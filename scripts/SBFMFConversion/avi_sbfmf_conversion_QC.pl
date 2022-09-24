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
use Data::Dumper;
use vars qw($DEBUG);

require '/groups/flyprojects/home/olympiad/bin/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{pipeline_stage} = '01_sbfmf_compressed';
BoxPipeline::add_settings_to_hash(\%pipeline_data, "avi_sbfmf_conversion", "", "QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $pipeline_data{'sage_env'} . ".config");

my $hr_qc_cvterm_id_lookup = get_qc_cvterm_id($dbh);

if ($DEBUG) {
    foreach my $key (sort keys %$hr_qc_cvterm_id_lookup) {
        print "$key $$hr_qc_cvterm_id_lookup{$key}\n";
    }
}

my $browser = LWP::UserAgent->new;

my $term_id =  get_cv_term_id($dbh,"fly_olympiad_box","not_applicable");
my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");

my $sbfmf_dir = $pipeline_data{'pipeline_root'} . "/" . $pipeline_data{'pipeline_stage'} . "/";
my $quarantine_dir = $pipeline_data{'pipeline_root'} . "/01_quarantine_not_compressed/";

my %tubedirs = ();

my $hr_protocols = get_protocols();

my $exp_protocol;
my $session_id = "NULL";
my $phase_id = "NULL";
my $message = "";
opendir(SBFMF,"$sbfmf_dir");
while (my $line = readdir(SBFMF)) {

    my $experror_message = "";

    chomp($line);
    next if ($line =~ /^\./);
    print "Checking experiment $line\n";

    my $dir_path = $sbfmf_dir . $line;
    my $new_path = $quarantine_dir . $line;
    %tubedirs = ();
    my @exp_dir;
    
    push(@exp_dir, $dir_path);

    find({wanted=>\&get_tube_dirs,follow=>1},@exp_dir);
    my $sage_id = 0;
    $sage_id = get_experiment_id($dbh,$line);
    if ($DEBUG) { print "sage experiment id: $sage_id\n"; }
    #$sage_id = 999;

    my $exp_box_name = "";
    $exp_box_name = parse_box_from_exp_name($line);
    if ($DEBUG) { print "box_name = $exp_box_name\n"; }
    my $exp_line_name = "";

    my $tube_dir_num = keys %tubedirs;
    if ($DEBUG) { print "tube_dir_num: $tube_dir_num \n";  }
    
    my $protocol_tube_dir_num = $$hr_protocols{$exp_protocol}->{'sbfmf_dir_num'}; 
    
    my $exp_line_name = "";

    unless ($exp_line_name) {
        my $temperature_dir =  "01_" . $exp_protocol . "_34";
        my $t_path = "$dir_path/$temperature_dir";
        my $m_path = find_m_file($t_path);
        if ($DEBUG) { print "$m_path\n"; }
        my ($line_not_in_sage,$effector_missing);
        
        ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$m_path);
        if ($DEBUG) { print "line name: $exp_line_name\n"; }
        
    }


    # check SAGE
#    my $sql = qq~
#select count(sc.value)
#from experiment e, score sc, session s, phase p, cv_term ct
#where e.name = '$line'
#and e.id = p.experiment_id
#and p.type_id in (select ct.id from cv_term ct, cv c where c.id = ct.cv_id and c.name = 'fly_olympiad_box' and ct.name like 'sequence_%4')
#and e.id = s.experiment_id
#and s.type_id = getCvTermId('fly_olympiad_box', 'region', NULL)
#and sc.session_id = s.id
#and sc.phase_id = p.id
#and sc.type_id in (select ct.id from cv_term ct, cv c where c.id = ct.cv_id and c.name = 'fly_olympiad_qc_box')
#and ct.id = sc.type_id
#and ct.name like 'sbfmf_stat%'
#        ~;

my $sql = qq~
select count(sc.value)
from experiment e, score sc, cv_term ct
where e.name = '$line'
and e.id = sc.experiment_id
and sc.type_id = ct.id
and ct.name like "sbfmf_stat%"
~;

    if ($DEBUG) { print "$sql\n"; }
    my @sbfmf_stat_count = do_sql($dbh,$sql);

    #$sbfmf_stat_count[0] = 360;

    if ($DEBUG) { print "loaded sbfmf qc stats: $sbfmf_stat_count[0]\n"; }
   
#    unless ($sbfmf_stat_count[0] > 0) {
#        my $sbfmf_stat_error = "$line is missing sbfmf qc stats in sage\n";
#        print "ERROR: $sbfmf_stat_error \n";
#        $experror_message .= $sbfmf_stat_error;
#        if ($sage_id) {
#            my $type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_error_ missingerrormetrics"};
#            my $check_score_id = check_score($dbh,"NULL","NULL", $sage_id, $type_id);
#            if ($check_score_id) {
#                update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
#            } else {
#                insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
#            }
#            #log failed experiment
#            my $check_expf_score_id = check_score($dbh,"NULL","NULL", $sage_id, $failed_exp_termid);
#            if ($check_score_id) {
#                update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
#            } else {
#                insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $failed_exp_termid, 1, 0);
#            }
#            #log failed stage
#            my $check_expprop_id = check_experiment_property($dbh, $sage_id, $failed_stage_termid);
#            if ($check_expprop_id) {
#                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "sbfmf");
#            } else {
#                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "sbfmf");
#            }
#        }
#    }

    my $missing_sbfmf = 0;
    
    if ($tube_dir_num != $protocol_tube_dir_num) {
        my $tube_dir_error = "$line is missing tube sbfmf directories\n";
        $experror_message .= $tube_dir_error;
        print "ERROR1: $tube_dir_error\n";
        $missing_sbfmf++;
    } else {
        if ($DEBUG) { print "Right number of tube dirs\n"; }
        # Check to make sure right number of sbfmf files are in the directories
        foreach my $tubedir (sort keys %tubedirs) {
            my $p_sbfmf_number = $$hr_protocols{$exp_protocol}->{'tube_sbfmf_number'};
            my $valid_sbfmf_count = count_sbfmfs($tubedir);
        
            unless ($p_sbfmf_number == $valid_sbfmf_count) {
                my $tube_sbfmf_error = "$line is missing sbfmf files in $tubedir\n";
                print "ERROR: $tube_sbfmf_error \n";
                $experror_message .= $tube_sbfmf_error;
                $missing_sbfmf++;
            }
            
        }

    }

    if ($missing_sbfmf) {
        print "MISSING SBFMF Files $missing_sbfmf\n";
        if ($sage_id) {
            my $type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_error_missingsbfmfs"};
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
                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "sbfmf");
            } else {
                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "sbfmf");
            }
        }
    }

    if ($experror_message) {
        $message .= $experror_message;
        #Move into quarantine
        print "Moving $dir_path to $new_path\n";
        unless($DEBUG) {
            move ("$dir_path", "$new_path" );
        }

        print "EXP: $experror_message\n";
        
        my %jira_ticket_params;

        $jira_ticket_params{'lwp_handle'} = $browser;
        $jira_ticket_params{'jira_project_pid'} = 10043;
        $jira_ticket_params{'issue_type_id'} = 6;
        $jira_ticket_params{'summary'} = "SBFMF Conversion Error Detected $line";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "SBFMF conversion";

        print "Errors found, submitting Jira Ticket\n";
        submit_jira_ticket(\%jira_ticket_params);
    }
    


}
closedir(SBFMF);
$dbh->disconnect();

if ($message) {
    $message = "Box pipeline SBFMF QC check.\n" . $message;
    my $subject = "[Olympiad Box SBFMF Quarantine]Quarantine experiments that have failed to convert avi to sbfmf properly.";
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
    send_email('weaverc10@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

exit;

sub count_sbfmfs {
    my ($tube_sbfmf_dir) = @_;
    my $count = 0;
    opendir(TUBE,$tube_sbfmf_dir) || print "Could not open $tube_sbfmf_dir\n";
    while (my $file = readdir(TUBE)) {
        if ($file =~ /\.sbfmf$/) {
            my $sbfmf_filepath = "$tube_sbfmf_dir/$file";
            my $file_size = 0;
            $file_size = -s "$sbfmf_filepath";
            if ($DEBUG) { print "$sbfmf_filepath $file_size\n"; }
            if ($file_size > 0) {
                $count++;
            }
        }
    }
    closedir(TUBE);
    return($count);
}

sub get_tube_dirs {
    #print "$_\n";
    
    if ($_ =~ /tube\d+_sbfmf$/) {
        my $tubedirpath =  $File::Find::name;
        next if ($tubedirpath =~ /Output/);
        #print "$tubedirpath\n";
        my @data = split(/\_/,$_);
        
        my $protocol = $data[1];
        my @dirpath = split(/\//,$tubedirpath);        
        my $tubedir = pop(@dirpath);
        my $tempdir = pop(@dirpath);

        $tubedirs{$tubedirpath}->{"hascompleted"} = 1;
        $tubedirs{$tubedirpath}->{"tubedir"} = $tubedir;
        $tubedirs{$tubedirpath}->{"tempdir"} = $tempdir;
        $tubedirs{$tubedirpath}->{"tube_sbfmf_files"} = 0;
        $tubedirs{$tubedirpath}->{"protocol"} = $protocol;
        $exp_protocol = $protocol;
    }

}

sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like 'sbfmf_error%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
