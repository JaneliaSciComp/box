% Seq2_analysis.m

% this script runs the analysis for sequence 2 and generates one figure

% movie 2: seq2.avi goes from 305 s to 490 s, times are from movie
% vidaction (4:9), Full intensity vibration every 30 seconds for 3
% minutes, takes place entirely in the dark
% VIBRATION
% [vidaction(4:9).time]:  [125 875 1625 2375 3125 3875] (command 2 5 255 0
% 0)


pulse_times = [125 875 1625 2375 3125 3875];

post_stim_times = []; pre_stim_times = [];  ts_average_times = [];  long_after_stim_times = [];
for j = 1:length(pulse_times)
    post_stim_times = [post_stim_times (pulse_times(j)+10):(pulse_times(j)+35)]; % one second just after pulse
    pre_stim_times = [pre_stim_times (pulse_times(j)-30):(pulse_times(j)-5)];    % one second just before pulse
    long_after_stim_times = [long_after_stim_times (pulse_times(j)+500):(pulse_times(j)+625)];    % 20 - 25 seconds after pulse
    ts_average_times = [ts_average_times; (pulse_times(j)-124):(pulse_times(j)+625)];    % 5 seconds before to 25 sec after
end

%% plot figure(1), median velocity
t_tick = [0 30 60 90 120 150];
t = [1:length(analysis_info_tube(1).median_vel)]*del_t;
X_pulse_time_plot = [pulse_times; pulse_times]*del_t;

figure(1)
set(1, 'Position', [150 125 450 600]);

for tube_num = 1:6
    subplot(6,1,tube_num)
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube    
        plot(X_pulse_time_plot, repmat([0 10], 6, 1)',  'r')
        hold on        
        plot(X_pulse_time_plot + 0.5, repmat([0 10], 6, 1)',  'r')
        plot(t, ma(analysis_info_tube(tube_num).median_vel, 3), 'k')
        plot(t, analysis_results(tube_num).seq1.med_vel, 'g') %FIXME
    end
    axis([0 t(end) 0 20]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [0 20]);
    if tube_num == 1
        text(100,29,'median velocity, buzz stimulation (seq 2)',  'HorizontalAlignment', 'center')
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
        text(100, -16.5, ['DateTime: ' exp_detail.date_time]) % annotate with date and time
    else
        set(gca, 'XTickLabel', []); 
    end   

    text(185, 23, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none')

    analysis_results(tube_num).seq2 = Common_analysis(analysis_info_tube(tube_num));
     
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % that is, if there is data for this tube
        analysis_results(tube_num).seq2.peak_mov_frac = mean(analysis_info_tube(tube_num).moving_fraction(post_stim_times));
        analysis_results(tube_num).seq2.peak_med_vel = mean(analysis_info_tube(tube_num).median_vel(post_stim_times));
        analysis_results(tube_num).seq2.long_after_med_vel = mean(analysis_info_tube(tube_num).median_vel(long_after_stim_times));

        analysis_results(tube_num).seq2.baseline_mov_frac = mean(analysis_info_tube(tube_num).moving_fraction(pre_stim_times));
        analysis_results(tube_num).seq2.baseline_med_vel = mean(analysis_info_tube(tube_num).median_vel(pre_stim_times));

        % startle response is defined as peak_med_vel - baseline_med_vel
        analysis_results(tube_num).seq2.startle_resp = analysis_results(tube_num).seq2.peak_med_vel ...
            - analysis_results(tube_num).seq2.baseline_med_vel;

        analysis_results(tube_num).seq2.med_vel_x = analysis_info_tube(tube_num).median_vel_x;
        analysis_results(tube_num).seq2.average_ts_med_vel =  mean(analysis_info_tube(tube_num).median_vel(ts_average_times));
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq2 = set_field_to_zero(analysis_results(tube_num).seq2, ...
        {'peak_mov_frac', 'peak_med_vel', 'long_after_med_vel', 'baseline_mov_frac', ...
        'baseline_med_vel', 'startle_resp', 'med_vel_x', 'average_ts_med_vel'});        
    end    
end

% now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq2_median_velocity.pdf']);
end

%%
figure(11)
set(11, 'Position', [650 125 325 600]);
t = [1:size(ts_average_times,2)]*del_t;
for tube_num = 1:6
    subplot(6,1,tube_num)
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube    
        average_ts_median_vel = analysis_results(tube_num).seq2.average_ts_med_vel;
        plot(t, ma(average_ts_median_vel, ma_points/2), 'k') % same smoothing as for lin motion looked way too sooth
                
        hold on
        plot(5 + [-30:-5]*del_t, analysis_results(tube_num).seq2.baseline_med_vel, 'g')
        plot(5+[10:35]*del_t, analysis_results(tube_num).seq2.peak_med_vel, 'g')
        plot([25:del_t:30], analysis_results(tube_num).seq2.long_after_med_vel, 'g')           
        plot([5 5], [0 25],  'r')
        plot([5.5 5.5], [0 25],  'r')        
    end
        axis([0 t(end) 0 20]); box off
        set(gca, 'Xtick', [0 5 15 25 30], 'XtickLabel', [-5 0 10 20 25], 'Ytick', [0 20]); 
        
        if tube_num == 1
            text(13.5, 29, 'median velocity, buzz stimulation (seq 2)', 'HorizontalAlignment', 'Center') % put the title higher
            %title('median velocity in each tube, seq 2')  
            ylabel('vel (mm/s)')
        end
        if tube_num == 6
            xlabel('time (s)')
        else
            set(gca, 'XTickLabel', []); 
        end   

        text(30, 23, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
            'HorizontalAlignment', 'right', 'Interpreter','none')
end

figure(11); text(19, -16, ['DateTime: ' exp_detail.date_time], 'HorizontalAlignment', 'center') % annotate with date and time
% now save figure 
if (save_plots)
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq2_median_velocity_averaged.pdf']);
end
