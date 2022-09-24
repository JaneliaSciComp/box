#!/usr/bin/env perl

# Print out one or more of the settings values from BoxPipeline.pm.
#
# Prints out each setting one per line in the same order as the inputs.
# If no settings are specified then all of the settings are listed.
# 
# Usage:
#   pipeline_settings.pl [name_of_setting [name_of_setting ...]]
#
# Examples:
#   > pipeline_settings.pl data_root
#   /path/to/data/root
#   > pipeline_settings.pl sage_env do_sageload_str
#   prod
#   true
#   > pipeline_settings.pl
#   analysis_protocol:        20130909
#   analysis_protocol_script: /groups/branson/bransonlab/projects/olympiad/FlyBowlAnalysis/analysis_protocol.pl
#   ctrax_annot_filename:     movie.ufmf.ann
#   ...
#   userid:                   olympiad


use strict;
use File::Path;
use File::Basename;
use Cwd 'abs_path';

my $pipeline_script_dir = abs_path(dirname(dirname($0)));
#print $pipeline_script_dir . "\n";

# Load the module from a path relative to this file.
require $pipeline_script_dir . "/BoxPipeline.pm";
my %pipeline_data;
$pipeline_data{pipeline_stage} = '00_incoming';
BoxPipeline::add_settings_to_hash(\%pipeline_data, "pipeline", "", "setting");

if ($#ARGV == -1) {
    # Print out all of the settings.
    my $len = 0;
    ((length($_) > $len) && ($len = length($_))) foreach (keys %pipeline_data);
        $len++;
    (printf "%-*s %s\n", $len, "$_:", $pipeline_data{$_})
        foreach (sort keys %pipeline_data);
} else {
    # Only print out the specified settings.
    foreach (@ARGV) {
        print $pipeline_data{"$_"} . "\n";
    }
}
