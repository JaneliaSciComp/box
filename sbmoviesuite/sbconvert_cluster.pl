#!/usr/bin/env perl

use strict;
use Cwd;
use Getopt::Long;
use File::Basename;

# setup options;
# Ignore args with no options (eg, the list of files)
$Getopt::Long::passthrough = 1;  
# Be case sensitive
$Getopt::Long::ignorecase = 0;
my $options = { };
GetOptions($options, "-H", "-help", "--help", "-bp:s", "-cp:s", "-R", "-OR" );
my $USAGE = qq~
Usage:
        sbconvert_cluster.pl <Optional parameter files>
        
        You must first ssh into the server login2 to run this script.
        It will only work with the new cluster.

        Example: sbconvert_cluster.pl 

        Set parameter files (optional):
                -bp     specify a parameter file to calculate background
                -cp     specify a parameter file to do avi to sbfmf conversion
                -R      remove avi file
                -OR     for Fly Olympiad only, removes source tube.avi if seq.avi file exists
~;
if ( $options->{'H'} || $options->{'-help'} || $options->{'help'}) {
        print STDERR $USAGE;
        exit 0;
}

print STDERR "Inside sbconvert_cluster.pl\n";

# Sort out where various folders, files of interest are
my $sbmoviesuite_folder_path = dirname(__FILE__);
my $box_root_folder_path = dirname($sbmoviesuite_folder_path);
#my $sce_root_folder_path = "$box_root_folder_path/local/SCE";  # used to be /misc/local/SCE
#my $cots_folder_path = "$sce_root_folder_path/SCE/build/COTS";
#my $python2_interpreter_path = "$box_root_folder_path/local/python-2.7.11/bin/python";  # used to me /misc/local/old_software/python-2.7.11/bin/python
my $python2_interpreter_path = "$box_root_folder_path/local/python-2-env/bin/python";  # used to me /misc/local/old_software/python-2.7.11/bin/python

my $calcbg_param_file = "$sbmoviesuite_folder_path/sbparam-calcbg.txt";
$calcbg_param_file = $options->{'bp'} if ($options->{'bp'});

my $usebg_param_file = "$sbmoviesuite_folder_path/sbparam-usebg.txt";
$usebg_param_file = $options->{'cp'} if ($options->{'cp'});

my $current_dir = getcwd;
print STDERR "current_dir: $current_dir\n";

my $random = int(rand($$));
my $bg_run_id = "sbconvert_" . $random;

my $sbconvertdotsh_path = "$sbmoviesuite_folder_path/sbconvert.sh";
my $cmd = qq~$sbconvertdotsh_path "$current_dir/" -p $calcbg_param_file~;

print STDERR "Generating background using command: $cmd\n";

system($cmd);

unless (-e "all-bg.pickle") {
        print STDERR "Error in sbconvert_cluster.pl: No background file (all-bg.pickle) seems to have been generated.  Exiting.";
        exit(1);
}

my $sbconvertdotpy_path = "$sbmoviesuite_folder_path/sbconvert.py";
opendir ( DIR, $current_dir ) || die "Error in opening dir $current_dir\n";
while( (my $filename = readdir(DIR))){
     if ($filename =~ /\.avi$/) {
        my $jobname = "sbconvert_" . $filename . "_" . $$;
        my $shfilename = $jobname . ".sh";
        write_qsub_sh($shfilename,$filename,$usebg_param_file,$sbconvertdotpy_path,$python2_interpreter_path);
        my $sbconvert_cmd = qq~bsub -J $jobname -oo ./$jobname.stdout -eo ./$jobname.stderr -n 2 ./$shfilename~;
        #my $sbconvert_cmd = qq~bsub -J $jobname -o /dev/null -e /dev/null -n 2 ./$shfilename~;
        print STDERR "submitting to cluster: $sbconvert_cmd\n";
        system($sbconvert_cmd);
     }
}
closedir(DIR);

print STDERR "It will take a few minutes for the sbfmf conversion to finish\n";

exit;

sub write_qsub_sh {
	my ($shfilename,$filename,$usebg_param_file,$sbconvertdotpy_path,$python2_interpreter_path) = @_;
	
	open(SHFILE,">$shfilename") || die 'Cannot write $shfilename';

	print SHFILE qq~#!/bin/bash
# sbconvert.py test script: calculate background on cluster; this
#   script will be qsub'd

# adapted from Mark Bolstad's "mtrax_batch"; removed the xvfb calls
#   since sbconvert doesn't require a screen

# call the main script, passing in all command-line parameters
$python2_interpreter_path $sbconvertdotpy_path $filename -p $usebg_param_file

~;

	if ($options->{'R'}) {
print SHFILE qq~#delete avi file
rm -f $filename
~;	
}

	if ($options->{'OR'}) {
	    my $seqfile = $filename;
	    $seqfile =~ s/_tube\d+//;
	    if (-e "../$seqfile") {
print SHFILE qq~#delete olympiad source avi file
rm -f ../$filename
~;
	    }
	}
	
	print SHFILE qq~#delete itself
rm -f \$0
~;	
	
	close(SHFILE);
	
	chmod(0755, $shfilename);
}
