function prot_513_tube_means(exp_directory, output_base_dir, save_plots)

%% Process arguments
if nargin < 3, save_plots = 1; end % default: analyze all
if nargin < 2, output_base_dir = 'Output_1.1_1.7'; end
if nargin < 1, error('Please give a valid experiment directory'); end

%% Set the working directory

tubes = [3,4,5];


cd([exp_directory filesep '01_5.13_34'])

cur_dir = dir('*.m');
    
    for j = 1:length(cur_dir)
        if (strcmp(cur_dir(j).name(1:16), 'sequence_details'))
            try 
                fid = fopen([cur_dir(j).name(1:end-2) '.m']);
                script = fread(fid, '*char')';
                fclose(fid);
                eval(script);
            catch exception
                fprintf(['Error: sequence_details file ' cur_dir(j).name ' does not load or is missing crucial info.'])            
                throw(exception)
            end
        end
    end
    
genotype = exp_detail.tube_info(1).Genotype;
exp_datetime = exp_directory(end-14:end);

cd([exp_directory filesep output_base_dir])
close all

figure(1)
set(1, 'Position', [30 55 1500 1500]);

% for phase 1, load analysis results
load('01_5.13_34_analysis_results.mat');



%% seq2, Linear Motion Analysis

%parameters for seq2
sequence = 'seq2';
dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625,5125,5625,6125,6625];
plot_conditions = [0 0.67 2 5 10 20 42 42 20 10 5 2 0.67 0]; %stimulus speeds
x_variable = 'Temporal Freqency';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;
%pull out motion response/direction index values for every tube

motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = tubes,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(4, 4, 1)

errorbar([1:half_num_conditions],nanmean(motion_resp,1),std(motion_resp), 'k')
box off  
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))

title('Optomotor (Median X Vel)')

subplot(4, 4, 2)

errorbar([1:half_num_conditions],mean(dir_idx,1),std(dir_idx), 'k')
box off 
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))

title('Optomotor (Dir Idx)')

%% Seq3, contrast series w. same average intensity

sequence = 'seq3';

dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625];
plot_conditions = [0.07, 0.2, 0.5, 0.7, 1, 1, 0.7, 0.5, 0.2, 0.07]; %stimulus speeds
x_variable = 'Contrast';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;

motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = tubes,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(4, 4, 3)

errorbar([1:half_num_conditions],mean(motion_resp,1),std(motion_resp), 'k')
box off   
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Constant Intensity Contrast (Median X Vel)')
subplot(4, 4, 4)

errorbar([1:half_num_conditions],mean(dir_idx,1),std(dir_idx), 'k')
box off   
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Constant Intensity Contrast (Dir Idx)')




%% seq4, contrast series w. increasing intensity
sequence = 'seq4';

dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625];
plot_conditions = [0.1, 0.3, 0.4, 0.7, 1, 1, 0.7, 0.4, 0.2, 0.1]; %stimulus speeds
x_variable = 'Contrast';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;

motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = tubes,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(4, 4, 5)

errorbar([1:half_num_conditions],mean(motion_resp,1),std(motion_resp), 'k')
box off 
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Increasing Intensity Contrast (Median X Vel)')
subplot(4, 4, 6)

errorbar([1:half_num_conditions],mean(dir_idx,1),std(dir_idx), 'k')
box off 
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Increasing Intensity Contrast (Dir Idx)')

%% seq5, spatial tuning
sequence = 'seq5';
dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625, 5125, 5625, 6125, 6625];
plot_conditions = [3, 4, 6, 8, 12, 16, 32, 32, 16, 12, 8, 6, 4, 3]; %stimulus speeds
x_variable = 'Pixels per cycle';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;
motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = tubes,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(4, 4, 7)

errorbar([1:half_num_conditions],mean(motion_resp,1),std(motion_resp), 'k')
box off 
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Spatial Tuning (Median X Vel)')

subplot(4, 4, 8)

errorbar([1:half_num_conditions],mean(dir_idx,1),std(dir_idx), 'k')
box off 
set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('Spatial Tuning (Dir Idx)')

clear analysis_results
load('02_5.13_34_analysis_results.mat');


%% Seq 6 - Phototaxis
%Parameters
sequence = 'seq6';
del_t = 1/25; %inverse frames per second
dir1_starts = [125 875 1625 2375];
dir2_starts = [500 1250 2000 2750];
X_label_short = {'GL', 'GH', 'UL', 'UH'};

trial_length = dir2_starts(1) - dir1_starts(1);
trial_time = trial_length*del_t;
num_conditions = length(dir1_starts);

y_lim_vel = 30;
y_lim_disp = 6*y_lim_vel; % (180 for current expts)
y_lim_DI = 1;
y_lim_cum_DI = 8*y_lim_DI; % (8 for current expts)
plot_gap = 40; %DEFINE
time_gap = plot_gap*del_t;

%Pulling out data

med_disp_x = nan(6,size(analysis_results(1).(sequence).med_disp_x(:),1));
mean_cum_dir_idx = nan(6,size(analysis_results(1).(sequence).mean_cum_dir_index(:),1));

for tube = tubes,

    med_disp_x(tube,:) = analysis_results(tube).(sequence).med_disp_x(:);
    mean_cum_dir_idx(tube,:) = analysis_results(tube).(sequence).mean_cum_dir_index(:);
end


subplot(4, 4, 9)

for k = 1:num_conditions
    plot_range = trial_length*(k-1) + (1:trial_length);
    time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
    
    shadedErrorBar(time_range,med_disp_x(:,plot_range),{@mean, @std},'k')
    hold on
    plot(time_range(1)*[1 1], [0 y_lim_disp]',  'r')            
end
plot([0 time_range(end)], [0 0], 'r')
box off
axis([0 time_range(end) -0.25*y_lim_disp y_lim_disp]); 
hold on
set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
    'Xticklabel', X_label_short);
text(time_range(end)/2, 1.15*y_lim_disp, ...
    'Phototaxis (med x disp in mm)', ...
    'HorizontalAlignment', 'center')  
xlabel('time (s)')


subplot(4, 4, 10)

for k = 1:num_conditions
    plot_range = trial_length*(k-1) + (1:trial_length);
    time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
    
    shadedErrorBar(time_range,mean_cum_dir_idx(:,plot_range),{@mean, @std},'k')
    hold on
    plot(time_range(1)*[1 1], [0 y_lim_cum_DI]',  'r')            
end
plot([0 time_range(end)], [0 0], 'r')

axis([0 time_range(end) -0.25*y_lim_cum_DI y_lim_cum_DI]);
box off
hold on
set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
    'Ytick', [0 y_lim_cum_DI], ...
    'Xticklabel', X_label_short);
text(time_range(end)/2, 1.15*y_lim_cum_DI, ...
             'Phototaxis (DirIdx)', ...
             'HorizontalAlignment', 'center')  
xlabel('time (s)')




%% Seq 7 - UV Constant Color Preference

sequence = 'seq7';
min_num_flies = 2; % minimum number of flies in tubes
del_t = 1/25; %inverse frames per second
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625 8125 8625 9125 9625 10125 10625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875 8375 8875 9375 9875 10375 10875];
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
X_label = [0 5 10 15 20 30 40 50 75 100 200 200 100 75 50 40 30 20 15 10 5 0];
tube_length = 112.55; %length of tube in mm
pref_index = [1 2 7 8]; % indices to use for preference index
X_variable = 'Green Intensity';

offset = dir1_starts(1);
trial_length = dir2_starts(1) - dir1_starts(1);
trial_time = trial_length*del_t;
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;
data_length = dir2_starts(end) + trial_length - offset;

t_tick = 0:30:data_length*del_t;
y_lim_vel = 30;
y_lim_disp = 6*y_lim_vel; % (180 for current expts)
y_lim_DI = 1;
y_lim_cum_DI = 4*y_lim_DI; % (8 for current expts)
plot_gap = 40; %DEFINE
time_gap = plot_gap*del_t;

% Pull out data

mean_cum_dir_index = nan(6,size(analysis_results(1).(sequence).mean_cum_dir_index(:),1));
cum_dir_index_peak = nan(6,size(analysis_results(1).(sequence).cum_dir_index_peak(:),1));

for tube = tubes,

    mean_cum_dir_index(tube,:) = analysis_results(tube).(sequence).mean_cum_dir_index(:);
    cum_dir_index_peak(tube,:) = analysis_results(tube).(sequence).cum_dir_index_peak(:);
end


%plot time series

subplot(4, 4, 11)
   
for k = 1:half_num_conditions
    plot_range = trial_length*(k-1) + (1:trial_length);
    time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
    shadedErrorBar(time_range,mean_cum_dir_index(:,plot_range),{@mean, @std},'k')
    hold on
    plot(time_range(1)*[1 1], [-y_lim_cum_DI y_lim_cum_DI]',  'r')
    hold on
end

plot([0 time_range(end)], [0 0], 'r')

axis([0 time_range(end) -y_lim_cum_DI y_lim_cum_DI]);

box off    
set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
         'Ytick', [-y_lim_cum_DI 0 y_lim_cum_DI], ...
         'Xticklabel', X_label, ... 
         'FontSize', 6);

text(time_range(end)/2, 1.15*y_lim_cum_DI, ...
     'UV Constant cum Dir Idx', ...
     'HorizontalAlignment', 'center')  


xlabel('time (s)')
ylabel('to green')
set(gca, 'XTickLabel', X_label); 


% plot the peak (or end point) values for the cumulative direction
% index
subplot(4,4,12)

errorbar([1:half_num_conditions],mean(cum_dir_index_peak,1),std(cum_dir_index_peak),'k')
hold on
plot([0 num_conditions], [0 0], 'r') 
box off 
title('UV Constant peak cum dir index')  

axis([0.5 half_num_conditions+0.5 -y_lim_cum_DI y_lim_cum_DI]);
box off    
set(gca, 'Xtick', 1:half_num_conditions, ...
         'Ytick', [-y_lim_cum_DI 0 y_lim_cum_DI], ...
         'Xticklabel', X_label, ...
         'FontSize', 6);

xlabel(X_variable)
ylabel('to green')

%% Seq 8 - Green Constant Color Preference

sequence = 'seq8';
min_num_flies = 2; % minimum number of flies in tubes
del_t = 1/25; %inverse frames per second
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625 8125 8625 9125 9625 10125 10625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875 8375 8875 9375 9875 10375 10875];
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
X_label = [5 7 10 15 20 30 40 50 75 100 200 200 100 75 50 40 30 20 15 10 7 5];
tube_length = 112.55; %length of tube in mm
pref_index = [1 2 7 8]; % indices to use for preference index
X_variable = 'UV Intensity';

offset = dir1_starts(1);
trial_length = dir2_starts(1) - dir1_starts(1);
trial_time = trial_length*del_t;
num_conditions = length(dir1_starts);
data_length = dir2_starts(end) + trial_length - offset;

t_tick = 0:30:data_length*del_t;
y_lim_vel = 30;
y_lim_disp = 6*y_lim_vel; % (180 for current expts)
y_lim_DI = 1;
y_lim_cum_DI = 4*y_lim_DI; % (8 for current expts)
plot_gap = 40; %DEFINE
time_gap = plot_gap*del_t;

% Pull out data

mean_cum_dir_index = nan(6,size(analysis_results(1).(sequence).mean_cum_dir_index(:),1));
cum_dir_index_peak = nan(6,size(analysis_results(1).(sequence).cum_dir_index_peak(:),1));

for tube = tubes,

    mean_cum_dir_index(tube,:) = analysis_results(tube).(sequence).mean_cum_dir_index(:);
    cum_dir_index_peak(tube,:) = analysis_results(tube).(sequence).cum_dir_index_peak(:);
end


%plot time series

subplot(4, 4, 13)
   
for k = 1:half_num_conditions
    plot_range = trial_length*(k-1) + (1:trial_length);
    time_range = ((trial_length + plot_gap)*(k-1) + (1:trial_length))*del_t;
    shadedErrorBar(time_range,mean_cum_dir_index(:,plot_range),{@mean, @std},'k')
    hold on
    plot(time_range(1)*[1 1], [-y_lim_cum_DI y_lim_cum_DI]',  'r')
    hold on
end

plot([0 time_range(end)], [0 0], 'r')

axis([0 time_range(end) -y_lim_cum_DI y_lim_cum_DI]);

box off    
set(gca, 'Xtick', (0.5*trial_time):(trial_time+time_gap):(num_conditions*(trial_time+time_gap)+0.5*trial_time), ...
         'Ytick', [-y_lim_cum_DI 0 y_lim_cum_DI], ...
         'Xticklabel', X_label, ... 
         'FontSize', 6);

text(time_range(end)/2, 1.15*y_lim_cum_DI, ...
     'Green Constant, Cum DirIdx', ...
     'HorizontalAlignment', 'center')  


xlabel('time (s)')
ylabel('to green')
set(gca, 'XTickLabel', X_label); 


% plot the peak (or end point) values for the cumulative direction
% index
subplot(4,4,14)

errorbar([1:half_num_conditions],mean(cum_dir_index_peak,1),std(cum_dir_index_peak),'k')
hold on
plot([0 num_conditions], [0 0], 'r') 
box off 
title('Green Constant peak cum dir index')  

axis([0.5 half_num_conditions+0.5 -y_lim_cum_DI y_lim_cum_DI]);
box off    
set(gca, 'Xtick', 1:half_num_conditions, ...
         'Ytick', [-y_lim_cum_DI 0 y_lim_cum_DI], ...
         'Xticklabel', X_label, ...
         'FontSize', 6);

xlabel(X_variable)
ylabel('to green')
genotype = strrep(genotype,'_',' ');
suptitle(sprintf([genotype,filesep,exp_datetime]))

if save_plots == 1,
    save2pdf([exp_directory filesep output_base_dir filesep 'All_Tubes_All_Sequences.pdf']);
end
