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

require '/groups/flyprojects/home/olympiad/bin/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{'pipeline_stage'} = '02_fotracked';
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

my $fotrak_dir = $pipeline_data{'pipeline_root'} . "/" . $pipeline_data{'pipeline_stage'} . "/";
my $quarantine_dir = $pipeline_data{'pipeline_root'} . "/02_quarantine_not_fotracked/";
my $message = "";

my %tempdirs = ();

my $hr_protocols = get_protocols();

#print "test $$hr_protocols{'3.1'}->{'sequences'}\n";

my $exp_protocol;
my $session_id = "NULL";
my $phase_id = "NULL";

my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");

opendir(FOTRAK,"$fotrak_dir") || die "can not open $fotrak_dir\n";
while (my $line = readdir(FOTRAK)) {
    my $experror_message = "";
    chomp($line);
    print "Checking fotrack $line\n";

    next if ($line =~ /^\./);
    my $dir_path = $fotrak_dir . $line;
    my $new_path = $quarantine_dir . $line;

    %tempdirs = ();
    
    my @dirs;
    push(@dirs, $dir_path);
    find({wanted=>\&get_temp_dirs,follow=>1},@dirs);

    my $sage_id = 0;
    $sage_id = get_experiment_id($dbh,$line);

    if ($DEBUG) { print "sage experiment id: $sage_id\n"; }

    my $exp_box_name = "";
    $exp_box_name = parse_box_from_exp_name($line);
    if ($DEBUG) { print "box_name = $exp_box_name\n"; }
    my $exp_line_name = "";

    my $exp_line_name = "";
    unless ($exp_line_name) {
        my $temperature_dir =  "01_" . $exp_protocol . "_24";
        my $t_path = "$dir_path/$temperature_dir";
	unless (-e $t_path) {
	    $temperature_dir =  "01_" . $exp_protocol . "_29";
	    $t_path = "$dir_path/$temperature_dir";
	}
        my $m_path = find_m_file($t_path);
        #print "$m_path\n";
        my ($line_not_in_sage,$effector_missing);
        ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$m_path);
        if ($DEBUG) { print "line name: $exp_line_name\n"; }

    }

    my $temp_dir_num = 0;
    $temp_dir_num = keys %tempdirs if (keys %tempdirs);

    #print "EXP Prot:*$exp_protocol*\n";

    my $protocol_tube_dir_num = $$hr_protocols{$exp_protocol}->{'temp_dir_number'};
    #print "temp-dir-num * $temp_dir_num * $protocol_tube_dir_num\n";

    my $error_message;

    if ($temp_dir_num != $protocol_tube_dir_num) {
	my $error_type = "";
	unless ($temp_dir_num) {
	    $error_message = "Tracking results for $line is missing tracking output directory.\n";
	    print "$error_message";
	    $experror_message .= $error_message;
	    $error_type = "tracking_error_missingoutputdirectory";
	} else {
	    $error_message =  "Tracking results for $line is missing tracking temperature directory.\n";
	    print "$error_message";
            $experror_message .= $error_message;
	    $error_type = "tracking_error_missingtemperaturedirectory";
	}

	# temp dir error
	if ($sage_id) {
            my $type_id = $$hr_qc_cvterm_id_lookup{$error_type};
	    log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
          
        }
    } else {
	#check temp directories
	my $tube_dir_count = 0;
	my $analysis_info_count = 0;
	my $track_info_upd_count = 0;
	my $track_results_count = 0;

	foreach my $temp_dir (sort keys %tempdirs ) {
	    if ($DEBUG) { print "Checking temp dir: $temp_dir\n"; }
	    
	    opendir(TEMPDIR,"$temp_dir") || die "can not open $temp_dir \n";
	    while (my $file = readdir(TEMPDIR)) {
		chomp($file);
		if ($file =~ /\_seq\d+\_tube\d+$/) {
		    $tube_dir_count++;
		    my $analysis_info_path = "$temp_dir/$file/analysis_info.mat";
		    if (-e $analysis_info_path) {
			$analysis_info_count++;
			#print "\t1\n";
		    }
		    my $track_info_upd_path = "$temp_dir/$file/track_info_upd.mat";
		    if (-e $track_info_upd_path) {
                        $track_info_upd_count++;
                        #print "\t2\n";
                    }
		    my $track_results = "$temp_dir/$file/trak_results.txt";
		    if (-e $track_results) {
                        $track_results_count++;
                        #print "\t3\n";
                    }
		    

		}
	    }
	    closedir(TEMPDIR);



	}
	
	if ($tube_dir_count != $$hr_protocols{$exp_protocol}->{'track_files'}) {
	    my $type_id = $$hr_qc_cvterm_id_lookup{"tracking_error_missingtubedirectory"};
	    if ($sage_id) {
		log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
	    }
	    $error_message =  "Missing tracking data tube dirs for $line $tube_dir_count != $$hr_protocols{$exp_protocol}->{'track_files'} \n";
            print "$error_message";
            $experror_message .= $error_message;

	}

	if ($analysis_info_count != $$hr_protocols{$exp_protocol}->{'track_files'}) {
	    my $type_id = $$hr_qc_cvterm_id_lookup{"tracking_error_missinganalysisinfo"};
	    if ($sage_id) {
		log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
	    }
	    #print "ac: $analysis_info_count $$hr_protocols{$exp_protocol}->{'track_files'}\n";
	    $error_message = "Missing analysis_info files for $line\n";
            print "$error_message";
            $experror_message .= $error_message;
	}

	if ($track_info_upd_count!= $$hr_protocols{$exp_protocol}->{'track_files'}) {
	    my $type_id = $$hr_qc_cvterm_id_lookup{"tracking_error_missingtrakinfoupd"};
	    if ($sage_id) {
		#log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
	    }
	    $error_message = "Warning missing track_info_upd files for $line\n";
            print "$error_message";
            #$experror_message .= $error_message;
	}

	if ($track_results_count != $$hr_protocols{$exp_protocol}->{'track_files'}) {
	    my $type_id = $$hr_qc_cvterm_id_lookup{"tracking_error_missingtrakresults"};
	    if ($sage_id) {
		log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
	    }
	    $error_message = "Missing trak_results.txt files for $line\n";
            print "$error_message";
            $experror_message .= $error_message;
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
        $jira_ticket_params{'summary'} = "FoTrak Error Detected $line";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "Fly tracking";
        print "Errors found submitting Jira Ticket\n";
        submit_jira_ticket(\%jira_ticket_params);
    }
    

}

if ($message) {
    $message = "Olympiad box quarantine check for FoTrak data.\n" . $message;
    my $subject = "[Olympiad Box FoTrak Quarantine]Quarantine experiments that have failed to generate FoTrak data.";
    send_email('weaverc10@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

closedir(FOTRAK);

$dbh->disconnect();

exit;

sub log_error_in_sage {
    my ($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid) = @_;
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

sub get_temp_dirs {
    #print "$_\n";
    if ($_ =~ /\d+\_\d+\.\d+\_\d+$/) {
    
        my $tempdirpath =  $File::Find::name;
        next unless ($tempdirpath =~ /$pipeline_data{'output_dir_name'}/);
        if ($DEBUG) { print "HERE: $tempdirpath\n"; }
        my @data = split(/\_/,$_);

        my $protocol = $data[1];

        $tempdirs{$tempdirpath}->{"hascompleted"} = 1;
        $tempdirs{$tempdirpath}->{"tempdir"} = $_;
        $tempdirs{$tempdirpath}->{"analysis_info_files"} = 0;
        $tempdirs{$tempdirpath}->{"protocol"} = $protocol;
	$exp_protocol = $protocol;
    }
}

sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like \
'tracking%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}

