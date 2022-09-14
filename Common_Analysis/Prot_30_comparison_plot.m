function Prot_30_comparison_plot(exp_directory, out_directory, save_plots, temp_folder, temp, exp_detail, protocol)

for k = 1:length(temp)
    try
        load([out_directory filesep temp_folder{k} '_analysis_results.mat'])
        An(k).res = analysis_results;     %#ok<AGROW>
    catch
        error(['The directory for the data path (' num2str(temp(k)) 'T) is incorrect, check filesystem'])
    end
end

try
    cd(fullfile(exp_directory, temp_folder{1}));
    cur_dir = dir('sequence_details*.m'); % grab local experiment file
    fid = fopen([cur_dir.name(1:end-2) '.m']);
    script = fread(fid, '*char')';
    fclose(fid);
    eval(script);
catch
    error('The experiment file for the sequence details file is incorrect, check filesystem')
end


%%
del_t = 1/25;
min_num_flies = 2; %10; change here for min number of flies
y_lim_vel = 30; % limit in mm/s on the y axes
y_lim_disp = 180; % length of displacement in mm
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
plot_speeds = [0 1 4 8 20 42 42 20 8 4 1 0];
plot_gap = 40; time_gap = plot_gap*del_t;
if strcmp(protocol, '3.1') || strcmp(protocol, '4.1')
    X_label = {'G = 25', 'G = 120','UV = 36', 'UV = 200'};
    seq4_X_label = {'GL', 'GH','UL', 'UH'};
    seq5_X_label = [0 12 24 36 48 60 72 84];
else
    X_label = {'G = 50', 'G = 255','UV = 6', 'UV = 15'};%mod from 2.8
    seq4_X_label = {'GL', 'GH','UL', 'UH'};
    seq5_X_label = [2:2:10 15 20 25];%mod from 2.8
end
thin_lw = 0.1; % linewidth for thin lines
thin_ls = 'k:';
data_lw = 1.3; % linewidth for data lines, thicker


figure(99)
set(99, 'Position', [100 100 1000 750]);
seq2_t = (1:750)*del_t; % used to read as below, but empty tube 1 will crash this...
%seq2_t = [1:length(An(1).res(1).seq2.average_ts_med_vel)]*del_t

for tube_num = 1:6
    % plot the seq 2 impulse response
    subplot(6,4,(tube_num-1)*4 + 1) 
    
   if (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...% only generate a plot if flies are in the tube
        (length(An(1).res(tube_num).seq2.average_ts_med_vel) > 1)  % and if data exists           
        plot([100; 100]*del_t, [0 25],  thin_ls, 'LineWidth', thin_lw)
        plot([100; 100]*del_t + 0.5, [0 25],  thin_ls, 'LineWidth', thin_lw)
        hold on
        for k = 1:length(temp)
            plot(seq2_t, ma(An(k).res(tube_num).seq2.average_ts_med_vel, ma_points/2), 'Color', temp_color(temp(k))) 
            text(7, 21 - (k-1)*2.6, [num2str(An(k).res(tube_num).seq2.long_after_med_vel, '%0.1f') ' mm/s; ' ...
                texlabel('Delta') num2str(An(k).res(tube_num).seq2.startle_resp, '%0.1f') ' mm/s; mvf: ' ...
                num2str(An(k).res(tube_num).seq2.baseline_mov_frac, '%0.2f') ...                
                ], 'HorizontalAlignment', 'Left', 'Color', temp_color(temp(k)), 'FontSize', 7) 
        end
    end
    axis([0 seq2_t(end) 0 20]); box off
    set(gca, 'Xtick', [0 4 14 24], 'XtickLabel', [-4 0 10 20], 'Ytick', [0 20]);    
    if tube_num == 1
        text(13.5, 26, 'med vel, mechanical startle', 'HorizontalAlignment', 'Center') % put the title higher
        ylabel('vel (mm/s)')

        % Add the temperature labels
        for k = 1:length(temp)
            text(-12, 33 - k * 5, ['T = ' num2str(temp(k))], 'HorizontalAlignment', 'Right', 'Color', temp_color(temp(k)), 'FontWeight', 'Bold', 'FontSize', 12 ) 
        end
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end   

    % plot the seq 3 motion tuning curve
    subplot(6,4,(tube_num-1)*4 + 2) 
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...% only generate a plot if flies are in the tube
        (length(An(1).res(tube_num).seq3.mean_motion_resp) > 1)  % and if data exists           
           
        for k = 1:length(temp)
            plot([0 10], [0 0], thin_ls, 'LineWidth', thin_lw) % 200 just a large number
            hold on
            errorbar(An(k).res(tube_num).seq3.mean_motion_resp, An(1).res(tube_num).seq3.std_motion_resp, 'k.-', 'MarkerSize', 14, 'Color', temp_color(temp(k)), 'LineWidth', 1)
            text(2, 21 - (k-1)*3.1, [texlabel('Delta') num2str(An(k).res(tube_num).seq3.motion_resp_diff, '%0.1f') ' mm/s; mvf:' ...
              num2str(An(k).res(tube_num).seq3.mov_frac, '%0.2f') ], ...
              'HorizontalAlignment', 'Left', 'Color', temp_color(temp(k)), 'FontSize', 7) 
        end
    end
    
   
    set(gca, 'Xtick', 1:6)
    axis([0.75 6.25 -5 y_lim_vel*2/3]); box off
     
    if tube_num == 1
        text(3.5, 26, 'med vel, visual motion', 'HorizontalAlignment', 'Center') % put the title higher
        ylabel('vel (mm/s)')
    end
    
    if tube_num == 6
        xlabel('Temporal Frequency') 
        set(gca, 'Xticklabel', plot_speeds(1:6))
    else
        set(gca, 'XTickLabel', []); 
    end  
    
    % plot the seq 4 displacement responses
    subplot(6,4,(tube_num-1)*4 + 3) 
    time_range_end = ((375 + plot_gap)*(3) + 375)*del_t;

    
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...% only generate a plot if flies are in the tube
        (length(An(1).res(tube_num).seq4.med_disp_x) > 1)  % and if data exists           
   
        plot([0 200], [0 0], thin_ls, 'LineWidth', thin_lw) % 200 just a large number
        hold on
        for k = 1:length(temp)
            for tr = 1:4
                plot_range = 375*(tr-1) + [1:375];
                time_range = ((375 + plot_gap)*(tr-1) + [1:375])*del_t;
                plot(time_range, An(k).res(tube_num).seq4.med_disp_x(plot_range)', 'Color', temp_color(temp(k)), 'LineWidth', data_lw)
                plot(time_range(1)*[1 1], [0 0.85*y_lim_disp]',  thin_ls, 'LineWidth', thin_lw)            
            end
            
            text(0.15*time_range_end, 1.06*y_lim_disp - (k-1)*26, ['PS: ' num2str(An(k).res(tube_num).seq4.disp_norm_max, '%-0.2f;') ...
                '  mvf:' num2str(An(k).res(tube_num).seq4.mov_frac, '%0.2f')], ...
              'HorizontalAlignment', 'Left', 'Color', temp_color(temp(k)), 'FontSize', 7)     
        end
        
        
    end
    
    axis([0 time_range_end -y_lim_disp/4 y_lim_disp]); box off
    
    set(gca, 'Xtick', 7.5+[0 15+time_gap 30+time_gap*2 45+time_gap*3], 'Ytick', [0 y_lim_disp], 'Xticklabel', seq4_X_label);
    if tube_num == 1
        text(time_range_end/2,y_lim_disp*1.35,'med disp, phototaxis',  'HorizontalAlignment', 'center') 
        ylabel('disp (mm)')
    end
    if tube_num == 6
        xlabel('time (s)')
    else
        set(gca, 'XTickLabel', []); 
    end
    
    % plot the seq 5 displacement responses
    subplot(6,4,(tube_num-1)*4 + 4) 
    
    if (exp_detail.tube_info(tube_num).n >= min_num_flies) && ...% only generate a plot if flies are in the tube
        (length(An(1).res(tube_num).seq5.disp_peak) > 1)  % and if data exists           
        
        plot([0 9], [0 0], thin_ls, 'LineWidth', thin_lw) 
        hold on
    
        for k = 1:length(temp)
            errorbar(An(k).res(tube_num).seq5.disp_peak, An(k).res(tube_num).seq5.disp_peak_SE,... 
            'k.-', 'MarkerSize', 14, 'Color', temp_color(temp(k)), 'LineWidth', 1) % seems silly to have 'k.-' but it helps!
         
            text(3.5, 1.0*y_lim_disp - (k-1)*40, ['ZC: ' num2str(seq5_X_label(An(k).res(tube_num).seq5.UVG_cross)) ...                
                texlabel('; Delta') 'Pref: ' num2str(An(k).res(tube_num).seq5.UVG_pref_diff, '%0.2f;') ...
                ' mvf: ' num2str(An(k).res(tube_num).seq5.mov_frac, '%0.2f') ], ...
                'HorizontalAlignment', 'Left', 'Color', temp_color(temp(k)), 'FontSize', 7)     
        end
    end

    axis([0.5 8.5 -y_lim_disp y_lim_disp]); box off
    set(gca, 'Xtick', [1:8], 'Ytick', [-y_lim_disp 0 y_lim_disp], 'Xticklabel', seq5_X_label);
    
    if tube_num == 1
        text(4.5,y_lim_disp*1.65,'med disp, color preference',  'HorizontalAlignment', 'center')  
        ylabel('disp (mm)')
    end

    if tube_num == 6
        xlabel('UV intensity');
        % annotate with Box name, topplate ID and date and time
        Ann_tag = ['BoxName: ' An(1).res(1).BoxName ';  TopPlateID: ' An(1).res(1).TopPlateID ';  DateTime: ' exp_detail.date_time];
        text(11.5, -y_lim_disp*2.5, Ann_tag, 'HorizontalAlignment', 'right')         
    else 
         set(gca, 'XTickLabel', []);              
    end

    text(12.5, y_lim_disp*1.28, [exp_detail.tube_info(tube_num).Genotype ' / ' exp_detail.tube_info(tube_num).Gender ' (n = ' num2str(exp_detail.tube_info(tube_num).n) ')'], ...
        'HorizontalAlignment', 'right', 'Interpreter','none', 'FontSize', 8)

 end


if (save_plots)
    save2pdf([out_directory filesep 'comparison_summary.pdf']);
%    close(99)
end



