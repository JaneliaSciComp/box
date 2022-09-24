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
use vars qw($DEBUG $message);
require '/groups/flyprojects/home/olympiad/bin/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
%pipeline_data{'pipeline_stage'} = "05_analyzed";
BoxPipeline::add_settings_to_hash(\%pipeline_data, "box_analysis", "", "QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $pipeline_data{'sage_env'} . ".config");

my $quarantine_dir = $pipeline_data{'pipeline_root'} . "/05_quarantine_analyzed/";
my $analysis_dir = $pipeline_data{'pipeline_root'} . "/" . %pipeline_data{'pipeline_stage'}  . "/";

my $analysis_ver = $pipeline_data{'analysis_version'};

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

my %tempdirs = ();

my $exp_protocol;
my $session_id = "NULL";
my $phase_id = "NULL";
my $message = "";

opendir(ANALYZED,"$analysis_dir") || die "can not open $analysis_dir\n";
while (my $line = readdir(ANALYZED)) {
    my $experror_message = "";
    chomp($line);
    #print "Checking analyzed $line\n";

    next if ($line =~ /^\./);

    my $dir_path = $analysis_dir . $line;
    my $new_path = $quarantine_dir . $line;

    my $sage_id = 0;
    $sage_id = get_experiment_id($dbh,$line);

    %tempdirs = ();
    my @dirs;
    push(@dirs, $dir_path);

    #find({wanted=>\&get_temp_dirs,follow=>1},@dirs);
    find({wanted=>\&get_temp_dirs,follow_skip=>1},@dirs);

    #print "$exp_protocol\n";

    my $comp_sum_pdf_count = 0;

    my $temp_dir_num = 0;
    $temp_dir_num = keys %tempdirs if (keys %tempdirs);

    my $exp_box_name = "";
    $exp_box_name = parse_box_from_exp_name($line);
    #print "box_name = $exp_box_name\n";

    my $exp_line_name = "";
    unless ($exp_line_name) {
        my $temperature_dir =  "01_" . $exp_protocol . "_24";
        my $t_path = "$dir_path/$temperature_dir";
        my $m_path = find_m_file($t_path);
        #print "$m_path\n";
        my ($line_not_in_sage,$effector_missing);
        ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$m_path);
        #print "line name: $exp_line_name\n";
    }

    my $error_message;
    my $output_dir = "$dir_path/" . $pipeline_data{'output_dir_name'};
    opendir (OUTPUTDIR, "$output_dir") || print "warning cannot open $output_dir\n";
    while (my $dircontent = readdir(OUTPUTDIR)) {
        chomp($dircontent);
        if ($dircontent =~ /comparison_summary.pdf/) {
            #print "$output_dir/$dircontent\n";
            $comp_sum_pdf_count++;
        }
    }
    closedir(OUTPUTDIR);

    unless($comp_sum_pdf_count > 0) {
	$experror_message .= "$line is missing comparison_summary.pdf\n";
	print "$sage_id $experror_message\n";
	if ($sage_id) {
            my $type_id = $$hr_qc_cvterm_id_lookup{"analysisspider_error_missingcomparisonsummarypdf"};
            log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
        }
    }

    if ($sage_id) {
        my $check_sessions_sql = "select s.id from session s, cv_term c  where s.experiment_id = $sage_id and s.type_id = c.id and c.name = \"analysis\"";
        my @analysis_session = do_sql($dbh,$check_sessions_sql);
        if (@analysis_session > 0) {
            # check if analysis score arrays were loaded
            my $sa_count = check_exp_score_array($dbh, $line, $analysis_ver);
            if ($sa_count < 1) {
                $experror_message .= "$line is missing analysis $analysis_ver data in SAGE.\n"
            }
        } else {
            $experror_message .= "$line is missing analysis sessions in SAGE.\n";
        }
    } else {
        $experror_message .= "$line is not loaded into SAGE.\n";
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
        $jira_ticket_params{'summary'} = "Analysis Error Detected $line";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "";
        print "Errors found submitting Jira Ticket\n";
        submit_jira_ticket(\%jira_ticket_params);
    }
}
close(ANALYZED);
$dbh->disconnect();

if ($message) {
    $message = "Olympiad box pipeline Analysis Quarantine.\n" . $message;
    my $subject = "[Olympiad Box Analysis Quarantine] Quarantine experiments where analysis did not create a comparison_summary.pdf.";
    send_email('midgleyf@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}


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
        next unless ($tempdirpath =~ /Output/);
        #print "$tempdirpath\n";
        my @data = split(/\_/,$_);

        my $protocol = $data[1];

        $tempdirs{$tempdirpath}->{"hascompleted"} = 1;
        $tempdirs{$tempdirpath}->{"tempdir"} = $_;
        $tempdirs{$tempdirpath}->{"analysis_info_files"} = 0;
        $tempdirs{$tempdirpath}->{"protocol"} = $protocol;
        $exp_protocol = $protocol;
    }
}


sub check_exp_score_array {
    my ($dbh,$expname,$analysisver) = @_;
    my $sql = "select count(*) from score_array sa, session s, experiment e, cv_term c where sa.session_id = s.id and s.experiment_id = e.id and e.name = '$expname' and s.type_id = c.id and c.name = \"analysis\" and s.name like 'Analysis $analysisver %'";
    my @results = do_sql($dbh,$sql);
    return($results[0]);
}


# cv_term analysisspider_error_missingcomparisonsummarypdf
sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and\
 ct.name like 'analysisspider%'";
    #print "$qc_cv_sql \n";
    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
