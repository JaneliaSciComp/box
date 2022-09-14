#!/usr/bin/perl

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
BoxPipeline::add_settings_to_hash(\%pipeline_data, "merge_fotrak", "", "QC");

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

my $exp_protocol;
my $session_id = "NULL";
my $phase_id = "NULL";

my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");

opendir(FOTRAK,"$fotrak_dir") || die "can not open $fotrak_dir\n";
while (my $line = readdir(FOTRAK)) {
    my $experror_message = "";
    chomp($line);
    next if ($line =~ /^\./);
    
    print "Checking fotrack $line\n";
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
    unless ($exp_line_name) {
        my $temperature_dir =  "01_" . $exp_protocol . "_24";
        my $t_path = "$dir_path/$temperature_dir";
        my $m_path = find_m_file($t_path);
        #print "$m_path\n";
        my ($line_not_in_sage,$effector_missing);
        ($line_not_in_sage,$effector_missing,$exp_line_name) = getlinefromseqdetails($dbh,$m_path);
        if ($DEBUG) { print "line name: $exp_line_name\n"; }

    }

    my $temp_dir_num = 0;
    $temp_dir_num = keys %tempdirs if (keys %tempdirs);

    my $error_message;
    my $output_dir = "$dir_path/" . $pipeline_data{'output_dir_name'};
    my $found_success_mat = 0;
    opendir (OUTPUTDIR, "$output_dir") || print "warning cannot open $output_dir\n";
    while (my $dircontent = readdir(OUTPUTDIR)) {
        chomp($dircontent);
        if ($dircontent =~ /success_.+\.mat/) {
            #print "$dircontent\n";
            $found_success_mat = 1;
        }
    }
    closedir(OUTPUTDIR);

    # temp dir error
    unless ($found_success_mat) {
        $error_message = "$line does not have merged fotrak output.\n";
        print "$error_message";
        $experror_message .=  $error_message;  
        if ($sage_id) {
            my $type_id = $$hr_qc_cvterm_id_lookup{"trackmerging_error_badsuccessfile"};
            log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
        }      
    }
    my $merge_analysis_info_count = 0;
    foreach my $tempdir (sort keys  %tempdirs ) {
        if ($DEBUG) { print "checking $tempdir\n"; }
        opendir(TEMPDIR , $tempdir) || die "can not open $tempdir\n";
        while (my $tempcontents = readdir(TEMPDIR)) {
            if ($tempcontents =~ /seq\d+_analysis_info\.mat$/) {
                #print "\t$tempcontents \n";
                $merge_analysis_info_count++;
            }
        }
        closedir(TEMPDIR);
    }
    if ($DEBUG) { print "f:$merge_analysis_info_count e:$$hr_protocols{$exp_protocol}->{'analysisinfo_files'}\n"; }
    if ($merge_analysis_info_count != $$hr_protocols{$exp_protocol}->{'analysisinfo_files'}) {
        $error_message = "$line is missing merged sequence analysis_info.mat files.\n";
        print "$error_message";
        $experror_message .=  $error_message;
        if ($sage_id) {
            my $type_id = $$hr_qc_cvterm_id_lookup{"trackmerging_error_missinganalysisinfo"};
            log_error_in_sage($dbh,$sage_id,$type_id, $session_id, $phase_id, $term_id, $failed_exp_termid, $failed_stage_termid);
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
        $jira_ticket_params{'summary'} = "Merge FoTrak Error Detected $line";
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
    $message = "Olympiad box pipeline Merge Fotrak Quarantine.\n" . $message;
    my $subject = "[Olympiad Box Merge FoTrak Quarantine]Quarantine experiments that have failed to merge FoTrak data.";
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
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

sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like \
'trackmerging%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}

