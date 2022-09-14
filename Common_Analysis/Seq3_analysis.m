% Seq3.m

% this script runs the analysis for sequence 3 and generates one figure

% movie 3: seq3.avi goes from 495 s to 740 s, times are from movie
% vidaction (12:59), 2 on/2 off Linear motion pattern at various speeds.  At each speed, pattern moves
% first from right to left, and then from left to right.  Each change in
% speed and/or direction is accompanied by full intensity vibration
% LIGHT CHANGES
% [vidaction(12:4:59).time]:  [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625] (command 7 0 n 1 0 [n = 0 250, 63, 31, 13, 6])
% [vidaction(14:4:59).time]:  [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875] (command 7 0 n 0 0 [n = 0 250, 63, 31, 13, 6])
% VIBRATION
% [vidaction(13:4:59).time]:  [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625] (command 2 5 255 0 0)
% [vidaction(15:4:59).time]:  [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875] (command 2 5 255 0 0)


%% extract summarizing values to use for later analysis
for tube_num = 1:6
    
    analysis_results(tube_num).seq3 = Common_analysis(analysis_info_tube(tube_num));
    
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % that is, if there is data for this tube
        analysis_results(tube_num).seq3.med_vel_x = analysis_info_tube(tube_num).median_vel_x;
        analysis_results(tube_num).seq3.direction_index = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num;
        
        
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq3 = set_field_to_zero(analysis_results(tube_num).seq3, ...
        {'med_vel_x' 'direction_index'});
    end
end

%% make plots using median velocity x
y_lim = 20; % limit in mm/s on the y axes
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625];
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875];
frames_per_trial = 250; 
t = (1:6125)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

plot_speeds = [0 1 4 8 20 42 42 20 8 4 1 0];

figure(2) 
set(2, 'Position', [60 30 950 700]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,3,(tube_num-1)*3 + 1) % this plot the time series in column 1
    if tfTubeHasValidData  
        med_x_vel = analysis_results(tube_num).seq3.med_vel_x(1:end-1);
        plot(t, ma(med_x_vel, ma_points), 'k') % put in an n-point moving average, only for plot
        hold on
        plot(X_dir1_time_plot, repmat([0 y_lim], 12, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim], 12, 1)',  'r')
    end

    axis([0 t(end) -y_lim y_lim]); box off
    set(gca,'Ytick', [-y_lim 0 y_lim]);
    if tube_num == 1
        text(440,28,'median X velocity, Optomotor (seq 3)',  'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end       

    subplot(6,3,((tube_num)*3) -1 ) % this plots the averaged series in column 2
    Nstart = length(dir1_starts);
    pos_vel_data = nan(1,Nstart);
    neg_vel_data = nan(1,Nstart);
%    pos_dirpref_data = nan(1,Nstart);
%    neg_dirpref_data = nan(1,Nstart);
    if tfTubeHasValidData
    
        med_x_vel = analysis_results(tube_num).seq3.med_vel_x(1:end-1);
%         mov_n_lft = analysis_results(tube_num).seq3.moving_num_left(1:end-1);
%         mov_n_rgt = analysis_results(tube_num).seq3.moving_num_right(1:end-1);
%         assert(isequal(size(med_x_vel),size(mov_n_lft),size(mov_n_rgt)));

        % calculate directional pref statistic
%        num_flies = exp_detail.tube_info(tube_num).n;
        %dir_pref = (mov_n_rgt - mov_n_lft)/num_flies;

        for k = 1:length(dir1_starts)
            dir1Idxs = (dir1_starts(k)+0):(dir1_starts(k)+200);
            dir2Idxs = (dir2_starts(k)+0):(dir2_starts(k)+200);
            pos_vel_data(k) = mean( med_x_vel( dir1Idxs ));
            neg_vel_data(k) = mean( med_x_vel( dir2Idxs ));
%             pos_dirpref_data(k) = mean( dir_pref( dir1Idxs ) );
%             neg_dirpref_data(k) = mean( dir_pref( dir2Idxs ) );
        end

        plot(pos_vel_data, 'ok-');
        hold on
        plot(neg_vel_data, 'or-');
        set(gca, 'Xtick', 1:12)
    end

    if tube_num == 6
        xlabel('Temporal Frequency') 
        set(gca, 'Xticklabel', plot_speeds)
    else
        set(gca, 'XTickLabel', []); 
    end  

    axis([0.5 12.5 -y_lim y_lim]); box off

     subplot(6,3,((tube_num)*3))  % this plots the averaged response to reach speed in column 3
     if tfTubeHasValidData
    
         all_vel_data = [ ...
             pos_vel_data(1:6); ...
             pos_vel_data(12:-1:7); ...
             -neg_vel_data(1:6); ...
             -neg_vel_data(12:-1:7) ];
         
%          all_dirpref_data = [ ...
%              pos_dirpref_data(1:6); ...
%              pos_dirpref_data(12:-1:7); ...
%              -neg_dirpref_data(1:6); ...
%              -neg_dirpref_data(12:-1:7) ];
         
         % save mean moving responses as a vector
         analysis_results(tube_num).seq3.mean_motion_resp = mean(all_vel_data,1);
         analysis_results(tube_num).seq3.std_motion_resp = std(all_vel_data,1);
%          analysis_results(tube_num).seq3.mean_dirpref = mean(all_dirpref_data,1);
         
         % calculate a simple motion modulation: the difference between the
         % mean of the 8 and 20 Hz response and the 0 and 1 hz response
         motion_resp = mean(all_vel_data,1);
         analysis_results(tube_num).seq3.motion_resp_diff = mean(motion_resp(4:5)) - mean(motion_resp(1:2));
           
         errorbar(mean(all_vel_data,1), std(all_vel_data,1), 'k.-', 'MarkerSize', 15)
     else
        analysis_results(tube_num).seq3 = set_field_to_zero(analysis_results(tube_num).seq3, ...
        {'mean_motion_resp', 'std_motion_resp', 'motion_resp_diff'});
         
     end
     
     set(gca, 'Xtick', [1:6])
     axis([0.75 6.25 -2 y_lim]); box off

     text(6.5, y_lim*1.07, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none')
     
     if tube_num == 6
        xlabel('Temporal Frequency') 
        set(gca, 'Xticklabel', plot_speeds(1:6))
        text(3, -18, ['DateTime: ' exp_detail.date_time])
    else
        set(gca, 'XTickLabel', []); 
    end  
end
    
    
 % now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq3_LinMotion_median_x_velocity_&_average.pdf']);
end

%% make plots using direction index
y_lim = 1; % limit in mm/s on the y axes
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625];
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875];
frames_per_trial = 250; 
t = (1:6125)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

plot_speeds = [0 1 4 8 20 42 42 20 8 4 1 0];

figure(3) 
set(3, 'Position', [60 30 950 700]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,3,(tube_num-1)*3 + 1) % this plot the time series in column 1
    if tfTubeHasValidData  
        direction_index = analysis_results(tube_num).seq3.direction_index(1:end-1);
        plot(t, ma(direction_index, ma_points), 'k') % put in an n-point moving average, only for plot
        hold on
        plot(X_dir1_time_plot, repmat([0 y_lim], 12, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim], 12, 1)',  'r')
    end

    axis([0 t(end) -y_lim y_lim]); box off
    set(gca,'Ytick', [-y_lim 0 y_lim]);
    if tube_num == 1
        text(440,1.4*y_lim,'direction index, Optomotor (seq 3)',  'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end       

    subplot(6,3,((tube_num)*3) -1 ) % this plots the averaged series in column 2
    Nstart = length(dir1_starts);
    pos_dir_data = nan(1,Nstart);
    neg_dir_data = nan(1,Nstart);
    if tfTubeHasValidData
    
        direction_index = analysis_results(tube_num).seq3.direction_index(1:end-1);

        for k = 1:length(dir1_starts)
            dir1Idxs = (dir1_starts(k)+0):(dir1_starts(k)+200);
            dir2Idxs = (dir2_starts(k)+0):(dir2_starts(k)+200);
            pos_dir_data(k) = mean( direction_index( dir1Idxs ));
            neg_dir_data(k) = mean( direction_index( dir2Idxs ));
        end

        plot(pos_dir_data, 'ok-');
        hold on
        plot(neg_dir_data, 'or-');
        set(gca, 'Xtick', 1:12)
    end

    if tube_num == 6
        xlabel('Temporal Frequency') 
        set(gca, 'Xticklabel', plot_speeds)
    else
        set(gca, 'XTickLabel', []); 
    end  

    axis([0.5 12.5 -y_lim y_lim]); box off

     subplot(6,3,((tube_num)*3))  % this plots the averaged response to reach speed in column 3
     if tfTubeHasValidData
    
         all_dir_data = [ ...
             pos_dir_data(1:6); ...
             pos_dir_data(12:-1:7); ...
             -neg_dir_data(1:6); ...
             -neg_dir_data(12:-1:7) ];
         
         % save mean moving responses as a vector
         analysis_results(tube_num).seq3.mean_dir_index = mean(all_dir_data,1);
         analysis_results(tube_num).seq3.std_dir_index = std(all_dir_data,1);
         
         % calculate a simple motion modulation: the difference between the
         % mean of the 8 and 20 Hz response and the 0 and 1 hz response
         dir_resp = mean(all_dir_data,1);
         analysis_results(tube_num).seq3.dir_index_diff = mean(dir_resp(4:5)) - mean(dir_resp(1:2));
           
         errorbar(mean(all_dir_data,1), std(all_dir_data,1), 'k.-', 'MarkerSize', 15)
     else
        analysis_results(tube_num).seq3 = set_field_to_zero(analysis_results(tube_num).seq3, ...
        {'mean_dir_index', 'std_dir_index', 'dir_index_diff'});
         
     end
     
     set(gca, 'Xtick', [1:6])
     axis([0.75 6.25 -0.1 0.8*y_lim]); box off

     text(6.5, y_lim, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none')
     
     if tube_num == 6
        xlabel('Temporal Frequency') 
        set(gca, 'Xticklabel', plot_speeds(1:6))
        text(3, -18, ['DateTime: ' exp_detail.date_time])
    else
        set(gca, 'XTickLabel', []); 
    end  
end
    
    
 % now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq3_LinMotion_direction_index_&_average.pdf']);
end

