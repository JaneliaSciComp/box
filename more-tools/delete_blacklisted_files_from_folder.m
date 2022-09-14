function delete_blacklisted_files_from_folder(folder_name, file_name_regexp_from_blacklist_index, do_wet_run)
    % Deletes files matching any of the given regexps from folder_name.
    % Note that this only deletes file directly in folder_name.  It does *not*
    % recurse into subfolders.  

    leaf_name_from_file_index = simple_dir(folder_name) ;
    does_match_blacklist_from_file_index = does_match_some_regexp(leaf_name_from_file_index, file_name_regexp_from_blacklist_index) ;
    do_delete_from_file_index = does_match_blacklist_from_file_index ;
    leaf_file_name_from_to_delete_index = leaf_name_from_file_index(do_delete_from_file_index) ;
    for to_delete_index = 1 : length(leaf_file_name_from_to_delete_index) ,
        leaf_file_name = leaf_file_name_from_to_delete_index{to_delete_index} ;
        file_name = fullfile(folder_name, leaf_file_name) ;
        if do_wet_run, 
            system_from_list_with_error_handling({'rm', '-f', file_name}) ;
        else
            fprintf('rm -f %s\n', file_name) ;
        end
    end
end



function result = does_match_regexp(strs, re)
    result = cellfun(@(x)(~isempty(x)), regexp(strs, re, 'once')) ;
end



function result = does_match_some_regexp(strs, res)
    result = false(size(strs)) ;
    for i = 1 : length(res) ,
        re = res{i} ;        
        result = result | does_match_regexp(strs, re) ;
    end
end

