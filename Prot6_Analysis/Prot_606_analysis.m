% Prot606_analysis.m

%%



clear all
close all

exp_name = 'EXT_DL_shi_Apollo_20140331T160329';
datetime = exp_name(end-14:end);

exp_directory{1} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_06/%s/Output/01_6.06_34',exp_name);
exp_directory{2} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_06/%s/Output/02_6.06_34',exp_name);

out_dir = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_06/%s/Output/',exp_name);

tubes = 1:6;

del_t = 1/25;

%% make plots

dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625 8125 8625 9125 9625 10125 10625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875 8375 8875 9375 9875 10375 10875];

avg_interval = [0, 250];

t = (1:10125)*del_t;

X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

scatter_x = repmat([1,2,3,4,5,6,7,8,9,10,11],1,4);
numtubes = length(tubes);

condsGR = [0,5,10,15,20,30,40,50,75,100,200];
condsUV = [5,7,10,15,20,30,40,50,75,100,200];

x = 1:11;

fig_handle(1) = figure('name','All tubes','position',[0 0 2500 1500]); % init fig

for phase = 1:2,
    
    
    % seqs 1:4 for phase 1, seqs 5:8 for phase 2
   
    seqnum = phase;
        
    cd(exp_directory{phase})
    load([sprintf('%02d_6.06_seq%d_analysis_info.mat', phase, seqnum)]);
        
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
       
                
        
            
    
    
    conds2 = {'UV 10','Green 100'};
   
    if phase == 1,    
    
    subplot(2,length(tubes),tube_ind)
    scatter(scatter_x,f_w_stim(seqnum,tubes(tube_ind),:),'*k')
    hold on
    plot([0,11], ones(1,2)*0.5,'--r')
    hold on
    plot(x,mean_f_w_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 11])
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    set(gca,'XTick',x,'XTickLabel',condsGR)
    title(conds2{seqnum})
    hold on
    
    elseif phase == 2,
    
    subplot(2,length(tubes),length(tubes)+tube_ind)
    scatter(scatter_x,f_w_stim(seqnum,tubes(tube_ind),:),'*k')
    hold on
    plot([0,10], ones(1,2)*0.5,'--r')
    hold on
    plot(x,mean_f_w_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 10])
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',x,'XTickLabel',condsUV)
    title(conds2{seqnum})
    hold on
    end
    
    end 
        suptitle('Color preference at variable intensities of Green and UV')
        text(5.05, 2.5, 'Genotype: DL', 'clipping', 'off');
        save2pdf([out_dir 'alltubes.pdf'], fig_handle(1));
end

for phase = 1:2,
    
    seqnum = phase;
    
        for j = 1:(length(dir1_starts)/2)
            temp(1:4) = nanmean(f_w_stim(seqnum,:,j,1:4));
            all_tubes_mean(seqnum,j) = nanmean(temp(1:4));
            all_tubes_std(seqnum,j) = std(temp(1:4));
        end
    
end

fig_handle(2) = figure('name','Tube Summary','position',[0 0 1500 1500]);

for phase = 1:2,
    
    seqnum = phase;
        
    x = 1:11;
    
    subplot(1,2,seqnum)
    
    plot([0,11], ones(1,2)*0.5,'--r')
    hold on
    plot(x,all_tubes_mean(seqnum,:),'bs')
    hold on
    errorbar(all_tubes_mean(seqnum,:),all_tubes_std(seqnum,:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    
    if phase == 1,
        xlim([0 12])
    elseif phase == 2,
        xlim([0 12])
    end
    
    title(conds2{seqnum})
    hold on
    
    if phase == 1,
    
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    set(gca,'XTick',x,'XTickLabel',condsGR)
    else
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',x,'XTickLabel',condsUV)
    end
end

suptitle('Color preference at variable intensities of Green and UV - Mean for all tubes')
text(0.85,1.07, 'Genotype: DL', 'Units','normalized');
save2pdf([out_dir 'tubemeans.pdf'], fig_handle(2));