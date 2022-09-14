%% Seq4_analysis.m

% movie 4: seq4.avi goes from 745 s to 870 s, times are from movie
% vidaction (62:80), 15 second phototaxis.  Each light change accompanied by a full intensity 0.5 s vibration

% LIGHT CHANGES
% [vidaction(63:4:78).time]:  [125 875 1625 2375] (command 1 0 50 0 0; 1 0 255 0 0; 1 8 0 0 0; 1 20 0 0 0)
% [vidaction(65:4:78).time]:  [500 1250 2000 2750] (command 1 0 0 0 50; 1 0 0 0 255; 1 0 0 8 0; 1 0 0 20 0)
% VIBRATION
% [vidaction(64:4:78).time]:  [125 875 1625 2375] (command 2 5 255 0 0)
% [vidaction(66:4:78).time]:  [500 1250 2000 2750] (command 2 5 255 0 0)
% uv intensities are 6 (low) and 15 (high)

%% extract summarizing values to use for later analysis
for tube_num = 1:6
    analysis_results(tube_num).seq4 = Common_analysis(analysis_info_tube(tube_num)); 
    % note that med_vel used to be caluated here (and in Seq5) as not a mean value, but
    % now common_analysis puts a mean in. This is fine as we don't currently use this anyhow.
    
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % that is, if there is data for this tube
        analysis_info_tube(tube_num).direction_index = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num;
    else % otherwise populate all fields with zero.
        analysis_info_tube(tube_num) = set_field_to_zero(analysis_info_tube(tube_num), ...
            {'direction_index'});
     end
end

%% make plots using med_vel_x

dir1_starts = [125 875 1625 2375]; 
dir2_starts = [500 1250 2000 2750];
frames_per_trial = 375;
t_tick = 0:30:125;
y_lim = 1;

% truncate this at one sample before end to avoid divide by zero problems
t = (1:(3126 - 1))*del_t; % used to be as below, but crashes if tube 1 is empty...
%t = [1:(length(analysis_info_tube(1).median_vel) - 1)]*del_t;
X_dir2_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir1_time_plot = [dir2_starts; dir2_starts]*del_t;

figure(4) 
set(4, 'Position', [60 55 800 600]);

for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,2,(tube_num-1)*2 + 1)
    if tfTubeHasValidData    
        med_x_vel = analysis_info_tube(tube_num).median_vel_x(1:end-1);
        plot(t, ma(med_x_vel, ma_points), 'k')
        hold on
        plot(X_dir1_time_plot, repmat([0 -y_lim_vel], 4, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 y_lim_vel], 4, 1)',  'r')
    end
    
    axis([0 t(end) -y_lim_vel y_lim_vel]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-y_lim_vel y_lim_vel]);
    if tube_num == 1
        text(125/2,y_lim_vel*1.5,'median X velocity, Phototaxis (seq 4)',  'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end  

    subplot(6,2,(tube_num)*2 )
    if tfTubeHasValidData    
        direction_index = analysis_info_tube(tube_num).direction_index(1:end-1);
        plot(t, ma(direction_index, ma_points), 'k')
        hold on
        plot(X_dir1_time_plot, repmat([0 -1], 4, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 1], 4, 1)',  'r')
    end
    
    axis([0 t(end) -1 1]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-y_lim y_lim]);
    if tube_num == 1
        text(125/2,1.65,'Direction index, Phototaxis (seq 4)',  'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end  

     text(150, 1.16, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none')
end

if save_plots
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq4_median_velocity_x&DI.pdf']);
end

%%
pos_vel_data = nan(6, 1500);
neg_vel_data = nan(6, 1500);
pos_disp_data = nan(6, 1500);
neg_disp_data = nan(6, 1500);

for tube_num = 1:6
    % have 4 experiments, each conducted once in each direction, avg. these
    % also compute median displacements as the median velocity times time
    % interval, then take a cumulative sum
    if length(analysis_info_tube(tube_num).median_vel) > 1 % that is, if there is data for this tube
        
        % calculate directional pref statistic        
        mov_n_lft = analysis_info_tube(tube_num).moving_num_left(1:end-1);
        mov_n_rgt = analysis_info_tube(tube_num).moving_num_right(1:end-1);
        num_flies = exp_detail.tube_info(tube_num).n;
        dir_pref = (mov_n_rgt - mov_n_lft)/num_flies;
        dir_pref = ma(dir_pref,6); % use moving av to smooth out sharp peaks; we will be looking for a peak value
        
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+374);
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+374);
            dataIdx = 375*(k-1) + (1:375);
            
            pos_vel_data(tube_num, dataIdx) = analysis_info_tube(tube_num).median_vel_x(dir1Idxs)';
            neg_vel_data(tube_num, dataIdx) = analysis_info_tube(tube_num).median_vel_x(dir2Idxs)';
       
            pos_disp_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).median_vel_x(dir1Idxs)'*del_t);
            neg_disp_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).median_vel_x(dir2Idxs)'*del_t);

        end
        analysis_results(tube_num).seq4.med_vel_x = (pos_vel_data(tube_num,:) - neg_vel_data(tube_num,:))/2;
        analysis_results(tube_num).seq4.med_disp_x = (pos_disp_data(tube_num,:) - neg_disp_data(tube_num,:))/2;

        % AL: this "averaging" process for dirpref can be imperfect if the
        % pos/neg peaks do not "line up". 
        
        for k = 1:length(dir1_starts)
            dataIdx = 375*(k-1) + (1:375);
            [analysis_results(tube_num).seq4.disp_max(k), ...
             analysis_results(tube_num).seq4.disp_rise(k), dispmaxtime] = ... 
                step_rise_time((1:375)*del_t, analysis_results(tube_num).seq4.med_disp_x(dataIdx));
            analysis_results(tube_num).seq4.disp_max_time(k) = dispmaxtime*del_t;
            analysis_results(tube_num).seq4.disp_norm_max(k) = analysis_results(tube_num).seq4.disp_max(k)/112.55; % length of tube in mm
            analysis_results(tube_num).seq4.disp_end(k) = analysis_results(tube_num).seq4.med_disp_x(dataIdx(end));
        end
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq4 = set_field_to_zero(analysis_results(tube_num).seq4, ...
        {'med_vel_x', 'med_disp_x', 'disp_max', 'disp_rise', 'disp_max_time' 'disp_norm_max' 'disp_end'});
    end
end

%%
figure(5) 
set(5, 'Position', [30 55 1000 600]);
plot_gap = 40; time_gap = plot_gap*del_t;
if strcmp(protocol, '3.1') || strcmp(protocol, '4.1')
    X_label = {'G = 25', 'G = 120','UV = 36', 'UV = 200'};
else
    X_label = {'G = 50', 'G = 255','UV = 6', 'UV = 15'}; %mod from 2.8
end
X_label_short = {'GL', 'GH','UL', 'UH'};

time_range_end = ((375 + plot_gap)*(3) + 375)*del_t;
            
for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,6,(tube_num-1)*6 + (1:2))
    if tfTubeHasValidData    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:4
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + (1:375))*del_t;
            plot(time_range, ma(analysis_results(tube_num).seq4.med_vel_x(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_vel]', 'r')            
        end
    end

    axis([0 time_range_end -5 y_lim_vel]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3], 'Ytick', [0 y_lim_vel], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range_end/2,y_lim_vel*1.13,'med X velocity, Phototaxis (seq 4)',  'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    % now plot the displacement
    subplot(6,6,(tube_num-1)*6 + (3:4))
    if tfTubeHasValidData    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:4
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + (1:375))*del_t;
            plot(time_range, analysis_results(tube_num).seq4.med_disp_x(plot_range)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim_disp]',  'r')            
        end
    end

    axis([0 time_range_end -y_lim_disp/4 y_lim_disp]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3], 'Ytick', [0 y_lim_disp], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range_end/2,y_lim_disp*1.18,'median X displacement (in mm)',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak values for the displacement
    subplot(6,6,(tube_num-1)*6 + 5)
         
    if tfTubeHasValidData    
       plot([0 5], [0 0], 'r') % 200 just a large number
       hold on
       plot([1 2], analysis_results(tube_num).seq4.disp_max(1:2), 'g.-', 'MarkerSize', 14)       
       plot([3 4], analysis_results(tube_num).seq4.disp_max(3:4), 'm.-', 'MarkerSize', 14)       
    end

    if tube_num == 1
        text(2.5,y_lim_disp*1.4,'peak disp. (in mm)',  'HorizontalAlignment', 'center')  
    end

    axis([0.5 4.5 -y_lim_disp/4 y_lim_disp]); box off
    
    set(gca, 'Xtick', [1:4], 'Ytick', [0 y_lim_disp], 'Xticklabel', X_label_short);

    if tube_num ~= 6
         set(gca, 'XTickLabel', []); 
    end


    % plot the time to peak displacement
    subplot(6,6,(tube_num-1)*6 + 6)
          
    if tfTubeHasValidData
       plot([0 5], [0 0], 'r') % 200 just a large number
       hold on
       plot([1 2], analysis_results(tube_num).seq4.disp_rise(1:2), 'g.-', 'MarkerSize', 14)       
       plot([3 4], analysis_results(tube_num).seq4.disp_rise(3:4), 'm.-', 'MarkerSize', 14)       
    end

    axis([0.5 4.5 -1 15]); box off
    
    set(gca, 'Xtick', 1:4, 'Ytick', [0 15], 'Xticklabel', X_label_short);

    if tube_num == 1
        text(2.5,15*1.35,'time to peak (in s)',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        text(9, -10, ['DateTime: ' exp_detail.date_time], 'HorizontalAlignment', 'right') % annotate with date and time
    else 
         set(gca, 'XTickLabel', []);              
    end

    text(7.5, 17, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none', 'FontSize', 8)
end

% now save plots
if save_plots
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq4_avg_vel_disp.pdf']);
end


%% make plots using direction_index

pos_dir_data = nan(6, 1500);
neg_dir_data = nan(6, 1500);
pos_cum_dir_data = nan(6, 1500);
neg_cum_dir_data = nan(6, 1500);

for tube_num = 1:6
    % have 4 experiments, each conducted once in each direction, avg. these
    % also compute median displacements as the median velocity times time
    % interval, then take a cumulative sum
    if length(analysis_info_tube(tube_num).median_vel) > 1 % that is, if there is data for this tube
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+374);
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+374);
            dataIdx = 375*(k-1) + (1:375);
            
            pos_dir_data(tube_num, dataIdx) = analysis_info_tube(tube_num).direction_index(dir1Idxs)';
            neg_dir_data(tube_num, dataIdx) = analysis_info_tube(tube_num).direction_index(dir2Idxs)';
       
            pos_cum_dir_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).direction_index(dir1Idxs)'*del_t);
            neg_cum_dir_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).direction_index(dir2Idxs)'*del_t);
        end
        analysis_results(tube_num).seq4.direction_index = (pos_dir_data(tube_num,:) - neg_dir_data(tube_num,:))/2;
        analysis_results(tube_num).seq4.mean_cum_dir_index = (pos_cum_dir_data(tube_num,:) - neg_cum_dir_data(tube_num,:))/2;

        % AL: this "averaging" process for dirpref can be imperfect if the
        % pos/neg peaks do not "line up". 
        
        for k = 1:length(dir1_starts)
            dataIdx = 375*(k-1) + (1:375);
            [analysis_results(tube_num).seq4.cum_dir_index_max(k), ...
             analysis_results(tube_num).seq4.cum_dir_index_rise(k), dispmaxtime] = ... 
                step_rise_time((1:375)*del_t, analysis_results(tube_num).seq4.mean_cum_dir_index(dataIdx));
            analysis_results(tube_num).seq4.cum_dir_index_max_time(k) = dispmaxtime*del_t;
            %analysis_results(tube_num).seq4.disp_norm_max(k) = analysis_results(tube_num).seq4.disp_max(k)/112.55; % length of tube in mm
            analysis_results(tube_num).seq4.cum_dir_index_end(k) = analysis_results(tube_num).seq4.direction_index(dataIdx(end));
        end
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq4 = set_field_to_zero(analysis_results(tube_num).seq4, ...
        {'direction_index', 'mean_cum_dir_index', 'cum_dir_index_max', 'cum_dir_index_rise', 'cum_dir_index_max_time' 'cum_dir_index_end'});
    end
end

%%
figure(51) 
set(51, 'Position', [30 55 1000 600]);
plot_gap = 40; time_gap = plot_gap*del_t;
if strcmp(protocol, '3.1') || strcmp(protocol, '4.1')
    X_label = {'G = 25', 'G = 120','UV = 36', 'UV = 200'};
else
    X_label = {'G = 50', 'G = 255','UV = 6', 'UV = 15'}; %mod from 2.8
end
X_label_short = {'GL', 'GH','UL', 'UH'};

time_range_end = ((375 + plot_gap)*(3) + 375)*del_t;
            
for tube_num = 1:6
    tfTubeHasValidData = ...
        (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,6,(tube_num-1)*6 + (1:2))
    if tfTubeHasValidData    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:4
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + (1:375))*del_t;
            plot(time_range, ma(analysis_results(tube_num).seq4.direction_index(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [0 y_lim]', 'r')            
        end
    end

    axis([0 time_range_end -0.2 y_lim]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3], 'Ytick', [0 y_lim], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range_end/2,y_lim*1.13,'direction index, Phototaxis (seq 4)',  'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    % now plot the displacement
    subplot(6,6,(tube_num-1)*6 + (3:4))
    if tfTubeHasValidData    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:4
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + (1:375))*del_t;
            plot(time_range, analysis_results(tube_num).seq4.mean_cum_dir_index(plot_range)', 'k')
            plot(time_range(1)*[1 1], [0 8]',  'r')            
        end
    end

    axis([0 time_range_end -y_lim 8]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3], 'Ytick', [0 8], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range_end/2,8*1.18,'cumulative Direction Index',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak values for the displacement
    subplot(6,6,(tube_num-1)*6 + 5)
         
    if tfTubeHasValidData    
       plot([0 5], [0 0], 'r') % 200 just a large number
       hold on
       plot([1 2], analysis_results(tube_num).seq4.cum_dir_index_max(1:2), 'g.-', 'MarkerSize', 14)       
       plot([3 4], analysis_results(tube_num).seq4.cum_dir_index_max(3:4), 'm.-', 'MarkerSize', 14)       
    end

    if tube_num == 1
        text(2.5,8*y_lim*1.4,'peak CDI',  'HorizontalAlignment', 'center')  
    end

    axis([0.5 4.5 -y_lim 8*y_lim]); box off
    
    set(gca, 'Xtick', [1:4], 'Ytick', [0 8*y_lim], 'Xticklabel', X_label_short);

    if tube_num ~= 6
         set(gca, 'XTickLabel', []); 
    end


    % plot the time to peak displacement
    subplot(6,6,(tube_num-1)*6 + 6)
          
    if tfTubeHasValidData
       plot([0 5], [0 0], 'r') % 200 just a large number
       hold on
       plot([1 2], analysis_results(tube_num).seq4.cum_dir_index_rise(1:2), 'g.-', 'MarkerSize', 14)       
       plot([3 4], analysis_results(tube_num).seq4.cum_dir_index_rise(3:4), 'm.-', 'MarkerSize', 14)       
    end

    axis([0.5 4.5 -1 15]); box off
    
    set(gca, 'Xtick', 1:4, 'Ytick', [0 15], 'Xticklabel', X_label_short);

    if tube_num == 1
        text(2.5,15*1.35,'time to peak (in s)',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        text(1, -10, ['DateTime: ' exp_detail.date_time], 'HorizontalAlignment', 'right') % annotate with date and time
    else 
         set(gca, 'XTickLabel', []);              
    end

    text(7.5, 17, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none', 'FontSize', 8)
end

% now save plots
if save_plots
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq4_cum_direction_index.pdf']);
end
