#!/usr/bin/env perl

use strict;
use Mail::Sendmail;
use File::Find;
use File::Copy;
use File::Path;
use File::Basename;
use Cwd 'abs_path';
use DBI;
use vars qw($DEBUG);

# TODO: use settings module

require '/groups/reiser/home/boxuser/box/scripts/flyolympiad_shared_functions.pl';

$DEBUG = 0;

# Load the box settings module from a path relative to this file.
my $pipeline_scripts_path = dirname(dirname(abs_path($0)));
require $pipeline_scripts_path . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{pipeline_stage} = '01_sbfmf_compressed';
BoxPipeline::add_settings_to_hash(\%pipeline_data, "store_sbfmf_stats", "", "QC");

my $dbh = connect_to_sage("/groups/flyprojects/home/olympiad/config/SAGE-" . $pipeline_data{'sage_env'} . ".config");

#options these will eventually need to be recovered from a parameter file

my $hr_qc_cvterm_id_lookup = get_qc_cvterm_id($dbh);

if ($DEBUG) {
    foreach my $key (sort keys %$hr_qc_cvterm_id_lookup) {
        print "$key $$hr_qc_cvterm_id_lookup{$key}\n";
    }
}

my $compress_dir = $pipeline_data{'pipeline_root'} . "/" . $pipeline_data{'pipeline_stage'} . "/";

my @search_avi_dirs = ();

push(@search_avi_dirs,$compress_dir);
my $avi_count = 0;
my %avidirs = ();

find({wanted=>\&getavidirs,follow=>1},@search_avi_dirs);

my $sbfmf_count = 0;

my $failed_avi_sbconvert = "";

foreach my $avidir (sort keys %avidirs) {
    opendir(AVIDIR,"$avidir");
    
    while (my $filename = readdir(AVIDIR)) {
	#print "file: $filename\n";
	if ($filename =~ /tube\d+_sbfmf$/) {
	    my $tube_dir = $filename;
	    #print "detect: $tube_dir\n";
	    #my $sbfmf_file = $filename;
	    #$sbfmf_file =~ s/avi/sbfmf/;
	    #$sbfmf_file = $tube_dir . "/" . $sbfmf_file;
	    #print "sbfmf_file: $sbfmf_file\n";
	    my $sbfmf_filepath = $avidir;
	    #$avidirs{$avidir}->{'sbfmfcompress'} = $sbfmf_filepath;
	    my $sbfmf_tube_dir = $sbfmf_filepath . "/" . $tube_dir;
	    #print "tubedir: $sbfmf_tube_dir\n";
	    # Create list of sbfmf dirs
	    if ($avidirs{$avidir}->{'sbfmfdirs'}) {
		my $hr_sbfmf_dirs = $avidirs{$avidir}->{'sbfmfdirs'};
		$$hr_sbfmf_dirs{$sbfmf_tube_dir} = 1;
	    } else {
		my %sbfmf_dirs = ();
		$sbfmf_dirs{$sbfmf_tube_dir} = 1;
		$avidirs{$avidir}->{'sbfmfdirs'} = \%sbfmf_dirs;
	    }
	    
	    #$sbfmf_filepath .= "/" . $sbfmf_file;
	    #print "filepath: $sbfmf_filepath\n"
                        
                        opendir(TUBEDIR,"$sbfmf_tube_dir");
                        while (my $tubefiles = readdir(TUBEDIR)) {
						     if ($tubefiles =~ /\.sbfmf$/) {
						     	#print "tubefiles: $tubefiles\n";
						     	my $sbfmf_filepath = $sbfmf_tube_dir . "/" . $tubefiles;
                                if (-s $sbfmf_filepath) {
                                # not empty
                                $sbfmf_count++;
                                my $size = -s $sbfmf_filepath;
                                my $sbfmf_summary = $sbfmf_tube_dir . "/sbconvert.summary";
                                
                                #my $sbfmf_avi_link = $sbfmf_tube_dir . "/" . $filename;
                                #print "$sbfmf_summary\n$sbfmf_avi_link\n"; 
                                
                              } else {
                                # empty!
                                # flag that it is empty file in the directory
                                $avidirs{$avidir}->{"hascompleted"} = 0;

                                print "fail to convert $avidir/$filename\n";
                                #log fail and leave so that it may be redone.
                                $failed_avi_sbconvert .= "$avidir\n";
                        	  }
                        	}
                        }
                        closedir(TUBEDIR);

                }
        }
        closedir(AVIDIR); 
}

#print "$sbfmf_count\n";

my $mean_error_summary = "";

foreach my $avidir (sort keys %avidirs) {
    if ($avidirs{$avidir}->{"hascompleted"}) {
	my $total_mean_error = 0;
	my $total_max_error = 0;
	my $conversion_count = 0;

	my $seqtemp = "sequence_";

	if (ref($avidirs{$avidir}->{'sbfmfdirs'}) eq 'HASH') {
	    my ($num,$protocol,$temp) = split(/\_/, $avidirs{$avidir}->{'tempdir'});
	    $seqtemp .= $temp;	    
	    if ($DEBUG) { print "EXP: $avidirs{$avidir}->{'expdir'}\nTMP: $seqtemp\n"; }
	} else {
	    #print "Fubar\n";
	    next;
	}
	
	my $hr_sbfmf_dirs = $avidirs{$avidir}->{'sbfmfdirs'};
	
	
	foreach my $tubedir (sort keys %$hr_sbfmf_dirs) {
	    my $tube_number = "";
	    if ($tubedir =~ /(tube\d+)/) {
		$tube_number = $1;
		$tube_number =~ s/tube//;
	    }

	    my ($exp_id, $session_id) = get_experiment_session($dbh, $avidirs{$avidir}->{'expdir'}, $tube_number);
	    if ($DEBUG) { print "\texperiminet id: $exp_id session id: $session_id"; }
	    if ($DEBUG) { print "\t$tubedir/sbconvert.summary $tube_number\n"; }
	    open(SUMMARY,"$tubedir/sbconvert.summary");
	    while (my $line = <SUMMARY>) {
		chomp($line);
		next if ($line =~ /^date/);
		
		my @datasum = split(/\t/,$line);
		#print "\t$datasum[3] $datasum[4]\n";
		my $nframes = $datasum[2];
		my $mean_error = $datasum[3];
		my $max_error = $datasum[4];
		my $mean_window_error = $datasum[5];
		my $max_window_error = $datasum[6];
		my $compression_rate = $datasum[7];



		$conversion_count++;

		my $phase_tube_num = "";
		if ($datasum[1] =~ /(seq\d+)/ ) {
		    $phase_tube_num = $1;
		    $phase_tube_num =~ s/seq//;
		}

		my $phase_id = get_experiment_phase($dbh, $avidirs{$avidir}->{'expdir'}, $seqtemp, $phase_tube_num);

		unless ($phase_id) {
		    next;
		}

		my $term_id =  get_cv_term_id($dbh,"fly_olympiad_box","not_applicable");
		#print "$datasum[1] $phase_tube_num\n";
		if ($DEBUG) { print "\t\t$line P$phase_id\n"; }
		
		#load into score use exp_id, session_id, phase_id, term_id
		my $type_id;

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_nframes"};

		if ($type_id) {
		    my $nframes = $datasum[2];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
		    if ($sa_id) {
			update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $nframes, 0);
		    } else {
			insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $nframes, 0);
		    }
		    
		}

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_meanerror"};
		if ($type_id) {
		    my $mean_error = $datasum[3];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
                    if ($sa_id) {
                        update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $mean_error, 0);
                    } else {
                        insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $mean_error, 0);
                    }
		}

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_maxerror"};
		if ($type_id) {
		    my $max_error = $datasum[4];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
                    if ($sa_id) {
                        update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $max_error, 0);
                    } else {
                        insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $max_error, 0);
                    }
		}

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_meanwindowerror"};
		if ($type_id) {
		    my $mean_window_error = $datasum[5];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
                    if ($sa_id) {
                        update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $mean_window_error, 0);
                    } else {
                        insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $mean_window_error, 0);
                    }
		}

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_maxwindowerror"};
		if ($type_id) {
		    my $max_window_error = $datasum[6];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
                    if ($sa_id) {
                        update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $max_window_error, 0);
                    } else {
                        insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $max_window_error, 0);
                    }
		}

		$type_id = $$hr_qc_cvterm_id_lookup{"sbfmf_stat_compressionrate"};
		if ($type_id) {
		    my $compression_rate = $datasum[7];
		    my $sa_id = check_score($dbh, $session_id, $phase_id, $exp_id, $type_id);
                    if ($sa_id) {
                        update_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $compression_rate, 0);
                    } else {
                        insert_score($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $compression_rate, 0);
                    }
		}

		$total_mean_error += $mean_error;
		$total_max_error += $max_error;
	    }
	    close(SUMMARY);
	}

	my $avg_mean_error = 0;
	my $avg_max_error = 0;
        if ($conversion_count) {
	    $avg_mean_error = sprintf("%.3f", $total_mean_error/$conversion_count);
	    $avg_max_error = sprintf("%.3f", $total_max_error/$conversion_count);
	}
	
	$mean_error_summary .= "avg mean error: $avg_mean_error, avg max error: $avg_max_error, number of sbfmf files: $conversion_count for $avidir\n";
	
    }
    
}

#foreach my $avidir (sort keys %avidirs) {
#    if ($avidirs{$avidir}->{"hascompleted"}) {
#        my $experiment_dir = $avidir;
#        $experiment_dir =~ s/\/\d+\_\d+\.\d+\_\d+$//;
#        print "EX $experiment_dir \n";
#        my $cmd = "unlink $experiment_dir";
#        print "$cmd\n";
#        #system($cmd);
#    }
#}
#exit;

# Email content
my $message = qq~Fly Olympiad Daily sbfmf conversion report:
$sbfmf_count sbfmfs have been converted
$mean_error_summary 
Software versions used:
ctrax v0.1.4.1 
sbconvert v0.7.6
~;
if (length($failed_avi_sbconvert)>0) {
$message .= qq~
Failed avi to sbfmf conversions that will be re-run:
$failed_avi_sbconvert
~;
}

my $subject = "Fly Olympiad Daily sbfmf Conversion Report";
#print "$message\n";

send_email('weaverc10@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message);

#send_email('korffw@janelia.hhmi.org','olympiad@janelia.hhmi.org', $subject, $message, 'midgleyf@janelia.hhmi.org');

exit;

sub getavidirs {
    #print "$_\n";
    if ($_ =~ /\d+\_\d+\.\d+\_\d+/) {
	my $avidirpath =  $File::Find::name;
	next if ($avidirpath =~ /Output/);
	#print "HERE: $avidirpath\n";
	my @dir_path = split(/\//,$avidirpath);
	#print "$dir_path[7]\n";
	$avidirs{$avidirpath}->{"hascompleted"} = 1;
	$avidirs{$avidirpath}->{"sbfmfcompress"} = "";
	$avidirs{$avidirpath}->{'sbfmfdirs'} = "";
	$avidirs{$avidirpath}->{'expdir'} = $dir_path[7];
	$avidirs{$avidirpath}->{'tempdir'} = $dir_path[8];
    }
    
}

# ****************************************************************************
# * send_email
# ****************************************************************************

=head2 send_email

 Title:       send_email
 Usage:       send_email($to_email, $from_email, $subject, $message);

 Description: Function that will prepare and send email notification.
$to_email = email address you want to send the message to.
$from_email = notify the recepient who sent the email.
$subject = what is to be displayed in the subject line of the email.
$message = the email message to be sent.
=cut

sub send_email {

        my ($to_email, $from_email, $subject, $message, $cc, $bcc) = @_;

        #required;

        my %mail = (smtp => 'smtp.janelia.priv', 
                                to => $to_email,
                                from => $from_email,
                                subject => $subject,
                                message => $message
                                );
        # optional
        if ($cc) {
                $mail{'cc'} = $cc;
        }

        if ($bcc) {
                $mail{'bcc'} = $bcc;
        }

        if (sendmail %mail) { 
                print "email notification sent to $to_email.\n"; 
        } else {
                print "Error sending mail: $Mail::Sendmail::error\n";
                print "Log $Mail::Sendmail::log\n";
        }
}

sub do_sql {
    my($dbh,$query,$delimeter) = @_;
    my($statementHandle,@x,@results);
    my(@row);

    if($delimeter eq "") {
        $delimeter = "\t"; # define a delimiter between each element in a row.
    }

    $statementHandle = $dbh->prepare($query); # prepare query
    if ( !defined $statementHandle) {
        print "Cannot prepare statement: $DBI::errstr\n"; # error in db connection
    }
    
    $statementHandle->execute() || print "failed query: $query\n"; #execute query
    
    while ( @row = $statementHandle->fetchrow() ) { # while query runs, @row is assigned
        push(@results,join($delimeter,@row)); # join contents of row with delimiter
    }

    #release the statement handle resources
    $statementHandle->finish;
    return(@results); #query results
}

sub run_mod {
    my($dbproc,$query) = @_;
    my($statementHandle,$result);

    $statementHandle = $dbproc->prepare($query); # prepare query 
    if ( !defined $statementHandle) {
        print "Cannot prepare statement: $DBI::errstr\n";
    }
    $statementHandle->execute(); # execute query
    #$dbproc->commit; # commit query
    $statementHandle->finish;
    
    return($result);
}

sub get_experiment_session {
    my ($dbh, $expdir, $tube_number) = @_;
    my $sql = "select e.id, s.id, s.line_id, s.name from experiment e, session s where e.type_id = getCvTermId('fly_olympiad_box', 'box', NULL) and e.name = '$expdir' and s.experiment_id = e.id and s.type_id = getCvTermId('fly_olympiad_box', 'region', NULL) and s.name = '$tube_number'";
    if ($DEBUG) { print "$sql\n"; }
    my @row = do_sql($dbh,$sql);
    my ($exp_id,$session_id) = split(/\t/,$row[0]);
    return($exp_id,$session_id);
}

sub get_experiment_phase {
    my ($dbh, $expdir, $seqtemp,$seq_num) = @_;
    my $sql = "select e.id, p.id from experiment e, phase p where e.type_id = getCvTermId('fly_olympiad_box', 'box', NULL) and e.name = '$expdir' and p.experiment_id = e.id and p.type_id = getCvTermId('fly_olympiad_box', '$seqtemp', NULL) and p.name = '$seq_num'";
    if ($DEBUG) { print "Phase $sql\n"; }
    my @row = do_sql($dbh,$sql);
    my ($exp_id,$phase_id) = split(/\t/,$row[0]);
    if ($DEBUG) { print "PHASE ID: $phase_id\n"; }
    return($phase_id);
}

sub get_cv_term_id {
    my ($dbh, $cv, $cvterm) = @_;
    my $sql = "select id from cv_term where id = getCvTermId('$cv', '$cvterm', NULL) ";
    my @row = do_sql($dbh,$sql);
    my $term_id = $row[0];
    return($term_id);
}

sub check_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $type_id) = @_;
    my $sql = "select id from score where session_id = $session_id and phase_id = $phase_id and experiment_id = $exp_id and type_id = $type_id";
    if ($DEBUG) { print "Check: $sql\n"; }
    my @row = do_sql($dbh,$sql);
    my $score_id = $row[0];
    return($score_id);
}

sub insert_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $value, $run) = @_;
    my $sql = "insert into score (session_id,phase_id,experiment_id,term_id,type_id,value,run) values ($session_id,$phase_id,$exp_id,$term_id,$type_id,'$value',$run)";
    if ($DEBUG) { print "Insert: $sql\n"; }
    run_mod($dbh,$sql);
}

sub update_score {
    my ($dbh, $session_id, $phase_id, $exp_id, $term_id, $type_id, $value, $run) = @_;
    my $sql = "update score set value = '$value', create_date = now() where session_id = $session_id and phase_id = $phase_id and experiment_id = $exp_id and type_id = $type_id";
    if ($DEBUG) { print "Update: $sql\n"; }
    run_mod($dbh,$sql);
}

sub get_qc_cvterm_id {
    my($dbh) = @_;
    my %qc_cvterm_ids;

    my $qc_cv_sql = "select ct.name, ct.id from cv_term ct, cv c where c.name = 'fly_olympiad_qc_box' and ct.cv_id = c.id and ct.name like 'sbfmf_stat%'";

    my @qc_rows = do_sql($dbh,$qc_cv_sql);

    foreach my $row (@qc_rows) {
	my ($termname,$termid) = split(/\t/,$row);
	
	#print "$termname,$termid\n";
	$qc_cvterm_ids{$termname} = $termid;
    }
    return(\%qc_cvterm_ids);
}
