#!/usr/bin/env perl

# Print out one of the settings values from BoxPipeline.pm.
#
# Usage:
#   pipeline_setting.pl name_of_setting

use strict;
use File::Path;
use File::Basename;
use Cwd 'abs_path';

my $pipeline_script_dir = abs_path(dirname(dirname($0)));
#print $pipeline_script_dir . "\n";

# Load the module from a path relative to this file.
require $pipeline_script_dir . "/BoxPipeline.pm";
my %pipeline_data;
BoxPipeline::add_settings_to_hash(\%pipeline_data, "pipeline", "setting");

#my $len = 0;
#((length($_) > $len) && ($len = length($_))) foreach (keys %pipeline_data);
#$len++;
#(printf "%-*s %s\n",$len,"$_:",$pipeline_data{$_})
#    foreach (sort keys %pipeline_data);

print $pipeline_data{"$ARGV[0]"} . "\n";
