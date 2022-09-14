function merge_analysis_output(experiment_dir_path,output_base_dir)
    % Contatenate the individual analysis_info and success files.
    
    %% Check the arguments
    if nargin < 2
      output_base_dir = 'Output';
    end
    
    cd(experiment_dir_path)
    
    %[parent_dir_path, experiment_name, dir_ext, dir_version] = fileparts(experiment_dir_path); %#ok
    [parent_dir_path, experiment_name, dir_ext] = fileparts(experiment_dir_path); %#ok    
    
    % The directory will never have an extension or version so put the pieces back together. (BOXPIPE-70)
    %experiment_name = [experiment_name dir_ext dir_version];
    experiment_name = [experiment_name dir_ext];
    
    data = load(fullfile(experiment_dir_path, [experiment_name '.exp']), '-mat');
    temp_ind = data.experiment.actionsource(1);
    protocol = data.experiment.actionlist(1, temp_ind).name;
    
    tr_ind = 1;
    for temp_ind = data.experiment.actionsource
        temp = data.experiment.actionlist(1, temp_ind).T;
        Temp_prot_str = sprintf('%02d_%s_%d', temp_ind, protocol, temp);
        for seq_ind = 1:5 %num_seqs 
            clear analysis_info_tube
            for tube_ind = 1:6 %num_tubes
%               tr_name = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
                tube_seq_name = sprintf('%02d_%s_seq%d_tube%d', temp_ind, protocol, seq_ind, tube_ind);
                
                %% Merge analysis_info files
                % create empty analysis_info_tube entry
                analysis_info_tube(tube_ind).avg_vel_x = 0; %#ok<*AGROW>
                analysis_info_tube(tube_ind).avg_vel_y = 0;
                analysis_info_tube(tube_ind).avg_vel = 0;
                analysis_info_tube(tube_ind).median_vel_x = 0;
                analysis_info_tube(tube_ind).median_vel_y = 0;
                analysis_info_tube(tube_ind).median_vel = 0;
                analysis_info_tube(tube_ind).Q1_vel = 0;
                analysis_info_tube(tube_ind).Q3_vel = 0;
                analysis_info_tube(tube_ind).tracked_num = 0;
                analysis_info_tube(tube_ind).moving_fraction = 0;
                analysis_info_tube(tube_ind).moving_num = 0;

                analysis_info_tube(tube_ind).moving_num_left = 0;
                analysis_info_tube(tube_ind).moving_num_right = 0;

                analysis_info_tube(tube_ind).avg_mov_vel = 0;
                analysis_info_tube(tube_ind).ang_vel = 0;
                analysis_info_tube(tube_ind).mutual_dist = 0;
                analysis_info_tube(tube_ind).mutual_dist_180 = 0;
                analysis_info_tube(tube_ind).start_move_num = 0;
%                 analysis_info_tube(tube_ind).pos_hist = 0;
%                 analysis_info_tube(tube_ind).move_pos_hist = 0;
                analysis_info_tube(tube_ind).max_tracked_num = 0;
                analysis_info_tube(tube_ind).version = [];

                row_ind = temp_ind + (seq_ind-1)*5; 
%               mov_str{row_ind,tube_ind} = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
                mov_str{row_ind,tube_ind} = tube_seq_name;
%               an_path = [experiment_dir_path filesep 'Output' filesep Temp_prot_str{temp_ind} filesep mov_str{row_ind,tube_ind} filesep 'analysis_info.mat'];
                an_path = [experiment_dir_path filesep output_base_dir filesep Temp_prot_str filesep mov_str{row_ind,tube_ind} filesep 'analysis_info.mat'];
                An_exists(row_ind, tube_ind) = exist(an_path, 'file');
                if An_exists(row_ind,tube_ind) == 2       
                    load(an_path);
                    if isfield(analysis_info, 'avg_vel_x')
                        analysis_info_tube(tube_ind) = analysis_info;
                    end
                    clear analysis_info
                else % if the analysis_info file is not there, this must be an error condition or flies in tube
                    % create empty analysis_info_tube entry
                    % no need to do anything since the entries are initialized
                    % to be empty
                end
                
                %% Merge trak_success files
                % create empty Trak_success entry
                All_Trak_success(tr_ind).success = 0; 
                All_Trak_success(tr_ind).error = [];  

                tr_path = [experiment_dir_path filesep output_base_dir filesep Temp_prot_str filesep tube_seq_name filesep 'trak_success.mat'];
                if exist(tr_path, 'file') == 2       
                    load(tr_path);
                    if isfield(Trak_success, 'success') %#ok
                        All_Trak_success(tr_ind) = Trak_success; 
                    end
                    clear Trak_success
                end
                tr_ind = tr_ind + 1;
            end
            
%           an_save_path = [experiment_dir_path filesep 'Output' filesep Temp_prot_str filesep Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_analysis_info.mat'];
            an_save_path = [experiment_dir_path filesep output_base_dir filesep Temp_prot_str filesep sprintf('%02d_%s_seq%d_analysis_info.mat', temp_ind, protocol, seq_ind)];
            try
                save(an_save_path, 'analysis_info_tube') 
            catch ME
               warning('Olympiad:FailToWrite', 'Can''t write analysis_info_tube to %s (%s)', an_save_path, ME.message);
            end        
        end
    end
    Trak_success = All_Trak_success; %#ok
    now_str = datestr(now, 30);
    tr_save_path = [experiment_dir_path filesep output_base_dir filesep 'success_' now_str '.mat'];
    try
        save(tr_save_path, 'Trak_success');
    catch ME
       warning('Olympiad:FailToWrite', 'Can''t write Trak_success to %s (%s)', tr_save_path, ME.message);
    end        
