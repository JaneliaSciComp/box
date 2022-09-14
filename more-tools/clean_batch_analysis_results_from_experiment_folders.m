function clean_batch_analysis_results_from_experiment_folders(root_folder_name, do_wet_run)    
    if ~exist('do_wet_run', 'var') || isempty(do_wet_run) ,
        do_wet_run = false ;
    end
    
    folder_path_from_experiment_index = find_experiment_folders(root_folder_name) ;
    cellfun(@(experiment_folder_name)(clean_batch_analysis_results_from_experiment_folder(experiment_folder_name, do_wet_run)), ...
            folder_path_from_experiment_index) ;
end
