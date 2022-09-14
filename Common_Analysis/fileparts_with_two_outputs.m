function [parent_folder_path, file_name] = fileparts_with_two_outputs(file_path)
    [parent_folder_path, file_stem_name, file_extension] = fileparts(file_path) ;
    file_name = horzcat(file_stem_name, file_extension) ;
end
