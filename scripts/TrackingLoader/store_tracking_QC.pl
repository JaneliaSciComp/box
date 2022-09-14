#!/usr/local/bin/perl

use strict;
use Mail::Sendmail;
use File::Find;
use File::Copy;
use File::Path;
use File::Basename;
use Cwd 'abs_path';
use DBI;
use LWP::UserAgent;
use vars qw($DEBUG $message);

require '/groups/flyprojects/home/olympiad/bin/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{pipeline_stage} = '02_fotracked';
BoxPipeline::add_settings_to_hash(\%pipeline_data, "store_tracking", "", "QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $pipeline_data{'sage_env'} . ".config");

my $quarantine = $pipeline_data{'pipeline_root'} . "/04_quarantine_not_loaded/";
my $loadeddir = $pipeline_data{'pipeline_root'} . "/04_loaded/";
my $fotrackdir = $pipeline_data{'pipeline_root'} . "/02_fotracked/";

my $hr_qc_cvterm_id_lookup = get_qc_cvterm_id($dbh);
if ($DEBUG) {
    foreach my $key (sort keys %$hr_qc_cvterm_id_lookup) {
        print "$key $$hr_qc_cvterm_id_lookup{$key}\n";
    }
}

my $term_id =  get_cv_term_id($dbh,"fly_olympiad_box","not_applicable");
my $session_id = "NULL";
my $phase_id = "NULL";
my $browser = LWP::UserAgent->new;

#check_experiments_loaded($dbh,$fotrackdir,$hr_qc_cvterm_id_lookup, $quarantine, $term_id, $session_id, $phase_id, $browser);
check_experiments_loaded($dbh,$loadeddir,$hr_qc_cvterm_id_lookup, $quarantine, $term_id, $session_id, $phase_id, $browser);

if ($message) {
    my $subject = "[Olympiad Box Load Tracking Data Quarantine]Quarantine experiments that have failed to load tracking data.";
    
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
    send_email('weaverc10@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

$dbh->disconnect();
exit;

sub check_experiments_loaded {
    my ($dbh, $expdir,$hr_qc_cvterm_id_lookup, $quarantine, $term_id, $session_id, $phase_id, $browser) = @_;

    opendir(EXPDIR,,"$expdir") || die "cannot read $expdir\n";
    while (my $exp = readdir(EXPDIR)) {
        chomp($exp);
        next if ($exp =~ /^\./);
        print "$exp\n" if ($DEBUG);
        my $exp_path = $expdir . $exp;
        my $q_path = $quarantine . $exp;
        my $exp_track_path = $exp_path . "/" . $pipeline_data{'output_dir_name'};
        my $tracking_ver = $pipeline_data{'tracking_version'};
        
        unless (-e $exp_track_path) {
            #not tracked yet, skip
            next;
        }
        
        print "Checking if tracking loaded for $exp\n";

        # check if experiment loaded
        my $sa_count = check_exp_score_array($dbh, $exp, $tracking_ver);

        if ($sa_count < 1) {
            ### LOADED
            if ($DEBUG) { print "$exp $sa_count\n"; }
            my ($line_not_in_sage,$effector_missing);
            my $exp_box_name = "";
            $exp_box_name = parse_box_from_exp_name($exp);
            if ($DEBUG) { print "box_name = $exp_box_name\n"; }

            my $exp_line_name = "";
            my $temp_dir_24 = $exp_path . "/" . "01_3.0_24";
            if (-e $temp_dir_24) {
                my $mfile_24 = find_m_file($temp_dir_24);
                #print "m_24 = $mfile_24\n";
                unless($exp_line_name) {
                    ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$mfile_24);
                }
            }
            my $temp_dir_34 = $exp_path . "/" . "01_3.0_34";
            if (-e $temp_dir_34) {
                my $mfile_34 = find_m_file($temp_dir_34);
                unless($exp_line_name) {
                    ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$mfile_34);
                }
            }
            if ($DEBUG) { print "line name = $exp_line_name\n"; }

            print "Moving $exp_path to $q_path\n";
            unless($DEBUG) {
                move ("$exp_path", "$q_path" );
            }

            # log into sage if there is a sage id
            my $sage_id = 0;
            $sage_id = get_experiment_id($dbh,$expdir);
            
            if ($DEBUG) { print "sageid: $sage_id\n"; }
            if ($sage_id) {
                my $type_id = $$hr_qc_cvterm_id_lookup{"loadtrack_error_missingtrackingdata"};
                my $check_score_id = check_score($dbh,"NULL","NULL", $sage_id, $type_id);
                if ($check_score_id) {
                    update_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                } else {
                    insert_score($dbh, $session_id, $phase_id, $sage_id, $term_id, $type_id, 1, 0);
                }
            }

            # create Jira Ticket.
            $message .= "Could not find tracking data for experiment $exp in SAGE\n";

            my %jira_ticket_params;
            $jira_ticket_params{'lwp_handle'} = $browser;
            $jira_ticket_params{'jira_project_pid'} = 10043;
            $jira_ticket_params{'issue_type_id'} = 6;
            $jira_ticket_params{'summary'} = "Load Tracking Data Error for $exp";
            $jira_ticket_params{'description'} = "Could not find tracking data for experiment $exp in SAGE";
            $jira_ticket_params{'box_name'} = $exp_box_name;
            $jira_ticket_params{'line_name'} = $exp_line_name;
            $jira_ticket_params{'file_path'} = $q_path;
            $jira_ticket_params{'error_type'} = "";
            $jira_ticket_params{'stage'} = "Tracking loader";

            print "Errors found submitting Jira Ticket\n";
            submit_jira_ticket(\%jira_ticket_params);
            
        } else {
            ### Loaded experiments do nothing
        }


    }
    close(EXPDIR);
}


sub check_exp_score_array {
    my ($dbh,$expname,$trackingver) = @_;
    my $sql = "select count(*) from score_array sa, session s, experiment e where sa.session_id = s.id and s.name like 'Tracking $trackingver%' and s.experiment_id = e.id and e.name = '$expname'";
    if ($DEBUG) {
        print "sql: ",$sql,"\n"
    }
    
    my @results = do_sql($dbh,$sql);
    return($results[0]);
}


sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like 'loadtrack_%'";
    if ($DEBUG) { print "$qc_cv_sql \n"; }
    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        if ($DEBUG) { print "$termname,$termid\n"; }
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
