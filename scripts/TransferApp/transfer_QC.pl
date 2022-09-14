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
$DEBUG=0;

# Load the settings module from a path relative to this file.
my %settings;
$settings{pipeline_scripts_path} = abs_path(dirname(dirname($0)));
$settings{pipeline_stage} = '00_incoming';
require $settings{pipeline_scripts_path} . "/BoxPipeline.pm";
BoxPipeline::add_settings_to_hash(\%settings, "Transfer", "", "transfer-QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $settings{sage_env} . ".config");

my $hr_qc_cvterm_id_lookup = get_qc_cvterm_id($dbh);

foreach my $key (sort keys %$hr_qc_cvterm_id_lookup) {
    print "$key $$hr_qc_cvterm_id_lookup{$key}\n";
}

my $browser = LWP::UserAgent->new;

my $term_id =  get_cv_term_id($dbh,"fly_olympiad_box","not_applicable");

my $failed_stage_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","failed_stage");
my $failed_exp_termid = get_cv_term_id($dbh,"fly_olympiad_qc_box","experiment_failed");

print "$failed_stage_termid $failed_exp_termid\n";
my $recycle_dir =    "$settings{pipeline_root}/recycle/";
my $incoming_dir =   "$settings{pipeline_root}/00_incoming/";
my $quarantine_dir = "$settings{pipeline_root}/00_quarantine_not_split/";
my $message = "";
my %avidirs = ();

my $hr_protocols = get_protocols();

my $session_id = "NULL";
my $phase_id = "NULL";

opendir(INCOMING,"$incoming_dir");
while (my $exp_name = readdir(INCOMING)) {

    my $experror_message = "";

    chomp($exp_name);
    next if ($exp_name =~ /^\./);
    next if ($exp_name eq "tube_avi_error_log.txt");

    my $dir_path = $incoming_dir . $exp_name;
    my $new_path = $quarantine_dir . $exp_name;

    # Get the count of temperature directories.
    my @avi_dir;
    push(@avi_dir, $dir_path);
    %avidirs = ();
    find({wanted=>\&getavifiles,follow=>1},@avi_dir);
    my $temp_dir_num = keys %avidirs;

    # Check if this experiment is in SAGE.
    my $sage_sql = "select id from experiment where name = '$exp_name'";
    my $sage_id = 0;
    my @sql_results = do_sql($dbh,$sage_sql);
    $sage_id = $sql_results[0];
    if ($DEBUG) { print "sage experiment id: $sage_id\n"; }

    unless ($sage_id) {
        my $load_error = "$exp_name has not been loaded into SAGE, moving to 00_quarantine_not_split.\n";
        print "$load_error";
        $experror_message .= $load_error;
    }
    
    # Check if the ROI file is missing.
    my $roi_file_path =  $incoming_dir . $exp_name . "/ROI.txt";
    unless (-e "$roi_file_path") {
        # boxtransfer_error_missingroi
        print "ROI MISSING $roi_file_path\n";
        $experror_message .= "ROI MISSING $roi_file_path\n";        
        if ($sage_id) {
            #log into sage observation boxtransfer_error_missingroi
            my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingroi"};
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
                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            } else {
                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            }
        }
    }
    
    # Check if the .exp file is missing.
    my $exp_file_path = $incoming_dir . $exp_name . "/" . $exp_name . ".exp";
    unless (-e "$exp_file_path") {
        # boxtransfer_error_missingexp
        print "EXP MISSING $exp_file_path\n";
        $experror_message .= "EXP MISSING $exp_file_path\n";
        if ($sage_id) {
            #log into sage observation 
            my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingexp"};
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
                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            } else {
                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            }
        }
    }
    
    # Check if the RunData file is missing.
    my $rundata_line = $exp_name;
    my @nameparse = split(/_/,$exp_name);
    my $lastvalnum = @nameparse - 1;
    if ($DEBUG) { print "$lastvalnum $nameparse[0]\n"; }
    my $lastval = $nameparse[$lastvalnum];
    $rundata_line =~ s/$lastval/RunData/;
    my $rundata_file_path = $incoming_dir . $exp_name . "/" . $rundata_line . ".mat";
    unless (-e "$exp_file_path") {
        # boxtransfer_error_missingexp
        print "Rundata MISSING $rundata_file_path\n";
        $experror_message .= "Rundata MISSING $rundata_file_path\n";
        if ($sage_id) {
            #log into sage 
            my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingrundata"};
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
                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            } else {
                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            }
        }

    }
    
    my $exp_box_name = "";
    $exp_box_name = parse_box_from_exp_name($exp_name);
    if ($DEBUG) { print "box_name = $exp_box_name\n"; }
    my $exp_line_name = "";

    if ($temp_dir_num == 0) {
        # The experiment has failed because it has no temperature directories.
        my $temp_dir_error = "$exp_name has $temp_dir_num temperature directories, moving to 00_quarantine_not_split.\n";
        print "$temp_dir_error";
        $experror_message .= "$temp_dir_error";
        if ($sage_id) {
            #log into sage observation boxtransfer_error_missingtempdir
            my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingtempdir"};
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
                update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
            } else {
                insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer"); 
            }
        }
    } else {
        # The experiment has at least one temperature directory.
        my $has_m_files = 0;
        my $missing_avi_issue = 0;
        
        # Check each of the temperature directories.
        my $protocol = "";
        foreach my $tempdir (sort keys %avidirs) {
            $protocol = $avidirs{$tempdir}->{"protocol"};
            my $protocol_temp_num = $$hr_protocols{$protocol}->{'temp_dir_number'};
            my $temperature_dir = $avidirs{$tempdir}->{'tempdir'};

            # Signal that the protocol doesn't exist.
            unless($protocol_temp_num) {
                my $protocol_error = "$exp_name is using protocol $protocol that does not exists, moving to 00_quarantine_not_split.\n";
                print "$protocol_error";
                $experror_message .= "$protocol_error";
                last;
            }

            # Check that the number of temperature directories in the file system matches the number that the protocol calls for.
            if ($protocol_temp_num != $temp_dir_num) {
                # boxtransfer_eror_missingtempdir
                my $temp_dir_error = "$exp_name has $temp_dir_num temp dirs but expects $protocol_temp_num dirs, moving to 00_quarantine_not_split.\n";
                print "$temp_dir_error";
                $experror_message .= "$temp_dir_error";
                
                if ($sage_id) {
                    #log into sage observation boxtransfer_error_missingtempdir
                    my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingtempdir"};
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
                        update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                    } else {
                        insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                    }

                }                

                last;
            } 
            # Check if the correct number of avi's exists and if they are not zero size.
            my $protocol_seq_num = $$hr_protocols{$protocol}->{'sequences'};
            my $avi_count = 0;
            my $avi_with_zero_size = 0;
            my $line_not_in_sage = 0;
            my $no_effector_in_m = 0;

            opendir(TEMPDIR,"$tempdir");
            while (my $out = readdir(TEMPDIR)) {
                chomp($out);
                if ($out =~ /\.avi$/) {
                    $avi_count++;
                    my $avi_path = $tempdir . "/" . $out;
                    my $file_size = -s "$avi_path";
                    if ($file_size == 0) {
                        $avi_with_zero_size++;
                    } else {
                        #print "$avi_path size $file_size\n";
                    }
                  
                } elsif ($out =~ /\.m$/) {
                    my $m_path = $tempdir . "/" . $out;                        
                    my ($line_not_in_sage,$no_effector_in_m,$line_name_p) = getlinefromseqdetails($dbh,$m_path);

                    if ($line_not_in_sage > 0) {
                        $experror_message .= "The line(s) in $temperature_dir/$out were not found in SAGE.\n";
                    } else {
                        unless($exp_line_name) {
                            $exp_line_name = $line_name_p;
                        }
                    }
                    if ($no_effector_in_m) {
                        print "effector(s) in $temperature_dir/$out file are missing\n";
                    }

                    # parse box name if available
                    unless($exp_box_name) {
                        $exp_box_name = getboxnamefromseqdetails($m_path);
                        if ($DEBUG) { print "Found m exp box: $exp_box_name\n"; }
                    }

                    $has_m_files++;
                }

            }
            closedir(TEMPDIR);


            # Signal that a zero-length AVI file was found.
            if ($avi_with_zero_size > 0) {
                my $avi_size_error = "$exp_name dir $temperature_dir has $avi_with_zero_size avi files that have size zero, moving to 00_quarantine_not_split.\n";
                print "$avi_size_error";
                $experror_message .= "$avi_size_error";
                $missing_avi_issue++;
                last;
            }

            # Signal that the wrong number of AVI files was found.
            if ($avi_count != $protocol_seq_num) { 
                my $avi_dir_error = "$exp_name dir $temperature_dir has $avi_count avi files but expects $protocol_seq_num avi files, moving to 00_quarantine_not_split.\n";
                print "$avi_dir_error";
                $experror_message .= "$avi_dir_error";
                $missing_avi_issue++;
                last;
            } else {
                if ($DEBUG) { print "OK $tempdir: $avi_count\n"; }
            }
            if ($DEBUG) { print "tempdir: $tempdir $protocol $protocol_temp_num $temp_dir_num\n"; }
            my $protocol_seq_num = $$hr_protocols{$protocol}->{'sequences'};
        }
        
        # Quarantine the experiment if it does not have the correct number of sequence details .m files.
        if ($has_m_files < $$hr_protocols{$protocol}->{'temp_dir_number'}) {
            #
            #print "missing 2 .m files\n";
            # $id

            $experror_message .= "seq details.m file is missing\n";
            if ($sage_id) {
                #log into sage observation boxtransfer_error_missingseqdetails                
                my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingseqdetails"};
                my $check_score_id = check_score($dbh,$session_id,$phase_id, $sage_id, $type_id);
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
                    update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                } else {
                    insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                }

            } 
        }
        
        # Quarantine the experiment if there are any missing or empty AVI files.
        if ($missing_avi_issue > 0) {
            #boxtransfer_error_missingavis
            $experror_message .= "seq AVIs are zero or missing detected\n";
            if ($sage_id) {
                my $type_id = $$hr_qc_cvterm_id_lookup{"boxtransfer_error_missingavis"};
                my $check_score_id = check_score($dbh,$session_id,$phase_id, $sage_id, $type_id);
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
                    update_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                } else {
                    insert_experiment_property($dbh, $sage_id, $failed_stage_termid, "boxtransfer");
                }

            }
        }

    }
    
    # Move any test experiments to the recycle bin.
    my $uc_line = uc($exp_name);
    if ($uc_line =~ /TEST/) {
        # move to recycle
        my $recycle_path = $recycle_dir . $exp_name;
        print "Moving $dir_path to $recycle_path\n";
        move ( "$dir_path", "$recycle_path" ) unless ($DEBUG);
    }
    
    # If any error was found then quarantine the experiment and create a JIRA ticket.
    if ($experror_message) {
        print "Moving $dir_path to $new_path\n";
        move ("$dir_path", "$new_path" ) unless ($DEBUG);
        
        my %jira_ticket_params;    
        $jira_ticket_params{'lwp_handle'} = $browser;
        $jira_ticket_params{'jira_project_pid'} = 10043; 
        $jira_ticket_params{'issue_type_id'} = 6;
        $jira_ticket_params{'summary'} = "Box Transfer Error Detected $exp_name";
        $jira_ticket_params{'description'} = $experror_message;
        $jira_ticket_params{'box_name'} = $exp_box_name;
        $jira_ticket_params{'line_name'} = $exp_line_name;
        $jira_ticket_params{'file_path'} = $new_path;
        $jira_ticket_params{'error_type'} = "";
        $jira_ticket_params{'stage'} = "Transfer app";
        
        my $uc_line = uc($exp_name);
        
        unless ($uc_line =~ /TEST/) {
            print "Submitting Jira Ticket for $dir_path\n";
            submit_jira_ticket(\%jira_ticket_params);
        }
    }
    
    print "\n";
    print "EXP: $experror_message\n";
    
    # Append the error message for this experiment to the master message for all experiments.
    $message .= $experror_message;

}
closedir(INCOMING);
$dbh->disconnect();

# If any problems were found then send an e-mail.
if ($message) {
    $message = "The following experiments transferred from the box PCs into:\n\n\t$incoming_dir\n\nbut did not have the right number of avi's, avi files that were empty, or failed to load into SAGE.\n\nExperiments that are found to have errors are moved into $quarantine_dir\n\n" . $message;
    my $subject = "[Olympiad Box Transfer Quarantine]Quarantine experiments that have been detected to be incomplete or have failed to load";
    
    #send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message,'midgleyf@janelia.hhmi.org');
    send_email('midgleyf@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);
}

exit;

sub getavifiles {
    if ($_ =~ /\d+\_\d+\.\d+\_\d+/) {
        my $avidirpath =  $File::Find::name;
        next if ($avidirpath =~ /Output/);
        next if ($avidirpath =~ /\/Logs\//);

        my @data = split(/\_/,$_);

        my $protocol = $data[1];
        
        $avidirs{$avidirpath}->{"hascompleted"} = 1;
        $avidirs{$avidirpath}->{"tempdir"} = $_;
        #$avidirs{$avidirpath}->{"avi_files"} = 0;
        $avidirs{$avidirpath}->{"protocol"} = $protocol;        
    }

}


sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like 'boxtransfer_%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
        my ($termname,$termid) = split(/\t/,$row);

        #print "$termname,$termid\n";
        $qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
