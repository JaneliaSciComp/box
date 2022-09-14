function clean_batch_analysis_results_from_experiment_folder(experiment_folder_name, do_wet_run)
    % Delete the batch_analysis() output files from an experiment folder.
    
    if ~exist('do_wet_run', 'var') || isempty(do_wet_run) ,
        do_wet_run = false ;
    end
    
    output_folder_name = fullfile(experiment_folder_name, 'Output_1.1_1.7') ;
    clean_batch_analysis_results_from_experiment_output_folder(output_folder_name, do_wet_run)
end
