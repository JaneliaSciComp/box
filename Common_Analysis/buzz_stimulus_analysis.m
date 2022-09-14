function buzz_stimulus_analysis(pulse_times, analysis_info_tube, sequence, ...
                                min_num_flies, ...
                                del_t, ...
                                trial_length, ...
                                ma_points, ...
                                exp_detail, ...
                                save_plots, ...
                                analysis_detail, ...
                                protocol_folder_name) 

%% buzz_stimulus_analysis.m
%
%#ok<*SAGROW>
%
% This script analyzes data for sequences where only buzz stimulus (i.e. 
% pager motor) is applied.  Before it is called, the following variables 
% must be defined in the workspace:
%
% sequence:      the designation of this sequence ('seq2')
% min_num_flies: the minimum number of flies required to track (2)
% del_t:         inverse frame rate (1/25)
% pulse_times:   frames at which the stimulus begins (array[num_trials])
% stim_length:   duration of the stimulus in frames %FIXME
% trial_length:  duration of a single trial in frames (750)
% ma_points:     number of points to use for smoothing (4)


%% Generate lists of event frames

post_stim_times = [];       % one second just after pulse
pre_stim_times = [];        % one second just before pulse
long_after_stim_times = []; % 20 - 25 seconds after pulse
ts_average_times = [];      % 5 seconds before to 25 sec after

for j = 1:length(pulse_times)
    post_stim_times = ...
        [post_stim_times (pulse_times(j)+10):(pulse_times(j)+35)]; %#ok<AGROW>
    pre_stim_times = ...
        [pre_stim_times (pulse_times(j)-30):(pulse_times(j)-5)];   %#ok<AGROW>
    long_after_stim_times = ...
        [long_after_stim_times (pulse_times(j)+200):(pulse_times(j)+250)]; %#ok<AGROW>
    ts_average_times = ...
        [ts_average_times; (pulse_times(j)-124):(pulse_times(j)+250)]; %#ok<AGROW>
end


%% Generate and store common analysis and sequence specific analysis

for tube_num = 1:6
    analysis_results(tube_num).(sequence) = ...
        Common_analysis(analysis_info_tube(tube_num));

    if (length(analysis_info_tube(tube_num).median_vel) > 1) % if there is data for this tube
        % 1s before stimulus
        analysis_results(tube_num).(sequence).baseline_mov_frac = ...
            mean(analysis_info_tube(tube_num).moving_fraction(pre_stim_times));
        analysis_results(tube_num).(sequence).baseline_med_vel = ...
            mean(analysis_info_tube(tube_num).median_vel(pre_stim_times));
        
        % 1s after stimulus
        analysis_results(tube_num).(sequence).peak_mov_frac = ...
            mean(analysis_info_tube(tube_num).moving_fraction(post_stim_times));
        analysis_results(tube_num).(sequence).peak_med_vel = ...
            mean(analysis_info_tube(tube_num).median_vel(post_stim_times));
        
        % 20-25s after stimulus
        analysis_results(tube_num).(sequence).long_after_med_vel = ...
            mean(analysis_info_tube(tube_num).median_vel(long_after_stim_times));
        
        % startle response is defined as peak_med_vel - baseline_med_vel
        analysis_results(tube_num).(sequence).startle_resp = ...
            analysis_results(tube_num).(sequence).peak_med_vel ...
            - analysis_results(tube_num).(sequence).baseline_med_vel;
        
        % transfer median x velocity sequence %TODO: why are we doing this?
        analysis_results(tube_num).(sequence).med_vel_x = ...
            analysis_info_tube(tube_num).median_vel_x;
        
        % mean time series
        analysis_results(tube_num).(sequence).average_ts_med_vel = ...
            mean(analysis_info_tube(tube_num).median_vel(ts_average_times));
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).(sequence) = ...
            set_field_to_zero(analysis_results(tube_num).(sequence), ...
            {'peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', ...
            'baseline_mov_frac', 'baseline_med_vel', 'startle_resp', ...
            'med_vel_x', 'average_ts_med_vel'});
    end
end

%% Plotting parameters

y_lim_vel = 20;


%% Generate median velocity plots

figure(1)
set(1, 'Position', [150 125 450 600]);

num_trials = length(pulse_times);
t_tick = 0:trial_length/del_t:num_trials*trial_length/del_t;
n_t = max(cellfun(@length, {analysis_info_tube.median_vel})) ;
t = (1:n_t)*del_t ;
X_pulse_time_plot = [pulse_times; pulse_times]*del_t;

for tube_num = 1:6
    subplot(6, 1, tube_num)
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube
        % plot median velocity
        plot(t, ma(analysis_info_tube(tube_num).median_vel, 3), 'k')
        hold on  
        % plot markers for beginning and end of stimulus
        plot(X_pulse_time_plot, repmat([0 10], num_trials, 1)',  'r')
        plot(X_pulse_time_plot + 0.5, repmat([0 10], num_trials, 1)',  'r')
        % plot median velocity
        %plot(t, analysis_results(tube_num).(sequence).med_vel, 'g') % what's going on here?
    end
    axis([0 t(end) 0 y_lim_vel]);
    box off
    set(gca, 'Xtick', t_tick, 'Ytick', [0 y_lim_vel]);
    if tube_num == 1
        text(t(end)/2, 1.45*y_lim_vel, ...
             'median velocity, buzz stimulation', ...
             'HorizontalAlignment', 'center')
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
        text(t(end)/2, -0.8*y_lim_vel, ...
             ['DateTime: ' exp_detail.date_time], ...
             'HorizontalAlignment', 'center', ...
             'FontSize', 7) % annotate with date and time
    else
        set(gca, 'XTickLabel', []); 
    end   

    text(t(end), 1.15*y_lim_vel, ...
        [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
         'HorizontalAlignment', 'right', ...
         'FontSize', 7, ...
         'Interpreter','none')
end

% save figure 
if (save_plots)
    pdf_file_path = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_' sequence '_med_vel.pdf'] ;
    ensure_parent_folder_exists(pdf_file_path) ;
    save2pdf(pdf_file_path);
end

%% Generate average median velocity plot
figure(2)
set(2, 'Position', [650 125 325 600]);

t = (1:size(ts_average_times,2))*del_t;

for tube_num = 1:6
    subplot(6, 1, tube_num)
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube    
        average_ts_median_vel = ...
            analysis_results(tube_num).(sequence).average_ts_med_vel;
        
        % use less smoothing than lin mot plots
        plot(t, ma(average_ts_median_vel, ma_points), 'k')
        hold on
        
        %FIXME: parameterize the time series
        
        % plot marker for baseline med vel
        plot(5 + (-30:-5)*del_t, analysis_results(tube_num).(sequence).baseline_med_vel, 'g')
        % plot marker for peak med vel
        plot(5+(10:35)*del_t, analysis_results(tube_num).(sequence).peak_med_vel, 'g')
        % plot marker for 'long after' med vel
        plot((25:del_t:30), analysis_results(tube_num).(sequence).long_after_med_vel, 'g')
        
        % plot markers for the stimulus
        plot([5 5], [0 y_lim_vel], 'r')
        plot([5.5 5.5], [0 y_lim_vel], 'r')        
    end
        axis([0 t(end) 0 y_lim_vel]);
        box off
        set(gca, 'Xtick', [0 5 15 25 30], ... 
                 'XtickLabel', [-5 0 10 20 25], ...
                 'Ytick', [0 y_lim_vel]);
        
        if tube_num == 1
            text(t(end)/2, 1.45*y_lim_vel, ...
                 'median velocity, buzz stimulation', ...
                 'HorizontalAlignment', 'Center')
            ylabel('vel (mm/s)')
        end
        if tube_num == 6
            xlabel('time (s)')
        else
            set(gca, 'XTickLabel', []); 
        end

        text(t(end), 1.15*y_lim_vel, ...
             [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
              'FontSize', 7, ...
              'HorizontalAlignment', 'right', ...
              'Interpreter','none')
end
text(15, -0.8*y_lim_vel, ...
     ['DateTime: ' exp_detail.date_time], ...
      'FontSize', 7, ...
      'HorizontalAlignment', 'center')

% save figure 
if (save_plots)
    pdf_file_path = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_' sequence '_mean_med_vel.pdf'] ;
    ensure_parent_folder_exists(pdf_file_path) ;    
    save2pdf(pdf_file_path) ;
end

%% Clean up

% close all figures
close all

end

