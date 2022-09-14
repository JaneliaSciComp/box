% Prot604_analysis.m

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

exp_name = 'EXT_DL_shi_Apollo_20131212T095532';
%exp_name = 'Test_shi_Apollo_20131105T101856';
datetime = exp_name(end-14:end);

exp_directory{1} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_04/%s/Output/01_6.04_34',exp_name);
exp_directory{2} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_04/%s/Output/02_6.04_34',exp_name);
exp_directory{3} = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_04/%s/Output/03_6.04_34',exp_name);


out_dir = sprintf('/Volumes/flyolympiad/Olympiad_Screen/box/reiser_protocol_test_2013/ColorPreference/6_04/%s/Output/',exp_name);

tubes = 1:6;
numtubes = numel(tubes);

del_t = 1/25;

%% make plots

dir1_starts = [375 1375 2375 3375]; 
dir2_starts = [875 1875 2875 3875];

ntrials = length(dir1_starts);

avg_interval = [0, 250];

t = (1:6325)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

scatter_x = repmat([1,2,3,4],1,2);
numtubes = length(tubes);

conds = [50,100,150,200];


for phase = 1:3,
    
    fig_handle(phase) = figure('name',strcat('Phase ',num2str(phase)),'position',[0 0 1500 1500]); % init fig
    
    % seqs 1:4 for phase 1, seqs 5:8 for phase 2
    if phase == 1,
        seqs = 1:5;
    elseif phase == 2,
        seqs = 6:10;
    else
        seqs = 11:15;
    end
    
    for seqnum = seqs
        
        cd(exp_directory{phase})
        load([sprintf('%02d_6.04_seq%d_analysis_info.mat', phase, seqnum)]);
        clear select_moving_num_left
        clear select_moving_num_right
        clear select_moving_num
        clear med_x_vel
        
        
        for tube_ind = 1:numtubes
            select_moving_num_left(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_left(1:end-1)];
            select_moving_num_right(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num_right(1:end-1)];
            select_moving_num(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).moving_num(1:end-1)];
            med_x_vel(tubes(tube_ind),:) = [analysis_info_tube(tubes(tube_ind)).median_vel_x(1:end-1)];
        
            for i = 1:length(select_moving_num_left(tubes(tube_ind),:)),
            
                f_left(tubes(tube_ind),i) = select_moving_num_left(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
                f_right(tubes(tube_ind),i) = select_moving_num_right(tubes(tube_ind),i)/select_moving_num(tubes(tube_ind),i);
                
            end
            
            if phase == 1,
                dir1_starts = [375 1375 2375 3375 4375];
                dir2_starts = [875 1875 2875 3875 4875];
                ntrials = length(dir1_starts);
            else
                dir1_starts = [375 1375 2375 3375]; 
                dir2_starts = [875 1875 2875 3875];

                ntrials = length(dir1_starts);
            end    

            
            for j = 1:ntrials,
                
                data(seqnum).f_w_stim(tubes(tube_ind),j,1:2) = [median(f_right(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_left(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2))))];                
                
                data(seqnum).f_against_stim(tubes(tube_ind),j,1:2) = [median(f_left(tubes(tube_ind), (dir1_starts(j)+avg_interval(1)):(dir1_starts(j)+avg_interval(2)) )), ...
                     median(f_right(tubes(tube_ind), (dir2_starts(j)+avg_interval(1)):(dir2_starts(j)+avg_interval(2))))];
                 
                data(seqnum).mean_f_w_stim(tubes(tube_ind),j) = nanmean(data(seqnum).f_w_stim(tubes(tube_ind),j,1:2));
                data(seqnum).mean_f_a_stim(tubes(tube_ind),j) = nanmean(data(seqnum).f_against_stim(tubes(tube_ind),j,1:2));
            end
            
    x = 1:4;
    conds2 = {'UV 5','UV 10','UV 20','UV 30','UV 40'};
   
    if phase == 1,
    
    subplot(length(tubes),5,5*tube_ind-(5-seqnum))
    scatter(repmat([1,2,3,4,5],1,2),data(seqnum).f_against_stim(tubes(tube_ind),:),'*k')
    hold on
    plot([0,5], ones(1,2)*0.5,'--r')
    hold on
    plot(1:5,data(seqnum).mean_f_a_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 6])
    xlabel('Green Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',1:5,'XTickLabel',[0,50,100,150,200])
    title(conds2{seqnum})
    hold on
    elseif phase == 2,
    
    subplot(length(tubes),5,5*tube_ind-(10-seqnum))
    scatter(scatter_x,data(seqnum).f_against_stim(tubes(tube_ind),:),'*k')
    hold on
    plot([0,6], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).mean_f_a_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 6])
    xlabel('Green Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum-5})
    hold on
    
    
    elseif phase == 3,
    
    subplot(length(tubes),5,5*tube_ind-(15-seqnum))
    scatter(scatter_x,data(seqnum).f_against_stim(tubes(tube_ind),:),'*k')
    hold on
    plot([0,6], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).mean_f_a_stim(tubes(tube_ind),:))
    ylim([0 1]);
    xlim([0 6])
    xlabel('Green Intensity')
    ylabel('frac moving to UV')
    set(gca,'XTick',x,'XTickLabel',conds)
    title(conds2{seqnum-10})
    hold on
    end
    
        end
    end
    
    if phase == 1,
        suptitle(strcat('lights all off',' , ',datetime))
        save2pdf([out_dir 'phase1.pdf'], fig_handle(1));
        
    elseif phase == 2,
        suptitle(strcat('Green on',' , ',datetime))
        save2pdf([out_dir 'phase2.pdf'], fig_handle(2));
    else
        suptitle(strcat('UV on',' , ',datetime))
        save2pdf([out_dir 'phase3.pdf'], fig_handle(3));
    end
    
end

for phase = 1:3,
    if phase == 1,
        seqs = 1:5;
        ntrials = 5;
    elseif phase==2,
        seqs = 6:10;
        ntrials = 4;
    else
        seqs = 11:15;
        ntrials = 4;
    end
    
    for seqnum = seqs
        for j = 1:ntrials
            temp(1:2) = nanmean(data(seqnum).f_against_stim(tubes,j,1:2));
            data(seqnum).all_tubes_a_mean(j) = nanmean(temp(1:2));
            data(seqnum).all_tubes_a_std(j) = std(temp(1:2));
        end
    end
end

fig_handle(4) = figure('name','Tube Summary','position',[0 0 1500 1500]);

for phase = 1:3,
    if phase == 1,
        seqs = 1:5;
    elseif phase == 2,
        seqs = 6:10;
    else
        seqs = 11:15;
    end
    
    for seqnum = seqs
        
    
    subplot(3,5,seqnum)
    
    if phase == 1,
        x = 1:5;
    
    plot([0,7], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).all_tubes_a_mean(:),'bs')
    hold on
    errorbar(data(seqnum).all_tubes_a_mean(:),data(seqnum).all_tubes_a_std(:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 6])
    
    set(gca,'XTick',x,'XTickLabel',[0,50,100,150,200])
    
    else
        x = 1:4;
    plot([0,7], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).all_tubes_a_mean(:),'bs')
    hold on
    errorbar(data(seqnum).all_tubes_a_mean(:),data(seqnum).all_tubes_a_std(:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 5])
    
    set(gca,'XTick',x,'XTickLabel',conds)
    end
    
    if phase == 1,
    title(strcat('all off, ',conds2{seqnum}))
    elseif phase ==2,
    title(strcat('green on, ',conds2{seqnum-5}))
    else
    title(strcat('UV on, ',conds2{seqnum-10}))
    end
    hold on
    
    
    xlabel('Green Intensity')
    ylabel('frac moving to UV')
    
    
    end
end


suptitle(strcat('Summary for All Tubes, moving to UV',' , ',datetime))
save2pdf([out_dir 'all_tubes_to_UV.pdf'], fig_handle(4));



fig_handle(5) = figure('name','Tube Summary','position',[0 0 2000 1500]);

for phase = 1:3,
    if phase == 1,
        seqs = 1:5;
        ntrials = 5;
    elseif phase==2,
        seqs = 6:10;
        ntrials = 4;
    else
        seqs = 11:15;
        ntrials = 4;
    end
    
    for seqnum = seqs
        for j = 1:ntrials
            temp(1:2) = nanmean(data(seqnum).f_w_stim(tubes,j,1:2));
            data(seqnum).all_tubes_w_mean(j) = nanmean(temp(1:2));
            data(seqnum).all_tubes_w_std(j) = std(temp(1:2));
        end
    end
    
    
end

for phase = 1:3,
    if phase == 1,
        seqs = 1:5;
    elseif phase == 2,
        seqs = 6:10;
    else
        seqs = 11:15;
    end
    
    for seqnum = seqs,
        subplot(3,5,seqnum)
    
    if phase == 1,
    x = 1:5;    
  
    
    plot([0,6], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).all_tubes_w_mean(:),'bs')
    hold on
    errorbar(data(seqnum).all_tubes_w_mean(:),data(seqnum).all_tubes_w_std(:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 6])
    
    set(gca,'XTick',x,'XTickLabel',[0,50,100,150,200])
    
     else
          x = 1:4;    
  
    
    plot([0,5], ones(1,2)*0.5,'--r')
    hold on
    plot(x,data(seqnum).all_tubes_w_mean(:),'bs')
    hold on
    errorbar(data(seqnum).all_tubes_w_mean(:),data(seqnum).all_tubes_w_std(:),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([0 1]);
    xlim([0 5])
    
    set(gca,'XTick',x,'XTickLabel',conds)
         
    end
    if phase == 1,
    title(strcat('all off, ',conds2{seqnum}))
    elseif phase ==2,
    title(strcat('green on, ',conds2{seqnum-5}))
    else
    title(strcat('UV on, ',conds2{seqnum-10}))
    end
    hold on
    
    
    xlabel('Green Intensity')
    ylabel('frac moving to Green')
    
    
    end
end

suptitle(strcat('Summary for All Tubes, moving to Green',' , ',datetime))
save2pdf([out_dir 'all_tubes_to_Green.pdf'], fig_handle(5));
%}