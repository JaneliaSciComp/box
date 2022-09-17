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

# Load the settings module from a path relative to this file.
my %settings;
$settings{pipeline_scripts_path} = abs_path(dirname(dirname($0)));
$settings{pipeline_stage} = '00_incoming';
require $settings{pipeline_scripts_path} . "/BoxPipeline.pm";
BoxPipeline::add_settings_to_hash(\%settings, "Metadata-Loader", "", "metadata-QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $settings{sage_env} . ".config");

my $browser = LWP::UserAgent->new;

my $automated_pf_cvtermid = get_cv_term_id($dbh,"fly_olympiad_qc","automated_pf");
if ($DEBUG) { print "automated_pf: $automated_pf_cvtermid\n"; }

my $message = "";

my %tempdirs = ();
my $hr_protocols = get_protocols();

my $exp_protocol;
my $session_id = "NULL";
my $phase_id = "NULL";

my $dir = "$settings{pipeline_root}/$settings{pipeline_stage}/";
my $quarantine_dir = "$settings{pipeline_root}/00_quarantine_not_split/";

#my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
#my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");
my @dirs;
opendir(INCOMING,"$dir") || die "can not open $dir\n";
while (my $line = readdir(INCOMING)) {
    my $experror_message = "";
    $exp_protocol = "";
    chomp($line);
    
    next if ($line =~ /^\./);
    
    if ($DEBUG) { print "$line\n"; }
    
    my $dir_path = $dir . $line;
    my $new_path = $quarantine_dir . $line;
    
    %tempdirs = ();    
    @dirs = ();
    push(@dirs, $dir_path);
    #print "$dir_path\n";
    #find({wanted=>\&get_temp_dirs,follow=>1},@dirs);
    find({wanted=>\&get_temp_dirs,follow=>1,follow_skip=>2},@dirs);
    
    if ($DEBUG) { print "$exp_protocol\n"; }
    
    next unless ($exp_protocol);
    
    my $sage_exp_id = 0;
    $sage_exp_id = get_experiment_id($dbh,$line);
    
    if ($DEBUG) { print $sage_exp_id . "\n"; }
    
    if (!$sage_exp_id) {
        $experror_message = "$line was not loaded into SAGE.\n";
    } elsif (!exists $$hr_protocols{$exp_protocol}) {
        $experror_message = "$line has an unknown protocol: $exp_protocol\n";
    } else {
        print "Checking  $line (exp_id: $sage_exp_id, protocol: $exp_protocol)\n";
        
        my $failure = check_box_failure($dbh,$line);
        if ($failure > $$hr_protocols{$exp_protocol}->{'failure'}) {
            if ($$hr_protocols{$exp_protocol}->{'transition_duration'} == 0) {
                if ($failure ==2)    {
                }
            } else {        
                $experror_message .= "$line has box failure flag $failure\n";
            }
        }
        
        my $errorcode = check_box_errorcode($dbh,$line);
        if (length($errorcode) > $$hr_protocols{$exp_protocol}->{'errorcode'}) {     
            if ($$hr_protocols{$exp_protocol}->{'transition_duration'} == 0) {
                if ($errorcode eq "No Transition from Hot to Cold")    {
                }
            } else {
                $experror_message .= "$line has box errorcode: $errorcode\n";
            }
        }
       
        my $cool_max_var = check_coolmaxvar_failure($dbh,$line);
        if ($cool_max_var > $$hr_protocols{$exp_protocol}->{'cool_max_var'}) {        
            $experror_message .= "$line exceeds cool_max_var limit of $$hr_protocols{$exp_protocol}->{'cool_max_var'}:  $cool_max_var\n";
        }

        my $hot_max_var = check_hotmaxvar_failure($dbh,$line);
        if ($hot_max_var > $$hr_protocols{$exp_protocol}->{'hot_max_var'}) {        
            $experror_message .= "$line exceeds hot_max_var limit of $$hr_protocols{$exp_protocol}->{'hot_max_var'}: $hot_max_var\n";
        }
        
        if ($$hr_protocols{$exp_protocol}->{'transition_duration'} > 0) { # Only do check if there is more than one temperature in protocol
            my $transition_duration = check_transitionduration_failure($dbh,$line);
            if ($transition_duration > $$hr_protocols{$exp_protocol}->{'transition_duration'}) {        
                $experror_message .= "$line transition duration of $transition_duration exceeds $$hr_protocols{$exp_protocol}->{'transition_duration'}\n";
            }
        }
        
        my $questionable_data = check_questionabledata_failure($dbh,$line);
        if ($questionable_data > $$hr_protocols{$exp_protocol}->{'questionable_data'}) {        
            $experror_message .= "$line has been flagged for questionable data by operator\n";
        }
        
        my $redo_experiment  = check_questionabledata_failure($dbh,$line);
        if ($redo_experiment > $$hr_protocols{$exp_protocol}->{'redo_experiment'}) {        
            $experror_message .= "$line has been flagged for experiment redo by operator\n";
        }
        
        my $total_duration_seconds = check_totaldurationseconds_failure($dbh,$line);
        if ($total_duration_seconds > $$hr_protocols{$exp_protocol}->{'total_duration_seconds'}) {        
            $experror_message .= "$line total duration secs of $total_duration_seconds exceeds $$hr_protocols{$exp_protocol}->{'total_duration_seconds'}\n";
        }
        
        my $force_seq_start  = check_forceseqstart_failure($dbh,$line);
        if ($force_seq_start > $$hr_protocols{$exp_protocol}->{'force_seq_start'}) {        
            $experror_message .= "$line has been flagged for force seq start by operator\n";
        }
        
        my $halt_early  = check_haltearly_failure($dbh,$line);
        if ($halt_early > $$hr_protocols{$exp_protocol}->{'halt_early'}) {        
            $experror_message .= "$line has been flagged for halt early by operator\n";
        }
    }
    
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
        #print "line name: $exp_line_name\n";
    }
    
    if ($experror_message) {
        # Something went wrong.  Move the experiment to quarantine and create a JIRA ticket.
        
        $message .= $experror_message;
        $experror_message .= "Exp Protocol: $exp_protocol\n";
        
        print "The experiment failed to load into SAGE:\n\n$experror_message\n";


        if ($DEBUG) {
            print "line name: $exp_line_name\n";
            print "box: $exp_box_name\n";
            
            opendir(EXPDIR,"$dir_path");
            while (my $file = readdir(EXPDIR)) {
                
                if ($file =~ /RunData.mat/) {
                    #print "\t$file\n";
                    my $rundatamat_path = $dir_path . "/" . $file;
                    $rundatamat_path =~ s/\/groups//g;
                    $rundatamat_path =~ s/\/sciserv//g;
                    print "rundatamat_path: $rundatamat_path\n";
                }
            }
            closedir(EXPDIR);
        }

        # Move the experiment into quarantine
        print "Quarantining $dir_path\n";
        if ($DEBUG) {
            print "(Move %dir_path to $new_path)\n";
        } else {
            move ("$dir_path", "$new_path" );
        }
        
        # Update the pass/fail flags in SAGE.
        insert_exp_automated_pf($dbh,$sage_exp_id,"F");
        insert_exp_manual_pf($dbh,$sage_exp_id,"U");
        
        # Create the JIRA ticket.
        my %jira_ticket_params;
        $jira_ticket_params{'lwp_handle'} = $browser;
        $jira_ticket_params{'jira_project_pid'} = 10043;
        $jira_ticket_params{'issue_type_id'} = 6;
        $jira_ticket_params{'summary'} = "Box Error Detected in MetaData for $line";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "Metadata loader";
        submit_jira_ticket(\%jira_ticket_params);
    } else {
        # The experiment successfully loaded into SAGE.

        # Update the pass/fail flags.
        insert_exp_automated_pf($dbh,$sage_exp_id,"P");
        insert_exp_manual_pf($dbh,$sage_exp_id,"U");
    }
}

# Send an e-mail if there is anything to report.
if ($message) {
    $message = "Olympiad box pipeline Meta Data Quarantine.\n" . $message;
    my $subject = "[Olympiad Box Meta Data Quarantine]Quarantine experiments that have failed .";
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
    send_email('midgleyf@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

closedir(INCOMING);

$dbh->disconnect();

exit;

#sub insert_exp_automated_pf {
#    my ($dbh,$exp_id, $cvt_id, $pf) = @_;
#    my $pf_sql = "insert into experiment_property (experiment_id, type_id, value) values ($exp_id, $cvt_id, \"$pf\")";
#    if ($DEBUG) {
#        print "$pf_sql\n";
#    } else {
#        run_mod($dbh,$pf_sql);
#    }
#}

sub check_box_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','failure',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_box_errorcode {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','errorcode',NULL)
and e.name = '$exp_name'
    ~;
    my $val = "";
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0] =~ /\w/);
    return($val);
}

sub check_coolmaxvar_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','cool_max_var ',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_hotmaxvar_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','hot_max_var ',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_transitionduration_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','transition_duration',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_questionabledata_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','questionable_data',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_redoexperiment_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','redo_experiment',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_totaldurationseconds_failure {    
    my ($dbh,$exp_name) = @_;
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','total_duration_seconds',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_forceseqstart_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','force_seq_start',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

sub check_haltearly_failure {    
    my ($dbh,$exp_name) = @_;
    
    my $check_failure = qq~
select p.value
from experiment e, experiment_property p
where e.type_id = 1096
and e.id = p.experiment_id 
and p.type_id = getCvTermId('fly_olympiad_box','halt_early',NULL)
and e.name = '$exp_name'
    ~;
    my $val = 0;
    my @data = &do_sql($dbh,$check_failure);
    $val = $data[0] if ($data[0]);
    return($val);
}

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
    if ($DEBUG) { print "test $_\n"; }
    if ($_ =~ /\d+\_\d+\.\d+\_\d+$/) {
        
        my $tempdirpath =  $File::Find::name;
        #next unless ($tempdirpath =~ /Output/);
        #print "Here: $tempdirpath\n";
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

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc' and ct.cv_id = c.id ";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}

