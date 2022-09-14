function result = collect_file_relative_paths_recursively(root_folder_path)
    % Returns a cell array of all the files in root_folder_path.  This does a
    % recursive search of the folder tree.  Note only regular files are returned,
    % not folder names.
    initial_raw_tile_folder_relative_paths = cell(0,1) ;  % these will be relative to root_folder_path    
    result = dirwalk(root_folder_path, @dirwalk_callback, initial_raw_tile_folder_relative_paths) ;    
end



function result = dirwalk_callback(root_folder_absolute_path, ...
                                   current_folder_relative_path, ...
                                   name_from_folder_index, ...
                                   name_from_file_index, ...
                                   relative_path_from_initial_file_index)  %#ok<INUSL>
    relative_path_from_file_index = cellfun(@(file_name)(fullfile(current_folder_relative_path, file_name)), ...
                                            name_from_file_index, ...
                                            'UniformOutput', false) ;
    result = vertcat(relative_path_from_initial_file_index, relative_path_from_file_index') ;
end
