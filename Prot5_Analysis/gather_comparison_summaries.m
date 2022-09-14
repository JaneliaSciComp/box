if ismac()
    flyvisionbox_folder_path = '/Volumes/flyvisionbox' ;
elseif ispc()
    flyvisionbox_folder_path = 'X:' ;    
else
    flyvisionbox_folder_path = '/groups/reiser/flyvisionbox' ;    
end
   

box_data_folder_path = fullfile(flyvisionbox_folder_path, 'box_data') ;
comparison_summaries_folder_path = fullfile(flyvisionbox_folder_path, 'comparison_summaries') ;
boxdata_mat_path = fullfile(flyvisionbox_folder_path, 'BoxData.mat') ;
BoxData = load_anonymous(boxdata_mat_path) ;
%cd(box_data_folder_path)

experiment_names = setdiff(simple_dir(box_data_folder_path), {'.' '..' '.DS_Store'}) ;
boxdata_experiment_names = {BoxData.experiment_name} ;

number_of_files_copied = 0 ;
for i = 1 : length(experiment_names)
    experiment_name = experiment_names{i} ;
%     if contains(experiment_name, '20180601')
%         keyboard
%     end
    is_match = strcmp(boxdata_experiment_names,experiment_name) ;
    if ~any(is_match)
        fprintf('%s: No entry for this experiment in BoxData.mat, so skipping.\n', experiment_name) ;
    else
        experiment = BoxData(is_match) ;
        date_as_string = experiment.date_time(1:8);

        this_date_comparison_summaries_folder_path = fullfile(comparison_summaries_folder_path, date_as_string) ;
        if ~exist(this_date_comparison_summaries_folder_path, 'dir')
            mkdir(this_date_comparison_summaries_folder_path)
        end

        output_folder_path = fullfile(box_data_folder_path, experiment.experiment_name, 'Output_1.1_1.7') ;
        %cd(output_folder_path)

        source_file_path = fullfile(output_folder_path, 'comparison_summary.pdf') ;
        if exist(source_file_path, 'file')
            target_file_path = fullfile(this_date_comparison_summaries_folder_path, [experiment_name '_comparison_summary.pdf']) ;
            if exist(target_file_path, 'file')        
                fprintf('%s: comparison_summary.pdf already present in comparison_summaries folder.\n', experiment_name) ;
            else
                fprintf('%s: Copying comparison_summary.pdf from output folder to comparison_summaries folder.\n', experiment_name) ;                     
                copyfile(source_file_path, target_file_path) ;
                number_of_files_copied = number_of_files_copied + 1 ;
            end
        else
            %if ~strcmp(experiment.type, 'control')
            fprintf('%s: No comparison_summary.pdf present in the output folder for this experiment\n', experiment_name) ;
            %end
        end
    end
end
fprintf('\nNumber of files copied: %d\n', number_of_files_copied) ; 
