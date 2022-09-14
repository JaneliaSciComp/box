function result = is_experiment_folder_given_contents(file_names, folder_names)
    result = all(ismember({'01_5.34_34', '02_5.34_34'}, folder_names)) && ...
             all(ismember({'01_Transition_to_5.34.mat', '02_Transition_to_5.34.mat', 'ROI.txt'}, file_names)) ;
end
