%% minimal_motion_analysis.m
%
%#ok<*SAGROW>
%
% This script analyzes data for sequences where only response to linear 
% motion is assayed.  Before it is called, the following variables must be 
% defined in the workspace:
%
% sequence:      the designation of this sequence (seq3)
% min_num_flies: the minimum number of flies required to track (2)
% del_t:         inverse frame rate (1/25)
% dir1_starts:   start frames for direction 1, right-to-left 
% dir2_starts:   start frames for direction 2, left-to-right
% trial_length:  duration of a single trial in frames (250)
% ma_points:     number of points to use for smoothing (8)
% plot_conditions:    stimulus conditions
% x_variable:    string to set xlabel
% main_title:    sequence description

%% Generate list of event frames
 
offset = dir1_starts(1);
trial_length = 100;
trial_time = trial_length*del_t;
num_conditions = length(dir1_starts);
data_length = dir2_starts(end) + trial_length - offset;


%% Generate and store common analysis and sequence specific analysis

for tube_num = 1:6
    analysis_results(tube_num).(sequence) = ...
        Common_analysis(analysis_info_tube(tube_num));
    
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % if there is data for this tube
        % transfer median x velocity sequence
        analysis_results(tube_num).(sequence).med_vel_x = ...
            analysis_info_tube(tube_num).median_vel_x;
        % calculate direction_index as R-L/total
        analysis_results(tube_num).(sequence).direction_index = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num;

    else % otherwise populate all fields with zero.
        analysis_results(tube_num).(sequence) = ...
            set_field_to_zero(analysis_results(tube_num).(sequence), ...
            {'med_vel_x', 'direction_index'});
    end
end


% pre-allocate arrays for storing velocity and displacement series
pos_vel_data = nan(6, num_conditions);
neg_vel_data = nan(6, num_conditions);

pos_dir_data = nan(6, num_conditions);
neg_dir_data = nan(6, num_conditions);

all_vel_data = nan(6, 2, num_conditions);
all_dir_data = nan(6, 2, num_conditions);

motion_resp = nan(6, num_conditions);
dir_resp = nan(6, num_conditions);

for tube_num = 1:6
    % only generate a plot if flies are in the tube
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
   
    if tfTubeHasValidData  
        med_x_vel(tube_num, 1:length(analysis_results(tube_num).(sequence).med_vel_x(1:end-1))) = ...
            analysis_results(tube_num).(sequence).med_vel_x(1:end-1);
        direction_index(tube_num, 1:length(analysis_results(tube_num).(sequence).direction_index(1:end-1))) = ...
            analysis_results(tube_num).(sequence).direction_index(1:end-1);
        
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+trial_length-1);
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+trial_length-1);
            dataIdx = trial_length*(k-1) + (1:trial_length);
            
            % fetch median x velocity per direction
            pos_vel_data(tube_num, k) = ...
                mean(med_x_vel(tube_num, dir2Idxs));
            neg_vel_data(tube_num, k) = ...
                mean(med_x_vel(tube_num, dir1Idxs));
            
            pos_dir_data(tube_num,k) = ...
                mean(direction_index(tube_num, dir2Idxs));
            neg_dir_data(tube_num,k) = ...
                mean(direction_index(tube_num, dir1Idxs));
        end
        
        all_vel_data(tube_num, :, :) = ...
            [pos_vel_data(tube_num, 1:num_conditions);
            -neg_vel_data(tube_num, 1:num_conditions);];
        
        all_dir_data(tube_num, :, :) = ...
            [pos_dir_data(tube_num, 1:num_conditions);
             -neg_dir_data(tube_num, 1:num_conditions);];
     
        motion_resp(tube_num, :) = mean(all_vel_data(tube_num, :, :), 2);
        dir_resp(tube_num, :) = mean(all_dir_data(tube_num, :, :), 2);
        
        analysis_results(tube_num).(sequence).mean_motion_resp = ...
            mean(all_vel_data(tube_num, :, :), 2);
        analysis_results(tube_num).(sequence).std_motion_resp = ...
            std(all_vel_data(tube_num, :, :), 0, 2);
        
        analysis_results(tube_num).(sequence).mean_dir_index = ...
            mean(all_dir_data(tube_num, :, :), 2);
        analysis_results(tube_num).(sequence).std_dir_index = ...
            std(all_dir_data(tube_num, :, :), 0, 2);
        
        % calculate a simple motion modulation: the difference between the
        % mean of the 8 and 20 Hz response and the 0 and slowest hz response
        analysis_results(tube_num).(sequence).motion_resp_diff = ...
            mean(motion_resp(tube_num,2:3)) - mean(motion_resp(tube_num,1:2)); %FIXME: parameterize?
        analysis_results(tube_num).(sequence).dir_index_diff = ...
            mean(dir_resp(tube_num,2:3)) - mean(dir_resp(tube_num,1:2)); %FIXME: parameterize?

     else
        analysis_results(tube_num).(sequence) = ...
            set_field_to_zero(analysis_results(tube_num).(sequence), ...
            {'mean_motion_resp', 'std_motion_resp', 'motion_resp_diff', ...
             'mean_dir_index', 'std_dir_index', 'dir_index_diff'});
     end
end


%% Plotting Parameters

y_lim_vel = 20;
y_lim_DI = 1;
t = (1:(data_length+400))*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;


%% Generate complete time series plot


figure(1) 
set(1, 'Position', [60 30 950 700]);

for tube_num = 1:6,

    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);

    % MEDIAN X VELOCITY TIME SERIES
    subplot(6, 3, (tube_num-1)*3 + 1)
    
    if tfTubeHasValidData
        plot(t, ma(med_x_vel(tube_num,:), ma_points), 'k') % put in an n-point moving average, only for plot
        hold on
        
        plot(X_dir1_time_plot, repmat([0 y_lim_vel], num_conditions, 1)', 'r') % red markers to indicate stimulus events
        plot(X_dir2_time_plot, repmat([0 -y_lim_vel], num_conditions, 1)', 'r')
    end
    
    axis([0 t(end) -y_lim_vel y_lim_vel]); 
    box off
    set(gca, 'Ytick', [-y_lim_vel 0 y_lim_vel]);
    
    if tube_num == 1
        text(t(end)/2, 1.4*y_lim_vel, ...
             'median X velocity, optomotor', ...
             'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % MEDIAN X VELOCITY AVERAGED TIME SERIES, "lips plots"
    subplot(6, 3, ((tube_num)*3) - 1)
    
    if tfTubeHasValidData
        plot(pos_vel_data(tube_num, :), 'ok-');
        hold on
        plot(neg_vel_data(tube_num, :), 'or-');
    end
    
    set(gca, 'Xtick', 1:num_conditions)
    
    if tube_num == 6
        xlabel(x_variable) 
        set(gca, 'Xticklabel', plot_conditions)
    else
        set(gca, 'XTickLabel', []); 
    end
    
    hold on
    axis([0.5 num_conditions+0.5 -y_lim_vel y_lim_vel]);
    box off
    set(gca, 'Ytick', [-y_lim_vel 0 y_lim_vel]);

    % AVERAGE MEDIAN X VELOCITY
    subplot(6, 3, ((tube_num)*3))  % this plots the averaged response to reach speed in column 3
    if tfTubeHasValidData
        errorbar(motion_resp(tube_num,:), ...
                 std(all_vel_data(tube_num, :, :), 0, 2), ...
                 'k.-', 'MarkerSize', 15)
    end
    
    set(gca, 'Xtick', (1:num_conditions))
    axis([0.75 num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);

    box off
    text(num_conditions, 1.15*y_lim_vel, ... 
         [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
         'HorizontalAlignment', 'right', ...
         'Interpreter', 'none', ...
         'FontSize', 7)
    if tube_num == 6

        xlabel(x_variable)
        set(gca, 'Xticklabel', plot_conditions(1:num_conditions))
        
    else
        set(gca, 'XTickLabel', []); 
    end
    
    
    
end

text(num_conditions, -0.8*y_lim_vel, ...
     ['DateTime: ' exp_detail.date_time], ...
      'FontSize', 7, ...
      'HorizontalAlignment', 'right') % annotate with date and time

suptitle(main_title)

% now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_' sequence '_LinMotion_median_x_velocity_and_average.pdf']);
end


%% Generate direction index plots

figure(2) 
set(2, 'Position', [60 30 950 700]);

for tube_num = 1:6
    % only generate a plot if flies are in the tube
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);

    % DIRECTION INDEX time series
    subplot(6, 3, (tube_num-1)*3 + 1) % this plot the time series in column 1
    
    if tfTubeHasValidData,
        plot(t, ma(direction_index(tube_num,:), ma_points), 'k') % put in an n-point moving average, only for plot
        hold on
        
        plot(X_dir1_time_plot, repmat([0 y_lim_DI], num_conditions, 1)', 'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim_DI], num_conditions, 1)', 'r')

    end
    
    axis([0 t(end) -y_lim_DI y_lim_DI]);
    box off
    set(gca, 'Ytick', [-y_lim_DI 0 y_lim_DI]);
    
    if tube_num == 1
        text(t(end)/2, 1.15*y_lim_DI, ...
             'direction index, optomotor', ...
             'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end       

    % DIRECTION INDEX "lips plots"
    subplot(6,3,((tube_num)*3) - 1) % this plots the averaged series in column 2
    
    if tfTubeHasValidData,
        plot(pos_dir_data(tube_num, :), 'ok-');
        hold on
        plot(neg_dir_data(tube_num, :), 'or-');
    end
    
    set(gca, 'Xtick', 1:length(plot_conditions))
    
    if tube_num == 6
        xlabel(x_variable) 
        set(gca, 'Xticklabel', plot_conditions)
    else
        set(gca, 'XTickLabel', []); 
    end
    
    hold on
    axis([0.5 num_conditions+0.5 -y_lim_DI y_lim_DI]);
    box off
    
    % MEAN DIRECTION INDEX
    subplot(6, 3, ((tube_num)*3))  % this plots the averaged response to reach speed in column 3
    if tfTubeHasValidData,
        errorbar(dir_resp(tube_num, :), ...
                 std(all_dir_data(tube_num, :, :), 0, 2), ...
                 'k.-', ...
                 'MarkerSize', 15)
    end

    set(gca, 'Xtick', (1:num_conditions))
    axis([0.75 num_conditions+0.25 -0.1*y_lim_DI 0.8*y_lim_DI]);

    box off
    
    text(num_conditions, 0.8*1.15*y_lim_DI, ...
         [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
         'HorizontalAlignment', 'right', ...
         'Interpreter', 'none', ...
         'FontSize', 7)
    
     if tube_num == 6

        xlabel(x_variable) 
        text(3, -18, ['DateTime: ' exp_detail.date_time])
        set(gca, 'Xticklabel', plot_conditions(1:num_conditions))

     else
        set(gca, 'XTickLabel', []); 
    end  
end

text(num_conditions, -0.8*y_lim_DI, ...
     ['DateTime: ' exp_detail.date_time], ...
      'FontSize', 7, ...
      'HorizontalAlignment', 'center') % annotate with date and time    

suptitle(main_title)

% now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_' sequence '_LinMotion_direction_index_and_average.pdf']);
end


%% Clean up
clear med_x_vel
clear direction_index

clear pos_vel_data
clear neg_vel_data

clear pos_dir_data
clear neg_dir_data

clear all_vel_data
clear all_dir_data

clear motion_resp
clear dir_resp

close all
