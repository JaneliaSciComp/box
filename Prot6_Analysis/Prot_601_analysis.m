% Prot601_analysis.m

%%



clear all
close all

exp_name = 'GMR_SS00205_trp_Athena_20141015T140523';
genotype = exp_name(1:11);
datetime = exp_name(end-14:end);

exp_directory{1} = sprintf('/Volumes/flyolympiad/Austin/Reiser_Lab/data/5_13/5_13_followedby_6_01/%s/Output_1.1_1.7/01_6.01_34',exp_name);
exp_directory{2} = sprintf('/Volumes/flyolympiad/Austin/Reiser_Lab/data/5_13/5_13_followedby_6_01/%s/Output_1.1_1.7/02_6.01_34',exp_name);

out_dir = sprintf('/Volumes/flyolympiad/Austin/Reiser_Lab/data/5_13/5_13_followedby_6_01/%s/Output_1.1_1.7/',exp_name);

tubes = 1:6;
numtubes = numel(tubes);

del_t = 1/25;

%% make plots

dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875];
trial_length = dir2_starts(1) - dir1_starts(1);
avg_interval = [0, 250];

t = (1:5125)*del_t;
X_dir1_time_plot = [dir1_starts; dir1_starts]*del_t;
X_dir2_time_plot = [dir2_starts; dir2_starts]*del_t;

scatter_x = repmat([1,2,3,4,5,6],1,4);
numtubes = length(tubes);

condsUV = [5,10,20,30,40,50];
condsGR = [0,50,100,150,200,250];
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;
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
        load([sprintf('%02d_6.01_seq%d_analysis_info.mat', phase, seqnum)]);
        
        
        for tube_num = 1:numtubes
            select_moving_num_left(tubes(tube_num),:) = [analysis_info_tube(tubes(tube_num)).moving_num_left(1:end-1)];
            select_moving_num_right(tubes(tube_num),:) = [analysis_info_tube(tubes(tube_num)).moving_num_right(1:end-1)];
            select_moving_num(tubes(tube_num),:) = [analysis_info_tube(tubes(tube_num)).moving_num(1:end-1)];
            med_x_vel(tubes(tube_num),:) = [analysis_info_tube(tubes(tube_num)).median_vel_x(1:end-1)];

            directionindex(tubes(tube_num),:) = ...
            (analysis_info_tube(tube_num).moving_num_right - ...
             analysis_info_tube(tube_num).moving_num_left) ./ ...
             analysis_info_tube(tube_num).tracked_num;
         
                for k = 1:length(dir1_starts)
                    dir1Idxs = dir1_starts(k):(dir1_starts(k)+trial_length-1);
                    dir2Idxs = dir2_starts(k):(dir2_starts(k)+trial_length-1);
                    dataIdx = trial_length*(k-1) + (1:trial_length);

                    pos_dir_data(tube_num,k) = ...
                        mean(directionindex(tube_num, dir2Idxs));
                    neg_dir_data(tube_num,k) = ...
                        mean(directionindex(tube_num, dir1Idxs));
                end
                if phase == 1,
                    all_dir_data(tube_num, :, :) = ...
            [-pos_dir_data(tube_num, 1:half_num_conditions); ...
             -pos_dir_data(tube_num, num_conditions:-1:half_num_conditions+1); ...
             neg_dir_data(tube_num, 1:half_num_conditions); ...
             neg_dir_data(tube_num, num_conditions:-1:half_num_conditions+1)];
                
                elseif phase == 2
            all_dir_data(tube_num, :, :) = ...
            [pos_dir_data(tube_num, 1:half_num_conditions); ...
             pos_dir_data(tube_num, num_conditions:-1:half_num_conditions+1); ...
             -neg_dir_data(tube_num, 1:half_num_conditions); ...
             -neg_dir_data(tube_num, num_conditions:-1:half_num_conditions+1)];
                end
                
         dir_resp(tube_num, :) = mean(all_dir_data(tube_num, :, :), 2);
         
    x = 1:6;
    conds2 = {'UV 5','UV 10','UV 20','UV 30','UV 40',...
        'Green 0','Green 50','Green 100','Green 150','Green 200'};
   
    if phase == 1,    
    
        subplot(length(tubes),5,5*tube_num-(5-seqnum))
        errorbar(dir_resp(tube_num, :), ...
                     std(all_dir_data(tube_num, :, :), 0, 2), ...
                     'k.-', ...
                     'MarkerSize', 15)
        hold on
        plot([0,6], zeros(1,2),'--r')
        hold on
        ylim([-0.4 1]);
        xlim([0 6])
        xlabel('Green Intensity')
        ylabel('frac moving to Green')
        set(gca,'XTick',x,'XTickLabel',condsGR)
        title(conds2{seqnum})
        hold on
        
    elseif phase == 2,
    
        subplot(length(tubes),5,5*tube_num-(10-seqnum))
        errorbar(dir_resp(tube_num, :), ...
                     std(all_dir_data(tube_num, :, :), 0, 2), ...
                     'k.-', ...
                     'MarkerSize', 15)
        hold on
        plot([0,6], zeros(1,2),'--r')
        hold on
        ylim([-0.4 1]);
        xlim([0 6])
        xlabel('UV Intensity')
        ylabel('frac moving to UV')
        set(gca,'XTick',x,'XTickLabel',condsUV)
        title(conds2{seqnum})
        hold on
    end
    
        end
        alltubes_dir_resp(seqnum,:,:) = dir_resp;
    end
    
    if phase == 1,
        suptitle(strcat('Green Variable',' , ',datetime,' , ', genotype))
        save2pdf([out_dir 'Green_variable.pdf'], fig_handle(1));
        
    elseif phase == 2,
        suptitle(strcat('UV Variable',' , ',datetime,' , ', genotype))
        save2pdf([out_dir 'UV_variable.pdf'], fig_handle(2));
        
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
    
    plot([0,7], zeros(1,2)*0.5,'--r')
    hold on
    errorbar(mean(alltubes_dir_resp(seqnum,:,:),2),std(alltubes_dir_resp(seqnum,:,:),0,2),'bs-','MarkerSize',8,'LineWidth',1.25)
    ylim([-0.4 1]);
    xlim([0 6])
    
    
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
end


suptitle(strcat('Summary for All Tubes',' , ',datetime,' , ',genotype))
save2pdf([out_dir 'all_tubes.pdf'], fig_handle(3));


%{
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
    
    set(gca,'XTick',x,'XTickLabel',condsUV)
    title(conds2{seqnum})
    hold on
    
    xlabel('UV Intensity')
    ylabel('frac moving to UV')
    
end
    

suptitle(strcat('Summary Plot - all tubes - both phases',' , ',datetime))
save2pdf([out_dir 'summary.pdf'], fig_handle(4));
%}