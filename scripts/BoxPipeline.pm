package BoxPipeline;
use strict;
use warnings;
use Exporter;
use POSIX qw(strftime);
use Cwd qw(realpath);

our @EXPORT = qw( add_settings_to_hash );

sub add_settings_to_hash {
    my $href = shift;
    my $topdir = shift;
    my $subdir = shift;
    my $keyword = shift;

    my $nowstr = POSIX::strftime("%Y%m%dT%H%M%S",localtime);

    # SAGE settings
    $href->{do_sageload_str} = 'false';  # 'true' or 'false'
    $href->{sage_env} = 'prod';          # 'prod', 'val' or 'dev'

    # The location of the actual experiment directories.
    $href->{data_root} = '/groups/reiser/home/boxuser/box_data';

    # The location of the 00_incoming, etc. pipeline directories containing sym. links to the experiment directories.
    #$href->{pipeline_root} = '/groups/flyprojects/home/olympiad/box/pipelines/centralcomplex';
    $href->{pipeline_root} = '/groups/reiser/home/boxuser/box';

    # Hard code the tracking and analysis versions for the current binaries used in the pipeline.
    # TODO: get these from the binaries themselves? e.g. "fo_trak -version"
    $href->{tracking_version} = '1.1';
    $href->{analysis_version} = '1.7';
    $href->{output_dir_name} = 'Output_' . $href->{tracking_version} . '_' . $href->{analysis_version};


    ### The remaining settings must not be altered. ###


    $href->{userid} = getlogin || getpwuid($<);
    $href->{data_dir} = $href->{pipeline_root} . '/' . $href->{pipeline_stage} . '/' . $topdir;
    $href->{data_dir} = realpath($href->{data_dir});

    $href->{unique_id} = BoxPipeline::unique_id($topdir, $subdir, $keyword);
    $href->{logs_dir} = $href->{data_dir} . '/Logs';
    $href->{gridscript_path} = $href->{logs_dir} . '/' . $href->{unique_id} . '.' . $nowstr . '.bash';
    $href->{stdout_path} = $href->{logs_dir} . '/' . $href->{unique_id} . '.' . $nowstr . '.stdout';
    $href->{stderr_path} = $href->{logs_dir} . '/' . $href->{unique_id} . '.' . $nowstr . '.stderr';
}

# Parameters: expdir, keyword
# Returns: unique id for grid jobs
sub unique_id {
    my $expdirshort = shift;
    my $subdir = shift;
    my $keyword = shift;
    my $unique_id =  $keyword . "-" . $expdirshort;
    if ($subdir) {
        $unique_id = $unique_id . "-" . $subdir;
    }
    $unique_id =~ s/\;/\_/g;
    $unique_id =~ s/\s+/\_/g;
    $unique_id =~ s/\(/\_/g;
    $unique_id =~ s/\)/\_/g;
    return $unique_id;
}
