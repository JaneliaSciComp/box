% Prot60_analysis.m

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


clear all
close all

exp_name = 'Test_UAS_DL_Shi_ts1_3_0033_Apollo_20131028T155302';
%exp_name = 'Test_shi_Apollo_20131105T101856';
datetime = exp_name(end-14:end);

exp_directory{1} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_0/%s/Output/01_6.0_34',exp_name);
exp_directory{2} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_0/%s/Output/02_6.0_34',exp_name);

out_dir = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_0/%s/Output/',exp_name);

tubes = 1:6;
numtubes = numel(tubes);

del_t = 1/25;

%% make plots

dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875];

avg_interval = [0, 250];

t = (1:5125)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

scatter_x = repmat([1,2,3,4,5,6],1,4);
numtubes = length(tubes);

conds = [0,50,100,150,200,250];


for phase = 1:2,
    
    fig_handle(phase) = figure('name',strcat('Phase ',num2str(phase)),'position',[0 0 1500 1500]); % init fig
    
    % seqs 1:4 for phase 1, seqs 5:8 for phase 2
    if phase == 1,
        seqs = 1:5;
    else
        seqs = 6:10;
    end
    
    for seqnum = seqs
        
        cd(exp_directory{phase})
        load([sprintf('%02d_6.0_seq%d_analysis_info.mat', phase, seqnum)]);
        
        for tube_ind = 1:numtubes
            select_moving_num_left(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_left(1:end-1)];
            select_moving_num_right(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_right(1:end-1)];
            select_moving_num(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num(1:end-1)];
            med_x_vel(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).median_vel_x(1:end-1)];
        
            for i = 1:length(select_moving_num_left(tubes(tube_ind),:)),
            
                f_left(tubes(tube_ind),i) = select_moving_num_left(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
                f_right(tubes(tube_ind),i) = select_moving_num_right(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
        
            end
        
            if phase == 1
            for j = 1:(length(dir1_starts)/2),
                
                f_w_stim(seqnum,tubes(tube_ind),j,1:4) = [median(f_right(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_left(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2)))), ...
                     median(f_right(tubes(tube_ind), (dir1_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir1_starts(length(dir1_starts)-j+1)+avg_interval(2)) )), ...
                     median(f_left(tubes(tube_ind), (dir2_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir2_starts(length(dir1_starts)-j+1)+avg_interval(2)) ))];                
                
                f_against_stim(seqnum,tubes(tube_ind),j,1:4) = [median(f_left(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2)))), ...
                     median(f_left(tubes(tube_ind), (dir1_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir1_starts(length(dir1_starts)-j+1)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir2_starts(length(dir1_starts)-j+1)+avg_interval(2)) ))];
                 
                mean_f_w_stim(tubes(tube_ind),j) = nanmean(f_w_stim(seqnum,tubes(tube_ind),j,1:4));
                
            end    
                
            elseif phase == 2
            for j = 1:(length(dir1_starts)/2),
                
                f_w_stim(seqnum,tubes(tube_ind),j,1:4) = [median(f_left(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2)))), ...
                     median(f_left(tubes(tube_ind), (dir1_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir1_starts(length(dir1_starts)-j+1)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir2_starts(length(dir1_starts)-j+1)+avg_interval(2)) ))];                
                
                mean_f_w_stim(tubes(tube_ind),j) = nanmean(f_w_stim(seqnum,tubes(tube_ind),j,1:4));
                
            end
            end 
                
                
        
            
    x = 1:6;
    conds2 = {'UV 0','UV 50','UV 100','UV 150','UV 200',...
        'Green 0','Green 50','Green 100','Green 150','Green 200'};
   
    if phase == 1,    
    
    subplot(length(tubes),5,5*tube_ind-(5-seqnum))
    scatter(scatter_x,f_w_stim(seqnum,tubes(tube_ind),:),'*k')
    hold on
    plot([0,6], ones(1,2)*0.5,'--r')
    hold on
    plot(x,mean_f_w_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 6])
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum})
    hold on
    elseif phase == 2,
    
    subplot(length(tubes),5,5*tube_ind-(10-seqnum))
    scatter(scatter_x,f_w_stim(seqnum,tubes(tube_ind),:),'*k')
    hold on
    plot([0,6], ones(1,2)*0.5,'--r')
    hold on
    plot(x,mean_f_w_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 6])
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum})
    hold on
    end
    
        end
    end
    
    if phase == 1,
        suptitle(strcat('Green Variable',' , ',datetime))
        save2pdf([out_dir 'Green_variable.pdf'], fig_handle(1));
        
    elseif phase == 2,
        suptitle(strcat('UV Variable',' , ',datetime))
        save2pdf([out_dir 'UV_variable.pdf'], fig_handle(2));
        
    end
    
end

for phase = 1:2,
    if phase == 1,
        seqs = 1:5;
    else
        seqs = 6:10;
    end
    
    for seqnum = seqs
        for j = 1:(length(dir1_starts)/2)
            temp(1:4) = nanmean(f_w_stim(seqnum,:,j,1:4));
            all_tubes_mean(seqnum,j) = nanmean(temp(1:4));
            all_tubes_std(seqnum,j) = std(temp(1:4));
            
            if phase == 1,
                temp(1:4) = nanmean(f_against_stim(seqnum,:,j,1:4));
                all_tubes_mean_against(seqnum,j) = nanmean(temp(1:4));
                all_tubes_std_against(seqnum,j) = std(temp(1:4));
            end
        end
    end
end

fig_handle(3) = figure('name','Tube Summary','position',[0 0 1500 1500]);

for phase = 1:2,
    if phase == 1,
        seqs = 1:5;
    else
        seqs = 6:10;
    end
    
    for seqnum = seqs
        
    x = 1:6;
    
    subplot(2,5,seqnum)
    
    plot([0,7], ones(1,2)*0.5,'--r')
    hold on
    plot(x,all_tubes_mean(seqnum,:),'bs')
    hold on
    errorbar(all_tubes_mean(seqnum,:),all_tubes_std(seqnum,:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 7])
    
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum})
    hold on
    
    if phase == 1,
    
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    
    else
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    
    end
    end
end


suptitle(strcat('Summary for All Tubes',' , ',datetime))
save2pdf([out_dir 'all_tubes.pdf'], fig_handle(3));

fig_handle(4) = figure('name','Tube Summary','position',[0 0 2000 1500]);

phase = 2;
seqs = 6:10;

for seqnum = seqs,
    
    x = 1:6;
    
    subplot(2,5,seqnum-5)
    
    plot([0,7], ones(1,2)*0.5,'--r')
    hold on
    plot(x,all_tubes_mean(seqnum,:),'ms')
    hold on 
    errorbar(all_tubes_mean(seqnum,:),all_tubes_std(seqnum,:),'ms','MarkerSize',8,'LineWidth',1.25)
    hold on
    
    for x2 = 1:5,
        plot(x2,all_tubes_mean_against(x2,seqnum-5),'Color',[0 .5 0],'Marker','x','MarkerSize',8,'LineWidth',1.25)
        errorbar(x2,all_tubes_mean_against(x2,seqnum-5),all_tubes_std_against(x2,seqnum-5),'Color',[0 0.5 0], 'Marker','x','MarkerSize',8,'LineWidth',1.25)
        hold on
    end
    
    ylim([0 1]);
    xlim([0 7])
    
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum})
    hold on
    
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    
end
    

suptitle(strcat('Summary Plot - all tubes - both phases',' , ',datetime))
save2pdf([out_dir 'summary.pdf'], fig_handle(4));
