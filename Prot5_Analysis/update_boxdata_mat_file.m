function update_boxdata_mat_file(box_data_mat_path, ...
                                 box_data_folder_path, ...
                                 box_data_merge_output_folder_path, ...
                                 box_data_analysis_output_folder_path, ...
                                 minimum_fly_count, ...
                                 minimum_good_tube_count, ...
                                 experiment_names_to_force)
    % What it says on the tin.  The file at box_data_mat_path is the only
    % file changed by this function.  It gets the information needed to
    % update that file from looking at files in box_data_folder_path,
    % box_data_merge_output_folder_path, and
    % box_data_merge_output_folder_path, which can all be identical, if
    % needed.
    
    %%
    % getBoxData crawls the box_data directory and adds new
    % experiment data to the BoxData.mat file
    %
    
    % % Sort out where the flyvisionbox folder is
    % if ismac(),
    %     flyvisionbox_folder_path = '/Volumes/flyvisionbox' ;
    % elseif ispc() ,
    %     flyvisionbox_folder_path = 'X:' ;
    % else
    %     % Assume linux box, with typical Janelia filesystem organization
    %     flyvisionbox_folder_path = '/groups/reiser/flyvisionbox' ;
    % end
    %box_data_mat_path = fullfile(flyvisionbox_folder_path, 'BoxData.mat') ;
    
    % try loading BoxData, start fresh if file does not exist
    try
        BoxData = load_anonymous(box_data_mat_path) ;
        %BoxData = s.BoxData ;
    catch
        % want zero-length row vector with certain fields present
        BoxData = struct_with_shape_and_fields([1 0], {'genotype', 'experiment_name'}) ;  
    end
    
    % We now decide what's a control and what's not later---no real reason
    % to cmmit now.
%     % lists of controls for different experiments
%     split_control_genotypes = {'JHS_K_85321', 'JHS_K_85321_10'} ;
%     %'GMR_SS00200',...
%     %                     'GMR_SS00205', ...
%     %                     'Dickson',...
%     %                     'GMR_SS00194',...
%     %                     'GMR_SS00179',...
%     %                     'CantonS',...
%     gal4_control_genotypes = {'pBDP_GAL4','pBDPGAL4U'} ;
    
    %box_data_folder_path = fullfile(flyvisionbox_folder_path, 'box_data') ;
    %box_data_merge_output_folder_path = fullfile(flyvisionbox_folder_path, 'box_data_merge_output') ;
    %box_data_analysis_output_folder_path = fullfile(flyvisionbox_folder_path, 'box_data_analysis_output') ;
    
    % experiments already saved in Box Data
    if ~isempty(BoxData) ,
        already_saved_experiment_names = {BoxData(:).experiment_name};        
    else
        already_saved_experiment_names = {};
    end
    
    % Delete any to-be-forced experiments from the BoxData
    do_delete = ismember(already_saved_experiment_names, experiment_names_to_force) ;
    BoxData = BoxData(~do_delete) ;
    if isempty(BoxData) ,
        experiment_names_in_box_data = cell(1,0) ;
    else        
        experiment_names_in_box_data = {BoxData(:).experiment_name} ;
    end
    
    %cd(fullfile(box_data_folder_path)) ;
    
    raw_experiment_names = simple_dir(fullfile(box_data_folder_path)) ;
    half_baked_experiment_names = setdiff(raw_experiment_names, {'.','..','.DS_Store','bad_experiments','old_controls'}) ;
    %files(~ismember(file_names,{'.','..'}));
    
    % filter, keeping just the folders
    is_folder = logical(cellfun(@(name)(exist(fullfile(box_data_folder_path, name), 'dir')), half_baked_experiment_names)) ;
    experiment_names = half_baked_experiment_names(is_folder) ;
    
    for experiment_index = 1:length(experiment_names)
        experiment_name = experiment_names{experiment_index} ;
        if ~ismember(experiment_name, experiment_names_in_box_data) ,
            try
                [was_tracked, box_data_for_this_experiment] = ...
                    gather_data_from_one_experiment_folder(...
                        box_data_folder_path, experiment_name, ...
                        box_data_merge_output_folder_path, box_data_analysis_output_folder_path, ...
                        minimum_fly_count) ;
                
                if was_tracked ,         
                    good_tube_count = length(box_data_for_this_experiment.tubes) ;  % A tube is "good" if it has enough flies
                    if good_tube_count >= minimum_good_tube_count ,
                        % This experiment is good enough, so commit it to BoxData
                        n_entries_so_far = length(BoxData) ;
                        index_for_this_entry = n_entries_so_far + 1 ;
                        if index_for_this_entry == 1 ,
                            BoxData = box_data_for_this_experiment ;  % have to get the field names right
                        else
                            BoxData(1,index_for_this_entry) = box_data_for_this_experiment ;
                        end
                        fprintf('Experiment %s gathered into BoxData.mat.\n', experiment_name) ;
                    else
                        fprintf('Experiment %s has %d tube(s) with enough flies, but the minimum is %d.  Not gathering into BoxData.mat.\n', ...
                                experiment_name, ...
                                good_tube_count, ...
                                minimum_good_tube_count) ;
%                         bad_experiments_folder_path = fullfile(box_data_folder_path, 'bad_experiments') ;
%                         if ~exist(bad_experiments_folder_path, 'dir') ,
%                             mkdir(bad_experiments_folder_path) ;
%                         end
%                         experiment_folder_path = fullfile(box_data_folder_path, experiment_name) ;
%                         movefile(experiment_folder_path, bad_experiments_folder_path) ;
                    end                
                else
                    fprintf('Experiment %s has not been tracked, so can''t gather into BoxData.mat.\n', experiment_name) ;
                end
            catch me
                me.getReport()
                warning('Problem with "experiment" folder %s.  Maybe it''s not really an experiment folder?', experiment_name) ;
            end
        else
            fprintf('Experiment %s already gathered into BoxData.mat, so not re-gathering.\n', experiment_name) ;      
        end
    end  % loop over experiment_names
    
    % Removes any empty entries
    BoxData(cellfun('isempty',{BoxData.genotype})) = [] ;
    
    save(box_data_mat_path, '-mat', 'BoxData') ;
end



