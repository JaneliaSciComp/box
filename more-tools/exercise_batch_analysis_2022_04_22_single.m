test_experiment_date_or_test_experiment_name_list = '20220422'
control_type_string = [] 
minimum_fly_count = 8 
output_folder_name = []
do_comparisons_only = []
do_force = []
flyvisionbox_read_only_folder_path = '/groups/scicompsoft/home/taylora/flyvisionbox-home/flyvisionbox-data-test-2022-04-22-single-read-only'
flyvisionbox_folder_path = '/groups/scicompsoft/home/taylora/flyvisionbox-home/flyvisionbox-data-test-2022-04-22-single'

% Reset the working folder
if exist(flyvisionbox_folder_path, 'file') ,
    system_from_list_with_error_handling({'rm', '-rf', flyvisionbox_folder_path}) ;
end
ensure_folder_exists(flyvisionbox_folder_path) ;
system_from_list_with_error_handling({'cp', '-R', '-T', flyvisionbox_read_only_folder_path, flyvisionbox_folder_path}) ;
%clean_batch_analysis_results_from_experiment_folders(flyvisionbox_folder_path, true)

% Run the batch_analysis
batch_analysis(test_experiment_date_or_test_experiment_name_list, ...
               control_type_string, ...
               minimum_fly_count, ...
               output_folder_name, ...
               do_comparisons_only, ...
               do_force, ...
               flyvisionbox_folder_path)



