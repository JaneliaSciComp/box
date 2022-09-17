#!/usr/bin/perl

# Load the metadata and pre-run experimental data for all of the experiments found in 00_incoming.

use strict;
use File::Basename;
use Cwd 'abs_path';

my $mode = $ARGV[0];

# Load the settings module from a path relative to this file.
my %settings;
$settings{pipeline_stage} = '00_incoming';
$settings{pipeline_scripts_path} = abs_path(dirname(dirname($0)));
require $settings{pipeline_scripts_path} . "/BoxPipeline.pm";
BoxPipeline::add_settings_to_hash(\%settings, "Metadata-Loader", "", "metadata-load");

my $dir = "$settings{pipeline_root}/$settings{pipeline_stage}";
my $exp_load_file = "prod-exp_load." . $$ . ".sh";
open (LOADFILE,">$exp_load_file") || die "Cant open $exp_load_file\n";

print LOADFILE '#!/bin/bash';
print LOADFILE "\n";
print LOADFILE 'source ~/.bashrc';
print LOADFILE "\n";
close(LOADFILE);

opendir(INDIR, "$dir") || die "Cant open $dir\n";
while (my $in = readdir(INDIR)) {
    chomp($in);
    next if ($in =~ /^\./);
    my $fullpath = $dir . "/" . $in;
    print "$fullpath\n";
    
    if ($mode eq "run") {
        open (LOADFILE,">>$exp_load_file") || die "Cant open $exp_load_file\n";
        print LOADFILE "\n# Load $in\n";
        my $cmd1 = "source /usr/local/matutil/mcr_select.sh 2011a\;";
        print LOADFILE "$cmd1\n";
        my $cmd2 = "/groups/flyprojects/home/olympiad/bin/MetadataLoader \"$fullpath\" /groups/flyprojects/home/olympiad/config/SAGE-" . $settings{sage_env} . ".config insert\;";
        print LOADFILE "$cmd2\n";
        my $cmd3 = "source /usr/local/matutil/mcr_select.sh 2010bSP1\;";
        print LOADFILE "$cmd3\n";
        my $cmd4 = "/groups/flyprojects/home/olympiad/bin/store_experiment_data /groups/flyprojects/home/olympiad/config/SAGE-" . $settings{sage_env} . ".params \"$fullpath\"\;";
        print LOADFILE "$cmd4\n\n";
        close (LOADFILE);
    } elsif ($mode eq "del") {
        my $del_cmd = "/groups/flyprojects/home/olympiad/bin/delete_box_experiment-" . $settings{sage_env} . ".pl \"$in\"";
        system($del_cmd);
    }
}
closedir(INDIR);

if ($mode eq "run") {
    open (LOADFILE,">>$exp_load_file") || die "Cant open $exp_load_file\n";
    print LOADFILE "\# Clean up\nsource /usr/local/matutil/mcr_select.sh clean\;\n";
    close (LOADFILE);
}

chmod(0775, $exp_load_file);
print "executing $exp_load_file\n";
system("./$exp_load_file");

exit;
