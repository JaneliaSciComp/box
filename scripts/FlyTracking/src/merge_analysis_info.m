function merge_analysis_info(outDir)
% AL: This appears to be deprecated in favor of ../../MergeTracking/merge_analysis_output
    if nargin==0 && isdeployed
        disp('Usage: merge_analysis_info output_dir_path');
        return
    end
    cd(outDir)
    Olympiad_folder_check; % badly named...this function concatenates the analysis_info's into an analysis_info_tube structure
