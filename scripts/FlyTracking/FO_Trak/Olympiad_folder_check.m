%Olympiad_folder_check.m
%only suited for protocol 3.0
%currently a script, so will use existing outDir
Temp_str{1} = '01';
Temp_str{2} = '02';

Temp_prot_str{1} = '01_3.0_24';
Temp_prot_str{2} = '02_3.0_34';

% now convert An to analysis_info_tube
for temp_ind = 1:2 %for two temps
    for seq_ind = 1:5 %num_seqs 
        clear analysis_info_tube
        for tube_ind = 1:6 %num_tubes
                % create empty analysis_info_tube entry
                analysis_info_tube(tube_ind).avg_vel_x = 0;
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
                analysis_info_tube(tube_ind).avg_mov_vel = 0;
                analysis_info_tube(tube_ind).ang_vel = 0;
                analysis_info_tube(tube_ind).mutual_dist = 0;
                analysis_info_tube(tube_ind).mutual_dist_180 = 0;
                analysis_info_tube(tube_ind).start_move_num = 0;
                analysis_info_tube(tube_ind).pos_hist = 0;
                analysis_info_tube(tube_ind).move_pos_hist = 0;
                analysis_info_tube(tube_ind).max_tracked_num = 0;
            row_ind = temp_ind + (seq_ind-1)*5; 
            %[temp_ind seq_ind tube_ind row_ind]
            mov_str{row_ind,tube_ind} = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
            %display(['Merging analysis_info ' mov_str{row_ind,tube_ind}]);
            an_path = [outDir filesep 'Output' filesep Temp_prot_str{temp_ind} filesep mov_str{row_ind,tube_ind} filesep 'analysis_info.mat'];
            An_exists(row_ind, tube_ind) = exist(an_path);
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
        end
        an_save_path = [outDir filesep 'Output' filesep Temp_prot_str{temp_ind} filesep Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_analysis_info.mat'];
        try
            save(an_save_path, 'analysis_info_tube') 
        catch
           warning('Can''t write analysis_info_tube, probably becuase the folder does not exist (%s)', an_save_path);
        end        
    end
end
