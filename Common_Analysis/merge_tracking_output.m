function merge_tracking_output(experiment_input_folder_path, ...
                               output_of_previous_analysis_folder_name, ...
                               experiment_output_folder_path)
    % Contatenate the individual analysis_info and success files.  These files,
    % produced by a previous stage of analysis, hold information about the
    % flies positions and velocities, and whether tracking was successful or
    % not.
    %
    % One input is the .exp file for the experiment, assumed to live in
    % experiment_input_folder_path.
    %
    % Other inputs are analysis_info.mat files, one for each (temperature protocol,
    % sequence, tube) triple, and trak_success.mat files, also one for each (temperature protocol,
    % sequence, tube).  These live under
    % output_of_previous_analysis_folder_name, within
    % experiment_input_folder_path.
    %
    % Outputs are files with names like 01_5.34_seq3_analysis_info.mat, one
    % file per (temperature protocol, sequence) pair; and a file named
    % something like success_20180501T181047.mat, one file per experiment.
    % (That date-time string is based on the time this function was run.)
    % These are stored in a folder structure parallel to that of the
    % analysis_info.mat and trak_success.mat files, but under
    % experiment_output_folder_path.
        
    %[parent_dir_path, experiment_name, dir_ext, dir_version] = fileparts(experiment_dir_path); %#ok
    [parent_dir_path, experiment_name, dir_ext] = fileparts(experiment_input_folder_path); %#ok    
    
    % The directory will never have an extension or version so put the pieces back together. (BOXPIPE-70)
    %experiment_name = [experiment_name dir_ext dir_version];
    experiment_name = [experiment_name dir_ext];
    
    data = load(fullfile(experiment_input_folder_path, [experiment_name '.exp']), '-mat');
    temp_ind = data.experiment.actionsource(1);
    protocol_name = data.experiment.actionlist(1, temp_ind).name;
    
    tr_ind = 1;
    trak_success_summary = struct([]) ;  % 0x0 struct with no fields
    for temp_ind = data.experiment.actionsource        
        temperature = data.experiment.actionlist(1, temp_ind).T;
        temperature_protocol_name = sprintf('%02d_%s_%d', temp_ind, protocol_name, temperature);
        for seq_ind = 1:8 %num_seqs 
            %clear analysis_info_tube
            per_tube_analysis_info = struct([]) ;  % 0x0 struct with no fields
            for tube_ind = 1:6 %num_tubes
%               tr_name = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
                tube_seq_name = sprintf('%02d_%s_seq%d_tube%d', temp_ind, protocol_name, seq_ind, tube_ind);
                
                %% Merge analysis_info files
                % create empty analysis_info_tube entry
                
                per_tube_analysis_info(tube_ind).avg_vel_x = 0; %#ok<*AGROW>
                per_tube_analysis_info(tube_ind).avg_vel_y = 0;
                per_tube_analysis_info(tube_ind).avg_vel = 0;
                per_tube_analysis_info(tube_ind).median_vel_x = 0;
                per_tube_analysis_info(tube_ind).median_vel_y = 0;
                per_tube_analysis_info(tube_ind).median_vel = 0;
                per_tube_analysis_info(tube_ind).Q1_vel = 0;
                per_tube_analysis_info(tube_ind).Q3_vel = 0;
                per_tube_analysis_info(tube_ind).tracked_num = 0;
                per_tube_analysis_info(tube_ind).moving_fraction = 0;
                per_tube_analysis_info(tube_ind).moving_num = 0;

                per_tube_analysis_info(tube_ind).moving_num_left = 0;
                per_tube_analysis_info(tube_ind).moving_num_right = 0;

                per_tube_analysis_info(tube_ind).avg_mov_vel = 0;
                per_tube_analysis_info(tube_ind).ang_vel = 0;
                per_tube_analysis_info(tube_ind).mutual_dist = 0;
                per_tube_analysis_info(tube_ind).mutual_dist_180 = 0;
                per_tube_analysis_info(tube_ind).start_move_num = 0;
                %analysis_info_tube(tube_ind).pos_hist = 0;
                %analysis_info_tube(tube_ind).move_pos_hist = 0;
                per_tube_analysis_info(tube_ind).max_tracked_num = 0;
                per_tube_analysis_info(tube_ind).version = [];

                %row_ind = temp_ind + (seq_ind-1)*5; 
%               mov_str{row_ind,tube_ind} = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
                %mov_str{row_ind,tube_ind} = tube_seq_name;
%               an_path = [experiment_dir_path filesep 'Output' filesep Temp_prot_str{temp_ind} filesep mov_str{row_ind,tube_ind} filesep 'analysis_info.mat'];
                analysis_info_mat_file_path = ...
                    fullfile(experiment_input_folder_path, ...
                             output_of_previous_analysis_folder_name, ...
                             temperature_protocol_name, ...
                             tube_seq_name, ...
                             'analysis_info.mat');
                does_analysis_info_mat_file_exist = exist(analysis_info_mat_file_path, 'file');
                if does_analysis_info_mat_file_exist ,        
                    analysis_info_mat_file_contents = load(analysis_info_mat_file_path);
                    analysis_info = analysis_info_mat_file_contents.analysis_info ;
                    if isfield(analysis_info, 'avg_vel_x')
                        per_tube_analysis_info(tube_ind) = analysis_info;
                    else
                        %fprintf('No laden analysis_info.mat file for temperature protocol %s, seq%d, tube %d\n', temperature_protocol_name, seq_ind, tube_ind) ;                       
                    end
                else % if the analysis_info file is not there, this must be an error condition or flies in tube
                    %fprintf('No laden analysis_info.mat file for temperature protocol %s, seq%d, tube %d\n', temperature_protocol_name, seq_ind, tube_ind) ;
                end
                
                %% Merge trak_success files
                % create empty Trak_success entry
                trak_success_summary(tr_ind).success = 0; 
                trak_success_summary(tr_ind).error = [];  

                %tr_path = [experiment_dir_path filesep output_base_dir filesep temperature_protocol_name filesep tube_seq_name filesep 'trak_success.mat'];
                trak_success_mat_file_path = fullfile(experiment_input_folder_path, ...
                                                      output_of_previous_analysis_folder_name, ...
                                                      temperature_protocol_name, ...
                                                      tube_seq_name, ...
                                                      'trak_success.mat') ;

                if exist(trak_success_mat_file_path, 'file') ,       
                    trak_success_mat_file_contents = load(trak_success_mat_file_path);
                    this_trak_success = trak_success_mat_file_contents.Trak_success ;
                    if isfield(this_trak_success, 'success')
                        trak_success_summary(tr_ind) = this_trak_success; 
                    end
                    %clear Trak_success
                end
                tr_ind = tr_ind + 1;
            end
            
%           an_save_path = [experiment_dir_path filesep 'Output' filesep Temp_prot_str filesep Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_analysis_info.mat'];
            per_tube_analysis_info_file_name = sprintf('%02d_%s_seq%d_analysis_info.mat', temp_ind, protocol_name, seq_ind) ;
            per_tube_analysis_info_file_path = fullfile(experiment_output_folder_path, ...
                                                        temperature_protocol_name, ...
                                                        per_tube_analysis_info_file_name) ;

            try
                ensure_parent_folder_exists(per_tube_analysis_info_file_path) ;
                save_as(per_tube_analysis_info_file_path, 'analysis_info_tube', per_tube_analysis_info) ;
            catch ME
               warning('Olympiad:FailToWrite', 'Can''t write analysis_info_tube to %s (%s)', per_tube_analysis_info_file_path, ME.message);
            end        
        end
    end
    %Trak_success = all_Trak_success; %#ok
    date_and_time_right_now_as_string = datestr(now(), 30);  % 30 is a code that means 'yyyymmddTHHMMSS' (ISO 8601) format
    trak_success_summary_mat_file_name = sprintf('success_%s.mat', date_and_time_right_now_as_string) ;
    trak_success_summary_mat_file_path = fullfile(experiment_output_folder_path, ...
                                                  trak_success_summary_mat_file_name);
    try
        save_as(trak_success_summary_mat_file_path, 'Trak_success', trak_success_summary);
    catch ME
       warning('Olympiad:FailToWrite', 'Can''t write Trak_success to %s (%s)', trak_success_summary_mat_file_path, ME.message);
    end        
end

