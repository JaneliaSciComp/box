% Seq5_analysis.m

%%
% movie 5: seq5.avi goes from 875 s to 1006 s, times are from movie
% vidaction (81:107), UV-green preference assay 
% 15 second phototaxis towards competing lights.  Each light change accompanied by a intensity 100, 0.5 s vibration
% green is on at 255, UV is ramped from 2 to 10, then 15, 20, 25. MR and WK
% determined ramp. 
% LIGHT CHANGES
% [vidaction(83:4:105).time]:  [125 875 1625 2375 3125 3875 4625 5375] (command 1 0 255 6 0; 1 0 255 9 0; 1 0 255 12 0; 1 0 255 15 0; 1 0 255 18 0; 1 0 255 21 0)
% [vidaction(85:4:105).time]:  [500 1250 2000 2750 3500 4250 4950 4950] (command 1 6 0 0 255; 1 9 0 0 255; 1 12 0 0 255; 1 15 0 0 255; 1 18 0 0 255; 1 21 0 0 255)
% VIBRATION
% [vidaction(82:4:104).time]:  [125 875 1625 2375 3125 3875 4625 5375] (command 2 5 100 0 0)
% [vidaction(84:4:104).time]:  [500 1250 2000 2750 3500 4250 4950 5700] (command 2 5 100 0 0)


%% extract summarizing values to use for later analysis
for tube_num = 1:6
    analysis_results(tube_num).seq5 = Common_analysis(analysis_info_tube(tube_num));
    if length(analysis_info_tube(tube_num).median_vel) > 1 % that is, if there is data for this tube
        analysis_info_tube(tube_num).direction_index = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num;
    else % otherwise populate all fields with zero.
        analysis_info_tube(tube_num) = set_field_to_zero(analysis_info_tube(tube_num), ...
            {'direction_index'});
    end
        
end

%% make plots
dir1_starts = [125 875 1625 2375 3125 3875 4625 5375]; 
dir2_starts = [500 1250 2000 2750 3500 4250 5000 5750];

frames_per_trial = 375;
t_tick = 0:30:245;
y_lim_vel = y_lim_vel*(2/3);
y_lim_disp = y_lim_disp*(3/4);

% truncate this at one sample before end to avoid divide by zero problems
t = [1:(6126 - 1)]*del_t; % used to be as below, but crashes if tube 1 is empty...

X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

figure(6)
set(6, 'Position', [60 55 800 600]);

for tube_num = 1:6
    tfTubeHasValidData = ...
       (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...
        (length(analysis_info_tube(tube_num).median_vel) > 1);
    
    subplot(6,2,(tube_num-1)*2 + 1)
    if tfTubeHasValidData    
        med_x_vel = analysis_info_tube(tube_num).median_vel_x(1:end-1);
        plot(t, ma(med_x_vel, ma_points), 'k')
        hold on
        plot(X_dir1_time_plot, repmat([0 y_lim_vel], 8, 1)',  'r')
        plot(X_dir2_time_plot, repmat([0 -y_lim_vel], 8, 1)',  'r')
    end
    
    axis([0 t(end) -y_lim_vel y_lim_vel]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-y_lim_vel y_lim_vel]);
    if tube_num == 1
        text(185/2,y_lim_vel*1.8,'median X velocity, color pref (seq 5)',  'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    end   
    
    subplot(6,2,(tube_num)*2 )
    if tfTubeHasValidData    
        direction_index = analysis_info_tube(tube_num).direction_index(1:end-1);
        plot(t, ma(direction_index, ma_points), 'k')
        hold on

        plot(X_dir1_time_plot, repmat([0 -1], 8, 1)', 'r')
        plot(X_dir2_time_plot, repmat([0 1], 8, 1)', 'r')
    end
    
    axis([0 t(end) -1 1]); box off
    set(gca, 'Xtick', t_tick, 'Ytick', [-1 1]);
    if tube_num == 1
        text(185/2,1.65,'Direction Index (seq 5)',  'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end  
    
    text(195, 1.16, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none')
    text(100, -16.5, ['DateTime: ' exp_detail.date_time]) % annotate with date and time
end

if save_plots
    save2pdf([analysis_detail.exp_path filesep folder_path '_seq5_median_velocity_x&DI.pdf']);
end
%%
pos_vel_data = nan(6, 3000);
neg_vel_data = nan(6, 3000);
pos_disp_data = nan(6, 3000);
neg_disp_data = nan(6, 3000);
pos_dirpref_data = nan(6, 3000);
neg_dirpref_data = nan(6, 3000);
for tube_num = 1:6
    %have 6 experiments, each conducted once in each direction, avg. these
    % also compute median displacements as the median velocity times time
    % interval, then take a cumulative sum
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % that is, if there is data for this tube
        
        % calculate directional pref statistic        
        mov_n_lft = analysis_info_tube(tube_num).moving_num_left(1:end-1);
        mov_n_rgt = analysis_info_tube(tube_num).moving_num_right(1:end-1);
        num_flies = exp_detail.tube_info(tube_num).n;
        dir_pref = (mov_n_rgt - mov_n_lft)/num_flies;
        dir_pref = ma(dir_pref,6); % use moving av to smooth out sharp peaks; we will be looking at peak values
        
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+374);
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+374);
            dataIdx = 375*(k-1) + (1:375);
            
            pos_vel_data(tube_num, dataIdx) = analysis_info_tube(tube_num).median_vel_x(dir1Idxs)';
            neg_vel_data(tube_num, dataIdx) = analysis_info_tube(tube_num).median_vel_x(dir2Idxs)';

            pos_disp_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).median_vel_x(dir1Idxs)'*del_t);
            neg_disp_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).median_vel_x(dir2Idxs)'*del_t);
            
            pos_dirpref_data(tube_num, dataIdx) = dir_pref(dir1Idxs);
            neg_dirpref_data(tube_num, dataIdx) = dir_pref(dir2Idxs);        
        end
        analysis_results(tube_num).seq5.med_vel_x = (pos_vel_data(tube_num,:) - neg_vel_data(tube_num,:))/2;
        %analysis_results(tube_num).seq5.med_vel_x = [pos_vel_data(tube_num,:) neg_vel_data(tube_num,:)];
        analysis_results(tube_num).seq5.med_disp_x = (pos_disp_data(tube_num,:) - neg_disp_data(tube_num,:))/2;
        %analysis_results(tube_num).seq5.med_disp_x = mean([pos_disp_data(tube_num,:), neg_disp_data(tube_num,:)],1);  % AL: This appears to be a bug, based on later usage
        % analysis_results(tube_num).seq5.med_dirpref = [pos_dirpref_data(tube_num,:) neg_dirpref_data(tube_num,:)];        
        %analysis_results(tube_num).seq5.med_disp_X_SE
        
        assert(isequal(size(analysis_results(tube_num).seq5.med_disp_x),[1 3e3]));

        %rather than computing peaks, here just use the endpoint displacement after 15 seconds...
        for k = 1:length(dir1_starts)
            data_range = 375*(k-1) + (1:375);
            analysis_results(tube_num).seq5.disp_end(k) = analysis_results(tube_num).seq5.med_disp_x(data_range(end));
            pos_neg_disp_peaks = [largest_val(pos_disp_data(tube_num,data_range)) largest_val(-neg_disp_data(tube_num,data_range))];
            analysis_results(tube_num).seq5.disp_peak(k) = mean(pos_neg_disp_peaks);
            analysis_results(tube_num).seq5.disp_peak_SE(k) = std(pos_neg_disp_peaks)/sqrt(2);
            
            %analysis_results(tube_num).seq5.dirpref_end(k) = analysis_results(tube_num).seq5.med_dirpref(data_range(end));
            %pos_neg_dirpref_peaks = [largest_val(pos_dirpref_data(tube_num,data_range)) largest_val(-neg_dirpref_data(tube_num,data_range))];
            %analysis_results(tube_num).seq5.dirpref_peak(k) = mean(pos_neg_dirpref_peaks);
        end

         
         % calculate a simple UV-green 'modulation': the difference between
         % the mean of the first two and last two conditions
         analysis_results(tube_num).seq5.UVG_pref_diff = (mean(analysis_results(tube_num).seq5.disp_peak(1:2)) - ...
             mean(analysis_results(tube_num).seq5.disp_peak(7:8)) )/112.55; % normalized to tube length, in principle, storng response could be 2.0
         
         % make a simple 'matched filter' for the zero crossing. It is
         % possible for the peak to be position 2 or 7, but biased for those in the middle with 'support' of 5 points 
         % Choose UV value that gives the largest filter response
         Filt_template = [1 1 0 -1 -1 0 0 0];
         FilterMat = zeros(8);
         FilterMat(2,:) = [1 0 -1 -1 0 0 0 0]; 
         FilterMat(7,:) = [0 0 0 0 1 1 0 -1 ]; 
         for j = 3:6
            FilterMat(j,:) = circshift(Filt_template, [0 j-3]);
         end
         
         [amp analysis_results(tube_num).seq5.UVG_cross] = largest_val(FilterMat*analysis_results(tube_num).seq5.disp_peak');
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq5 = set_field_to_zero(analysis_results(tube_num).seq5, ...
        {'med_vel_x', 'med_disp_x', 'disp_end', 'disp_peak', 'disp_peak_SE', ...
         'UVG_pref_diff', 'UVG_cross'});
    end
end

%%
figure(7) 
set(7, 'Position', [30 55 1000 600]);
plot_gap = 40; time_gap = plot_gap*del_t;
if strcmp(protocol, '3.1') || strcmp(protocol, '4.1')
    X_label = [0 12 24 36 48 60 72 84];
else
    X_label = [2:2:10 15 20 25]; % {'UV = 2', 'UV = 4','UV = 6', 'UV = 8', 'UV = 10', 'UV = 15', 'UV = 20', 'UV = 25'}
end
X_label_short = X_label;

for tube_num = 1:6
    subplot(6,3,(tube_num-1)*3 + 1)
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) & ...% only generate a plot if flies are in the tube
        (length(analysis_info_tube(tube_num).median_vel) > 1)  % and if data exists
    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:8
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + [1:375])*del_t;
            plot(time_range, ma(analysis_results(tube_num).seq5.med_vel_x(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [-y_lim_vel y_lim_vel]',  'r')            
        end
    end

    axis([0 time_range(end) -y_lim_vel y_lim_vel]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3 60+time_gap*4 75+time_gap*5 90+time_gap*5 105+time_gap*5], 'Ytick', [-y_lim_vel 0 y_lim_vel], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2,y_lim_vel*1.6, 'med X velocity, Phototaxis (seq 5)',  'HorizontalAlignment', 'center')  
        ylabel('vel (mm/s)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    
    % now plot the displacement
    subplot(6,3,(tube_num-1)*3 + 2)
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) & ...% only generate a plot if flies are in the tube
        (length(analysis_info_tube(tube_num).median_vel) > 1)  % and if data exists
    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:8
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + [1:375])*del_t;
            plot(time_range, analysis_results(tube_num).seq5.med_disp_x(plot_range)', 'k')
            plot(time_range(1)*[1 1], [-y_lim_disp y_lim_disp]',  'r')            
        end
    end

    axis([0 time_range(end) -y_lim_disp y_lim_disp]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3 60+time_gap*4 75+time_gap*5 90+time_gap*5 105+time_gap*5], 'Ytick', [-y_lim_disp 0 y_lim_disp], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2,y_lim_disp*1.6,'median X displacement (in mm)',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak (or end point) values for the displacement
    subplot(6,3,(tube_num-1)*3 + 3)
    plot([0 9], [0 0], 'r') 
    hold on
           
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube
       errorbar(analysis_results(tube_num).seq5.disp_peak, analysis_results(tube_num).seq5.disp_peak_SE, 'k.-', 'MarkerSize', 14)
       %plot(analysis_results(tube_num).seq5.disp_peak, 'k.-', 'MarkerSize', 14)       
    end

    if tube_num == 1
        text(3.5,y_lim_disp*1.6,'end disp. (in mm)',  'HorizontalAlignment', 'center')  
    end

    axis([0.5 8.5 -y_lim_disp y_lim_disp]); box off
    
    set(gca, 'Xtick', [1:8], 'Ytick', [-y_lim_disp 0 y_lim_disp], 'Xticklabel', X_label_short);

    if tube_num == 6
        text(10, -y_lim_disp*2.5, ['DateTime: ' exp_detail.date_time], 'HorizontalAlignment', 'right') % annotate with date and time
        xlabel('UV intensity')
    else 
         set(gca, 'XTickLabel', []);              
    end

    text(10, y_lim_disp*1.2, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none', 'FontSize', 8)
end

if (save_plots)
        save2pdf([analysis_detail.exp_path filesep folder_path '_seq5_avg_vel_disp.pdf']);
end


%% make plots using direction_index
pos_dir_data = nan(6, 3000);
neg_dir_data = nan(6, 3000);
pos_cum_dir_data = nan(6, 3000);
neg_cum_dir_data = nan(6, 3000);

for tube_num = 1:6
    %have 6 experiments, each conducted once in each direction, avg. these
    % also compute median displacements as the median velocity times time
    % interval, then take a cumulative sum
    if (length(analysis_info_tube(tube_num).median_vel) > 1) % that is, if there is data for this tube
        
        % calculate directional pref statistic        
        for k = 1:length(dir1_starts)
            dir1Idxs = dir1_starts(k):(dir1_starts(k)+374);
            dir2Idxs = dir2_starts(k):(dir2_starts(k)+374);
            dataIdx = 375*(k-1) + (1:375);
            
            pos_dir_data(tube_num, dataIdx) = analysis_info_tube(tube_num).direction_index(dir1Idxs)';
            neg_dir_data(tube_num, dataIdx) = analysis_info_tube(tube_num).direction_index(dir2Idxs)';

            pos_cum_dir_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).direction_index(dir1Idxs)'*del_t);
            neg_cum_dir_data(tube_num, dataIdx) = cumsum(analysis_info_tube(tube_num).direction_index(dir2Idxs)'*del_t);       
        end
        analysis_results(tube_num).seq5.direction_index = (pos_dir_data(tube_num,:) - neg_dir_data(tube_num,:))/2;
        
        analysis_results(tube_num).seq5.mean_cum_dir_index = (pos_cum_dir_data(tube_num,:) - neg_cum_dir_data(tube_num,:))/2;
        
        assert(isequal(size(analysis_results(tube_num).seq5.med_disp_x),[1 3e3]));

        %rather than computing peaks, here just use the endpoint displacement after 15 seconds...
        for k = 1:length(dir1_starts)
            data_range = 375*(k-1) + (1:375);
            analysis_results(tube_num).seq5.cum_dir_index_end(k) = analysis_results(tube_num).seq5.mean_cum_dir_index(data_range(end));
            pos_neg_cum_dir_peaks = [largest_val(pos_cum_dir_data(tube_num,data_range)) largest_val(-neg_cum_dir_data(tube_num,data_range))];
            analysis_results(tube_num).seq5.cum_dir_index_peak(k) = mean(pos_neg_cum_dir_peaks);
            analysis_results(tube_num).seq5.cum_dir_index_peak_SE(k) = std(pos_neg_cum_dir_peaks)/sqrt(2);
        end

         
         % calculate a simple UV-green 'modulation': the difference between
         % the mean of the first two and last two conditions
         analysis_results(tube_num).seq5.UVG_pref_diff_dir_index = (mean(analysis_results(tube_num).seq5.cum_dir_index_peak(1:2)) - ...
             mean(analysis_results(tube_num).seq5.cum_dir_index_peak(7:8)) )/112.55; % normalized to tube length, in principle, storng response could be 2.0
         
         % make a simple 'matched filter' for the zero crossing. It is
         % possible for the peak to be position 2 or 7, but biased for those in the middle with 'support' of 5 points 
         % Choose UV value that gives the largest filter response
         Filt_template = [1 1 0 -1 -1 0 0 0];
         FilterMat = zeros(8);
         FilterMat(2,:) = [1 0 -1 -1 0 0 0 0]; 
         FilterMat(7,:) = [0 0 0 0 1 1 0 -1 ]; 
         for j = 3:6
            FilterMat(j,:) = circshift(Filt_template, [0 j-3]);
         end
         
         [amp analysis_results(tube_num).seq5.UVG_cross_dir_index] = largest_val(FilterMat*analysis_results(tube_num).seq5.cum_dir_index_peak');
    else % otherwise populate all fields with zero.
        analysis_results(tube_num).seq5 = set_field_to_zero(analysis_results(tube_num).seq5, ...
        {'direction_index', 'mean_cum_dir_index', 'cum_dir_index_end', 'cum_dir_index_peak', 'cum_dir_index_peak_SE', ...
         'UVG_pref_diff_dir_index', 'UVG_cross_dir_index'});
    end
end

%%
figure(71) 
set(71, 'Position', [30 55 1000 600]);
plot_gap = 40; time_gap = plot_gap*del_t;
if strcmp(protocol, '3.1') || strcmp(protocol, '4.1')
    X_label = [0 12 24 36 48 60 72 84];
else
    X_label = [2:2:10 15 20 25]; % {'UV = 2', 'UV = 4','UV = 6', 'UV = 8', 'UV = 10', 'UV = 15', 'UV = 20', 'UV = 25'}
end
X_label_short = X_label;

for tube_num = 1:6
    subplot(6,3,(tube_num-1)*3 + 1)
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) & ...% only generate a plot if flies are in the tube
        (length(analysis_info_tube(tube_num).median_vel) > 1)  % and if data exists
    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:8
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + [1:375])*del_t;
            plot(time_range, ma(analysis_results(tube_num).seq5.direction_index(plot_range), ma_points)', 'k')
            plot(time_range(1)*[1 1], [-1 1]',  'r')            
        end
    end

    axis([0 time_range(end) -1 1]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3 60+time_gap*4 75+time_gap*5 90+time_gap*5 105+time_gap*5], 'Ytick', [-y_lim_vel 0 y_lim_vel], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2,1.6, 'Direction Index, Phototaxis (seq 5)',  'HorizontalAlignment', 'center')  
        ylabel('DI')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    
    % now plot the displacement
    subplot(6,3,(tube_num-1)*3 + 2)
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) & ...% only generate a plot if flies are in the tube
        (length(analysis_info_tube(tube_num).median_vel) > 1)  % and if data exists
    
        plot([0 200], [0 0], 'r') % 200 just a large number
        hold on
        for k = 1:8
            plot_range = 375*(k-1) + [1:375];
            time_range = ((375 + plot_gap)*(k-1) + [1:375])*del_t;
            plot(time_range, analysis_results(tube_num).seq5.mean_cum_dir_index(plot_range)', 'k')
            plot(time_range(1)*[1 1], [-8 8]',  'r')            
        end
    end

    axis([0 time_range(end) -8 8]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3 60+time_gap*4 75+time_gap*5 90+time_gap*5 105+time_gap*5], 'Ytick', [-8 0 8], 'Xticklabel', X_label);
    if tube_num == 1
        text(time_range(end)/2,8*1.6,'cumulative Direction Index',  'HorizontalAlignment', 'center')  
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end

    % plot the peak (or end point) values for the displacement
    subplot(6,3,(tube_num-1)*3 + 3)
    plot([0 9], [0 0], 'r') 
    hold on
           
    if exp_detail.tube_info(tube_num).n >= min_num_flies % only generate a plot if flies are in the tube
       errorbar(analysis_results(tube_num).seq5.cum_dir_index_peak, analysis_results(tube_num).seq5.cum_dir_index_peak_SE, 'k.-', 'MarkerSize', 14)
    end

    if tube_num == 1
        text(3.5,8*1.6,'peak cum dir index',  'HorizontalAlignment', 'center')  
    end

    axis([0.5 8.5 -8 8]); box off
    
    set(gca, 'Xtick', [1:8], 'Ytick', [-8 0 8], 'Xticklabel', X_label_short);

    if tube_num == 6
        text(10, -8*2.5, ['DateTime: ' exp_detail.date_time], 'HorizontalAlignment', 'right') % annotate with date and time
        xlabel('UV intensity')
    else 
         set(gca, 'XTickLabel', []);              
    end

    text(10, 8*1.2, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender], ...
        'HorizontalAlignment', 'right', 'Interpreter','none', 'FontSize', 8)
end

if (save_plots)
        save2pdf([analysis_detail.exp_path filesep folder_path '_seq5_cum_dir_index.pdf']);
end