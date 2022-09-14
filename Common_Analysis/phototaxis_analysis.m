%% phototaxis_analysis.m
%
%#ok<*SAGROW>
%
% This script analyzes data for sequences where phototaxis is assayed. 
% Before it is called, the following variables must be defined in the 
% workspace:
%
% sequence:      the designation of this sequence (seq4)
% min_num_flies: the minimum number of flies required to track (2)
% del_t:         inverse frame rate (1/25)
% dir1_starts:   start frames for direction 1, right-to-left
% dir2_starts:   start frames for direction 2, left-to-right
% ma_points:     number of points to use for smoothing (8)
% X_label:       cell array of Xtick labels like 'G = 25' or 'UV = 36'
% X_label_short: cell array of shortened Xtick labels like 'GL' or 'UH'
% tube_length:   length of tube in mm (112.55)


%% Generate list of event frames

offset = dir1_starts(1);
trial_length = dir2_starts(1) - dir1_starts(1);
%trial_length = 125;
trial_time = trial_length*del_t;
num_conditions = length(dir1_starts);
data_length = dir2_starts(end) + trial_length - offset;


%% Generate and store analysis

for tube_num = 1:6
    % run the common analysis
    analysis_results(tube_num).(sequence) = ...
        Common_analysis(analysis_info_tube(tube_num)); 
    
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % if there is data for this tube
        % calculate direction index as R-L/total
        analysis_info_tube(tube_num).direction_index = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num; 
    else % otherwise populate all fields with zero.
        analysis_info_tube(tube_num).direction_index = 0;
    end
end

% pre-allocate arrays for storing velocity and displacement series
pos_vel_data = nan(6, data_length/2);
neg_vel_data = nan(6, data_length/2);
pos_disp_data = nan(6, data_length/2);
neg_disp_data = nan(6, data_length/2);

% pre-allocate arrays for storing DI and cumulative DI series
pos_dir_data = nan(6, data_length/2);
neg_dir_data = nan(6, data_length/2);
pos_cum_dir_data = nan(6, data_length/2);
neg_cum_dir_data = nan(6, data_length/2);

for tube_num = 1:6
    if length(analysis_info_tube(tube_num).median_vel) > 1 % if there is data for this tube
        % for each set of conditions
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+(trial_length-1));
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+(trial_length-1));
            dataIdx = trial_length*(k-1) + (1:trial_length);
            
            % fetch median x velocity per direction
            pos_vel_data(tube_num, dataIdx) = ...
                analysis_info_tube(tube_num).median_vel_x(dir1Idxs)';
            neg_vel_data(tube_num, dataIdx) = ...
                analysis_info_tube(tube_num).median_vel_x(dir2Idxs)';
            
            % calculate x displacement per direction
            pos_disp_data(tube_num, dataIdx) = ...
                cumsum(analysis_info_tube(tube_num).median_vel_x(dir1Idxs)'*del_t);
            neg_disp_data(tube_num, dataIdx) = ...
                cumsum(analysis_info_tube(tube_num).median_vel_x(dir2Idxs)'*del_t);
            
            % average direction index per direction
            pos_dir_data(tube_num, dataIdx) = ...
                analysis_info_tube(tube_num).direction_index(dir1Idxs)';
            neg_dir_data(tube_num, dataIdx) = ...
                analysis_info_tube(tube_num).direction_index(dir2Idxs)';
            
            % calculate cumulative sum (displacement analog) of DI per
            % direction
            pos_cum_dir_data(tube_num, dataIdx) = ...
                cumsum(analysis_info_tube(tube_num).direction_index(dir1Idxs)'*del_t);
            neg_cum_dir_data(tube_num, dataIdx) = ...
                cumsum(analysis_info_tube(tube_num).direction_index(dir2Idxs)'*del_t);
        end
        
        % store mean med vel x and direction index series
        analysis_results(tube_num).(sequence).med_vel_x = ...
            (pos_vel_data(tube_num, :) - neg_vel_data(tube_num, :))/2;
        analysis_results(tube_num).(sequence).med_disp_x = ...
            (pos_disp_data(tube_num, :) - neg_disp_data(tube_num, :))/2;
        analysis_results(tube_num).(sequence).direction_index = ...
            (pos_dir_data(tube_num, :) - neg_dir_data(tube_num, :))/2;
        analysis_results(tube_num).(sequence).mean_cum_dir_index = ...
            (pos_cum_dir_data(tube_num, :) - neg_cum_dir_data(tube_num, :))/2;
        
        for k = 1:length(dir1_starts)
            % calculate peak displacement, displacement rise, time to peak
            % displacement, and final displacement
            dataIdx = trial_length*(k-1) + (1:trial_length);
            [analysis_results(tube_num).(sequence).disp_max(k), ...
                analysis_results(tube_num).(sequence).disp_rise(k), ...
                dispmaxtime] = ...
                step_rise_time((1:trial_length)*del_t, ...
                analysis_results(tube_num).(sequence).med_disp_x(dataIdx));
            analysis_results(tube_num).(sequence).disp_max_time(k) = ...
                dispmaxtime*del_t;
            analysis_results(tube_num).(sequence).disp_norm_max(k) = ...
                analysis_results(tube_num).(sequence).disp_max(k)/tube_length; % length of tube in mm
            analysis_results(tube_num).(sequence).disp_end(k) = ...
                analysis_results(tube_num).(sequence).med_disp_x(dataIdx(end));
            
            % calculate peak cum DI, cum DI rise, time to peak cum DI, and
            % final cum DI
            [analysis_results(tube_num).(sequence).cum_dir_index_max(k), ...
                analysis_results(tube_num).(sequence).cum_dir_index_rise(k), ...
                dispmaxtime] = ...
                step_rise_time((1:trial_length)*del_t, analysis_results(tube_num).(sequence).mean_cum_dir_index(dataIdx));
            analysis_results(tube_num).(sequence).cum_dir_index_max_time(k) = ...
                dispmaxtime*del_t;
            analysis_results(tube_num).(sequence).cum_dir_index_end(k) = ...
                analysis_results(tube_num).(sequence).direction_index(dataIdx(end));
        end
    else % otherwise populate all fields with zero.
        analysis_info_tube(tube_num).(sequence).med_vel_x = 0;
        analysis_info_tube(tube_num).(sequence).med_disp_x = 0;
        analysis_info_tube(tube_num).(sequence).disp_max = 0;
        analysis_info_tube(tube_num).(sequence).disp_rise = 0;
        analysis_info_tube(tube_num).(sequence).disp_max_time = 0;
        analysis_info_tube(tube_num).(sequence).disp_norm_max = 0;
        analysis_info_tube(tube_num).(sequence).disp_end = 0;
        analysis_info_tube(tube_num).(sequence).direction_index = 0;
        analysis_info_tube(tube_num).(sequence).mean_cum_dir_index = 0;
        analysis_info_tube(tube_num).(sequence).cum_dir_index_max = 0;
        analysis_info_tube(tube_num).(sequence).cum_dir_index_rise = 0;
        analysis_info_tube(tube_num).(sequence).cum_dir_index_max_time = 0;
        analysis_info_tube(tube_num).(sequence).cum_dir_index_end = 0;
    end
end


%% Plotting parameters

t_tick = 0:30:data_length*del_t;
y_lim_vel = 30;
y_lim_disp = 6*y_lim_vel; % (180 for current expts)
y_lim_DI = 1;
y_lim_cum_DI = 8*y_lim_DI; % (8 for current expts)
plot_gap = 40; %DEFINE
time_gap = plot_gap*del_t;


%% Generate complete time series plot

t = (1:(data_length+offset))*del_t;
%t = (1:(9000+offset))*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

figure(1) 
set(1, 'Position', [60 55 800 600]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    % MEDIAN X VELOCITY
    subplot(6, 2, (tube_num-1)*2 + 1)
    if tfTubeHasValidData
        % plot median x velocity
        med_x_vel = analysis_info_tube(tube_num).median_vel_x(1:end-1);
        plot(t, ma(med_x_vel, ma_points), 'k')
        hold on
        % plot markers showing trial starts
        plot(X_dir1_time_plot, repmat([0 y_lim_vel], num_conditions, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim_vel], num_conditions, 1)',  'r')
    end
    axis([0 t(end) -y_lim_vel y_lim_vel]);
    box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-y_lim_vel y_lim_vel]);
    if tube_num == 1
        text(t_tick(end)/2, y_lim_vel*1.5, ...
            'median X velocity, phototaxis', ...
            'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % DIRECTION INDEX
    subplot(6,2,(tube_num)*2 )
    if tfTubeHasValidData
        % plot direction index
        direction_index = analysis_info_tube(tube_num).direction_index(1:end-1);
        plot(t, ma(direction_index, ma_points), 'k')
        hold on
        % plot markers showing trial starts
        plot(X_dir1_time_plot, repmat([0 y_lim_DI], num_conditions, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim_DI], num_conditions, 1)',  'r')
    end
    axis([0 t(end) -y_lim_DI y_lim_DI]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-y_lim_DI y_lim_DI]);
    if tube_num == 1
        text(t_tick(end)/2, 1.65, ...
            'Direction index, phototaxis', ...
            'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end  

    % annotate with genotype and gender
    text(1.2*t_tick(end), 1.16*y_lim_DI, ...
         [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
         'HorizontalAlignment', 'right', ...
         'FontSize', 7, ...
         'Interpreter','none')
end

% save figure
if save_plots
    %save2pdf([analysis_detail.exp_output_path filesep protocol_folder_name '_' sequence '_med_vel_x_and_DI.pdf']);
    pdf_file_path = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_' sequence '_med_vel_x_and_DI.pdf'] ;
    ensure_parent_folder_exists(pdf_file_path) ;
    save2pdf(pdf_file_path);
end


%% Generate median velocity plots

figure(2)
set(2, 'Position', [30 55 1000 600]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);

    % plot the median velocity in column 1
    subplot(6, 6, (tube_num-1)*6 + (1:2))
    time_range = 1;
    if tfTubeHasValidData    
        hold on
        for k = 1:num_conditions
            plot_range = trial_length*(k-1) + (1:trial_length);
            time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
            plot(time_range, ma(analysis_results(tube_num).(sequence).med_vel_x(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_vel]', 'r')   
     
        end
        plot([0 time_range(end)], [0 0], 'r')
    end
    
    axis([0 time_range(end) -0.0833*y_lim_vel y_lim_vel]); 
    box off
    set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
             'Ytick', [0 y_lim_vel], ...
             'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2, 1.15*y_lim_vel, ...
             'med X velocity, phototaxis', ...
             'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    
    % plot the displacement in column 2
    subplot(6, 6, (tube_num-1)*6 + (3:4))
    if tfTubeHasValidData
        hold on
        for k = 1:num_conditions
            plot_range = trial_length*(k-1) + (1:trial_length);
            time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
            plot(time_range, analysis_results(tube_num).(sequence).med_disp_x(plot_range)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_disp]',  'r')   
            
            
            
        end
        plot([0 time_range(end)], [0 0], 'r')
    end
    axis([0 time_range(end) -0.25*y_lim_disp y_lim_disp]); 
    box off
    set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
             'Ytick', [0 y_lim_disp], ...
             'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2, 1.15*y_lim_disp, ...
             'median X displacement (in mm)', ...
             'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak values for the displacement in column 3
    subplot(6, 6, (tube_num-1)*6 + 5)
    if tfTubeHasValidData    
       plot([0 num_conditions+1], [0 0], 'r')
       hold on
       plot(1:num_conditions, analysis_results(tube_num).(sequence).disp_max, 'k.-', 'MarkerSize', 14)
    end
    if tube_num == 1
        text((num_conditions+1)/2, 1.5*y_lim_disp, ...
             'peak disp. (in mm)', ...
             'HorizontalAlignment', 'center')  
    end
    axis([0.5 num_conditions+0.5 -0.25*y_lim_disp y_lim_disp]);
    box off
    set(gca, 'Xtick', 1:num_conditions, ...
             'Ytick', [0 y_lim_disp], ...
             'Xticklabel', X_label_short);
    if tube_num ~= 6
         set(gca, 'XTickLabel', []); 
    end

    % plot the time to peak displacement in column 4
    subplot(6,6,(tube_num-1)*6 + 6)
    if tfTubeHasValidData
       plot([0 num_conditions+1], [0 0], 'r')
       hold on
       plot(1:num_conditions, analysis_results(tube_num).(sequence).disp_rise, 'k.-', 'MarkerSize', 14)
    end
    axis([0.5 num_conditions+0.5 -1 trial_time]);
    box off
    set(gca, 'Xtick', 1:num_conditions, ...
             'Ytick', [0 trial_time], ...
             'Xticklabel', X_label_short);
    if tube_num == 1
        text((num_conditions+1)/2, 1.5*trial_time, ...
             'time to peak (in s)', ...
             'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        text(2*num_conditions+1, -0.33*trial_time, ...
             ['DateTime: ' exp_detail.date_time], ...
             'HorizontalAlignment', 'right', ...
             'FontSize', 7)
    else 
         set(gca, 'XTickLabel', []);              
    end
    
    text(trial_time/2, 17, ...
         [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
         'HorizontalAlignment', 'right', ...
         'Interpreter','none', ...
         'FontSize', 7)
end

% save plots
if save_plots
    %save2pdf([analysis_detail.exp_output_path filesep protocol_folder_name '_' sequence '_avg_vel_disp.pdf']);
    pdf_file_path = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_' sequence '_avg_vel_disp.pdf'] ;
    ensure_parent_folder_exists(pdf_file_path) ;
    save2pdf(pdf_file_path);
end


%% Generate direction index plots

figure(3)
set(3, 'Position', [30 55 1000 600]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);

    % plot the DI in column 1
    subplot(6, 6, (tube_num-1)*6 + (1:2))
    if tfTubeHasValidData
        hold on
        for k = 1:num_conditions
            plot_range = trial_length*(k-1) + (1:trial_length);
            time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
            plot(time_range, ma(analysis_results(tube_num).(sequence).direction_index(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_DI]', 'r')            
        end
        plot([0 time_range(end)], [0 0], 'r')
    end
    axis([0 time_range(end) -0.5*y_lim_DI y_lim_DI]);
    box off
    set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
             'Ytick', [0 y_lim_DI], ...
             'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2, 1.15*y_lim_DI, ...
            'direction index, phototaxis', ...
            'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    
    % plot the cumulative DI in column 2
    subplot(6, 6, (tube_num-1)*6 + (3:4))
    if tfTubeHasValidData
        hold on
        for k = 1:num_conditions
            plot_range = trial_length*(k-1) + (1:trial_length);
            time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
            plot(time_range, analysis_results(tube_num).(sequence).mean_cum_dir_index(plot_range)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_cum_DI]',  'r')            
        end
        plot([0 time_range(end)], [0 0], 'r')
    end
    axis([0 time_range(end) -0.25*y_lim_cum_DI y_lim_cum_DI]);
    box off
    set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
             'Ytick', [0 y_lim_cum_DI], ...
             'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2, 1.15*y_lim_cum_DI, ...
             'cumulative Direction Index', ...
             'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak values for the displacement in column 3
    subplot(6, 6, (tube_num-1)*6 + 5)
    if tfTubeHasValidData    
       plot([0 num_conditions+1], [0 0], 'r')
       hold on
       plot(1:num_conditions, analysis_results(tube_num).(sequence).cum_dir_index_max, 'k.-', 'MarkerSize', 14)
    end
    if tube_num == 1
        text((num_conditions+1)/2, 1.4*y_lim_cum_DI, ...
             'peak CDI', ...
             'HorizontalAlignment', 'center')  
    end
    axis([0.5 num_conditions+0.5 -0.25*y_lim_cum_DI y_lim_cum_DI]);
    box off
    set(gca, 'Xtick', 1:num_conditions, ...
             'Ytick', [0 y_lim_cum_DI], ...
             'Xticklabel', X_label_short);
    if tube_num ~= 6
         set(gca, 'XTickLabel', []); 
    end

    % plot the time to peak displacement
    subplot(6,6,(tube_num-1)*6 + 6)
    if tfTubeHasValidData
       plot([0 num_conditions+1], [0 0], 'r')
       hold on
       plot(1:num_conditions, analysis_results(tube_num).(sequence).cum_dir_index_rise, 'k.-', 'MarkerSize', 14)       
    end
    axis([0.5 num_conditions+0.5 -1 trial_time]);
    box off
    set(gca, 'Xtick', 1:num_conditions, ...
             'Ytick', [0 trial_time], ...
             'Xticklabel', X_label_short);
    if tube_num == 1
        text((num_conditions+1)/2, 1.5*trial_time, ...
             'time to peak (in s)', ...
             'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        text(1, -0.33*trial_time, ...
             ['DateTime: ' exp_detail.date_time], ...
             'HorizontalAlignment', 'right', ...
             'FontSize', 7)
    else 
         set(gca, 'XTickLabel', []);
    end

    text(trial_time/2, 17, ...
        [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', ...
        'Interpreter','none', ...
        'FontSize', 7)
end

% save plots
if save_plots
    %save2pdf([analysis_detail.exp_output_path filesep protocol_folder_name '_' sequence '_cum_direction_index.pdf']);
    pdf_file_path = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_' sequence '_cum_direction_index.pdf'] ;
    ensure_parent_folder_exists(pdf_file_path) ;
    save2pdf(pdf_file_path);
end


%% Clean up
clear offset trial_length trial_time num_conditions data_length ...
    pos_vel_data neg_vel_data pos_disp_data neg_disp_data ...
    pos_dir_data neg_dir_data pos_cum_dir_data neg_cum_dir_data;

close all;