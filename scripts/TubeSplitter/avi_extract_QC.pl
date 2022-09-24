#!/usr/bin/env perl

use strict;
use Mail::Sendmail;
use File::Find;
use File::Copy;
use File::Path;
use File::Basename;
use Cwd 'abs_path';
use DBI;
use LWP::UserAgent;
use vars qw($DEBUG);

require '/groups/reiser/home/boxuser/box/scripts/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{pipeline_stage} = '00_incoming';
BoxPipeline::add_settings_to_hash(\%pipeline_data, "avi_extract", "", "QC");

my $dbh = connect_to_sage("/groups/reiser/home/boxuser/box/scripts/SAGE-" . $pipeline_data{'sage_env'} . ".config");

my $hr_qc_cvterm_id_lookup = get_qc_cvterm_id($dbh);

foreach my $key (sort keys %$hr_qc_cvterm_id_lookup) {
    print "$key $$hr_qc_cvterm_id_lookup{$key}\n";
}

my $browser = LWP::UserAgent->new;

my $term_id =  get_cv_term_id($dbh,"fly_olympiad_box","not_applicable");

my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");

my $incoming_dir = $pipeline_data{'pipeline_root'} . "/00_incoming";
my $quarantine_dir = $pipeline_data{'pipeline_root'} . "/00_quarantine_not_split";


my %avidirs = ();

my $hr_protocols = get_protocols();

my $session_id = "NULL";
my $phase_id = "NULL";

my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");
my $message = "";
opendir(INCOMING,"$incoming_dir");
while (my $line = readdir(INCOMING)) {

    my $experror_message = "";

    chomp($line);
    next if ($line =~ /^\./);
    next if ($line eq "tube_avi_error_log.txt");

    my $dir_path = $incoming_dir . "/" . $line;
    my $new_path = $quarantine_dir . "/" . $line;
    %avidirs = ();
    my @avi_dir;
    push(@avi_dir, $dir_path);
    find({wanted=>\&getavifiles,follow=>1},@avi_dir);

    my $temp_dir_num = keys %avidirs;
    
    my $exp_box_name = "";
    $exp_box_name = parse_box_from_exp_name($line);
    print "box_name = $exp_box_name\n";
    my $exp_line_name = "";
    
    my $sage_id = get_experiment_id($dbh,$line);
    
    if ($DEBUG) { print "sage experiment id: $sage_id\n" };
    
    unless ($sage_id) {
        my $not_in_sage_error = "$line has not been loaded into SAGE, moved to 00_quarantine_not_split.\n";
        print "$not_in_sage_error";
        $experror_message .= "$not_in_sage_error";

        print "Moving $line to $new_path\n";
        unless($DEBUG) {
            move ("$dir_path", "$new_path" );
        }
    } else {

        unless ($temp_dir_num > 0) {
            my $temp_dir_error = "$line has $temp_dir_num temperature dirs and no tube avi files, moved to 00_quarantine_not_split.\n";
            print "$temp_dir_error";
            $experror_message .= "$temp_dir_error";

            print "Moving $line to $new_path\n";
            unless($DEBUG) {
                move ("$dir_path", "$new_path" );
            }

            if ($sage_id) {
                my $type_id = $$hr_qc_cvterm_id_lookup{"avisplit_error_missingtubeavis"};
                my $check_score_id = check_score($dbh,"NULL","NULL", $sage_id, $type_id);
                if ($check_score_id) {
                    update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                } else {
                    insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                }
                #log failed experiment
                my $check_expf_score_id = check_score($dbh,"NULL","NULL", $sage_id, $failed_exp_termid);
                if ($check_score_id) {
                    update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
                } else {
                    insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
                }
                #log failed stage
                my $check_expprop_id = check_experiment_property($dbh, $sage_id, $failed_stage_termid);
                if ($check_expprop_id) {
                    update_experiment_property($dbh, $sage_id, $failed_stage_termid, "avisplit");
                } else {
                    insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "avisplit");
                }
            }

        } else {
            #print "$line $temp_dir_num \n";
            my $total_tube_avi_count = 0;
            my $exp_protocol;
            foreach my $key (sort keys  %avidirs) {
                print "Analyzing\t$key\n";
                my $tube_avi_count = get_tube_avi_count($key);
                $exp_protocol = $avidirs{$key}->{"protocol"};
                my $tempdir = $avidirs{$key}->{"tempdir"};

                my $m_path = find_m_file($key);
                my ($line_not_in_sage,$effector_missing);
                
                unless($exp_line_name) {
                    ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$m_path);
                }

                print "Line name: $exp_line_name\n";
                unless($exp_box_name) {
                    $exp_box_name = getboxnamefromseqdetails($m_path);
                    print "Found m exp box: $exp_box_name\n";
                }

                print "protocol $exp_protocol\n";

                if ($tube_avi_count != $$hr_protocols{$exp_protocol}->{'tube_avi_number'}) {
                    
                    my $avi_missing_error = "$line/$tempdir has $tube_avi_count tube avi files needs to have $$hr_protocols{$exp_protocol}->{'tube_avi_number'} tube avi files, moved to 00_quarantine_not_split.\n";
                    print "$avi_missing_error\n";
                    $experror_message .= $avi_missing_error;

                    print "Moving $line to $new_path\n";
                    unless($DEBUG) {
                        move ("$dir_path", "$new_path" );
                    }

                    if ($sage_id) {
                        my $type_id = $$hr_qc_cvterm_id_lookup{"avisplit_error_missingtubeavis"};
                        my $check_score_id = check_score($dbh,"NULL","NULL", $sage_id, $type_id);
                        if ($check_score_id) {
                            update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                        } else {
                            insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                        }
                        #log failed experiment
                        my $check_expf_score_id = check_score($dbh,"NULL","NULL", $sage_id, $failed_exp_termid);
                        if ($check_score_id) {
                            update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
                        } else {
                            insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
                        }
                        #log failed stage
                        my $check_expprop_id = check_experiment_property($dbh, $sage_id, $failed_stage_termid);
                        if ($check_expprop_id) {
                            update_experiment_property($dbh, $sage_id, $failed_stage_termid, "avisplit");
                        } else {
                            insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "avisplit");
                        }
                    }

                } 
            }
        }
    }
    
    if ($experror_message) {
        #jira ticket submission
        
        my %jira_ticket_params;
        
        $jira_ticket_params{'lwp_handle'} = $browser;
        $jira_ticket_params{'jira_project_pid'} = 10043;
        $jira_ticket_params{'issue_type_id'} = 6;
        $jira_ticket_params{'summary'} = "AVI Split Error Detected $line";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "Tube splitter";
        
        print "Errors found, submitting Jira Ticket\n";
        submit_jira_ticket(\%jira_ticket_params);
        $message .= $experror_message;
    }
}

closedir(INCOMING);
$dbh->disconnect();

if ($message) {
    $message = "Box Pipeline AVI Split Quarantine Check\n" . $message;
    my $subject = "[Olympiad Box AVI Split Quarantine]Quarantine experiments that have failed to split the avi correctly";
    
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
    send_email('weaverc10@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

exit;


sub get_tube_avi_count {
    my ($temperature_dir) = @_;
    my $dir_avi_count = 0;
    opendir(TEMPERDIR,"$temperature_dir");
    while (my $avi = readdir(TEMPERDIR)) {
        if ($avi =~ /seq\d+_tube\d+\.avi/) {
            my $avi_path = $temperature_dir . "/" . $avi;
            my $file_size = 0;
            $file_size = -s "$avi_path";
            #print "$avi_path $file_size\n";
            if ($file_size > 0) {
                $dir_avi_count++;
            }
        }
    }
    return($dir_avi_count);
}


sub getavifiles {
    #print "$_\n";
    if ($_ =~ /\d+\_\d+\.\d+\_\d+/) {
    #if ($_ =~ /seq\d+_tube\d+\.avi/) {

        my $avidirpath =  $File::Find::name;
        next if ($avidirpath =~ /Output/);
        #print "$avidirpath\n";
        my @data = split(/\_/,$_);

        my $protocol = $data[1];

        $avidirs{$avidirpath}->{"hascompleted"} = 1;
        $avidirs{$avidirpath}->{"tempdir"} = $_;
        $avidirs{$avidirpath}->{"tube_avi_files"} = 0;
        $avidirs{$avidirpath}->{"protocol"} = $protocol;
    }

}

sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like 'avisplit_%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
