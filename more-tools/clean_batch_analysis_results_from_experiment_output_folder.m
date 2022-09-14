function clean_batch_analysis_results_from_experiment_output_folder(output_folder_name, do_wet_run)
    % Delete the batch_analysis() output files from an folder.  It is assumed that
    % output_folder_name is an experiment folder's Output_1.1_1.7 folder.
    
    file_name_regexp_from_blacklist_index = ...
        {'^.*\.pdf$'}' ;
    % Need to keep _analysis_results.mat files, those are an output of tracking,
    % apparently.
%         {'^.*\.pdf$', ...
%          '^.*_analysis_results\.mat$'}' ;
   


    delete_blacklisted_files_from_folder(output_folder_name, file_name_regexp_from_blacklist_index, do_wet_run)
    clean_batch_analysis_results_from_output_01_02_folder(fullfile(output_folder_name, '01_5.34_34'), do_wet_run) ;
    clean_batch_analysis_results_from_output_01_02_folder(fullfile(output_folder_name, '02_5.34_34'), do_wet_run) ;
end



function clean_batch_analysis_results_from_output_01_02_folder(folder_name, do_wet_run)
    % Deletes batch analysis results from folder_name.  It is assumed that
    % folder_name is a subfolder with a name like Output_1.1_1.7/01_5.34_34 within
    % an experiment folder.
    file_name_regexp_from_blacklist_index = ...
        {'^.*_analysis_info\.mat$', ...
         '^.*_analysis_results\.mat$'}' ;
    delete_blacklisted_files_from_folder(folder_name, file_name_regexp_from_blacklist_index, do_wet_run)
end
