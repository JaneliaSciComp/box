% Prot601_analysis.m

%%



clear all
close all

exp_name = 'EXT_DL_No_Effector_0_9999_Ares_20131121T100614';
datetime = exp_name(end-14:end);

exp_directory{1} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_02/%s/Output/01_6.02_34',exp_name);
exp_directory{2} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_02/%s/Output/02_6.02_34',exp_name);

out_dir = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_02/%s/Output/',exp_name);

tubes = 1:6;
numtubes = numel(tubes);

del_t = 1/25;

%% make plots

dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875];

avg_interval = [0, 250];

t = (1:5125)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

scatter_x = repmat([1,2,3,4,5,6,7,8,9,10],1,2);
numtubes = length(tubes);

condsGR = [0,2,5,8,12,16,20,30,40,50,60];

for phase = 1,
    
    fig_handle(phase) = figure('name',strcat('Phase ',num2str(phase)),'position',[0 0 1500 1500]); % init fig
    
    % seqs 1:4 for phase 1, seqs 5:8 for phase 2
    
    
    for seqnum = 1:3
        
        cd(exp_directory{phase})
        load([sprintf('%02d_6.02_seq%d_analysis_info.mat', phase, seqnum)]);
        
        
        
        for tube_ind = 1:numtubes
            select_moving_num_left(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_left(1:end-1)];
            select_moving_num_right(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_right(1:end-1)];
            select_moving_num(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num(1:end-1)];
            med_x_vel(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).median_vel_x(1:end-1)];
        
            for i = 1:length(select_moving_num_left(tubes(tube_ind),:)),
            
                f_left(tubes(tube_ind),i) = select_moving_num_left(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
                f_right(tubes(tube_ind),i) = select_moving_num_right(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
        
            end
        
            
            for j = 1:(length(dir1_starts)),
                
                f_w_stim(seqnum,tubes(tube_ind),j,1:2) = [median(f_right(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_left(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2))))];  
                                   
                
                f_against_stim(seqnum,tubes(tube_ind),j,1:2) = [median(f_left(tubes(tube_ind), (dir1_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir1_starts(length(dir1_starts)-j+1)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(length(dir1_starts)-j+1)+avg_interval(1)):(dir2_starts(length(dir1_starts)-j+1)+avg_interval(2)) ))];
                 
                
                mean_f_w_stim(tubes(tube_ind),j) = nanmean(f_w_stim(seqnum,tubes(tube_ind),j,1:2));
            end    
                
            
            
                
                
        
            
    x = 1:10;
    conds2 = {'UV 0','UV 0','UV 0','UV 0','UV 0','UV 0','UV 0','UV 0','UV 0','UV 0'};
   
        
    
    subplot(length(tubes),3,3*tube_ind-(3-seqnum))
    scatter(scatter_x,f_w_stim(seqnum,tubes(tube_ind),:),'*k')
    hold on
    plot([0,10], ones(1,2)*0.5,'--r')
    hold on
    plot(x,mean_f_w_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 11])
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    set(gca,'XTick',x,'XTickLabel',condsGR)
    title(conds2{seqnum})
    hold on
   
    
        
    end
    
    
        suptitle(strcat('Green Variable',' , ',datetime))
        save2pdf([out_dir 'Green_variable.pdf'], fig_handle(1));
        
  
    
end
end 
for phase = 1,
    
    for seqnum = 1:3
        for j = 1:(length(dir1_starts))
            temp(1:2) = nanmean(f_w_stim(seqnum,:,j,1:2));
            all_tubes_mean(seqnum,j) = nanmean(temp(1:2));
            all_tubes_std(seqnum,j) = std(temp(1:2));
            
            if phase == 1,
                temp(1:2) = nanmean(f_against_stim(seqnum,:,j,1:2));
                all_tubes_mean_against(seqnum,j) = nanmean(temp(1:2));
                all_tubes_std_against(seqnum,j) = std(temp(1:2));
            end
        end
    end
end

fig_handle(3) = figure('name','Tube Summary','position',[0 0 1500 1500]);

for phase = 1,
    
    for seqnum = 1:3
        
    x = 1:10;
    
    subplot(1,3,seqnum)
    
    plot([0,11], ones(1,2)*0.5,'--r')
    hold on
    plot(x,all_tubes_mean(seqnum,:),'bs')
    hold on
    errorbar(all_tubes_mean(seqnum,:),all_tubes_std(seqnum,:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 11])
    
    
    title(conds2{seqnum})
    hold on
    
    
    
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    set(gca,'XTick',x,'XTickLabel',condsGR)
    
    end
end


suptitle(strcat('Summary for All Tubes',' , ',datetime))
save2pdf([out_dir 'all_tubes.pdf'], fig_handle(3));

%}