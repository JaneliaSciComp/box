function prot_514_tube_means(exp_directory, output_base_dir, save_plots)

%% Process arguments
if nargin < 3, save_plots = 1; end % default: analyze all
if nargin < 2, output_base_dir = 'Output_1.1_1.7'; end
if nargin < 1, error('Please give a valid experiment directory'); end

%% Set the working directory

cd([exp_directory filesep output_base_dir])
close all 

figure(1)
% for phase 1, load analysis results
load('01_5.14_34_analysis_results.mat');

%% seq5, spatial tuning
sequence = 'seq1';
dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625, 5125, 5625, 6125, 6625];
plot_conditions = [1, 2, 3, 4, 6, 8, 16, 16, 8, 6, 4, 3, 2, 1]; %stimulus speeds
x_variable = 'Spatial Frequency';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;
motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = 1:6,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(3, 2, 1)

errorbar([1:half_num_conditions],mean(motion_resp,1),std(motion_resp), 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 1/0 (Median X Vel)')

subplot(3, 2, 2)

errorbar([1:half_num_conditions],mean(dir_idx,1),std(dir_idx), 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 1/0 (Dir Idx)')


%% seq2, spatial tuning, 3/15
sequence = 'seq2';
dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625, 5125, 5625, 6125, 6625];
plot_conditions = [1, 2, 3, 4, 6, 8, 16, 16, 8, 6, 4, 3, 2, 1]; %stimulus speeds
x_variable = 'Spatial Frequency';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;
motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = 1:6,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(3, 2, 3)

shadedErrorBar([],motion_resp,{@mean,@std}, 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 3/0 (Median X Vel)')

subplot(3, 2, 4)

shadedErrorBar([], dir_idx, {@mean,@std}, 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 3/0 (Dir Idx)')


%% seq2, spatial tuning, 5/15
sequence = 'seq3';
dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625, 5125, 5625, 6125, 6625];
plot_conditions = [1, 2, 3, 4, 6, 8, 16, 16, 8, 6, 4, 3, 2, 1]; %stimulus speeds
x_variable = 'Spatial Frequency';
num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;

y_lim_vel = 20;
y_lim_DI = 1;
motion_resp = nan(6,half_num_conditions);
dir_idx = nan(6,half_num_conditions);

for tube = 1:6,

    motion_resp(tube,:) = analysis_results(tube).(sequence).mean_motion_resp(:);
    dir_idx(tube,:) = analysis_results(tube).(sequence).mean_dir_index(:);

end

subplot(3, 2, 5)

shadedErrorBar([],motion_resp,{@mean,@std}, 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_vel y_lim_vel]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 5/0 (Median X Vel)')

subplot(3, 2, 6)

shadedErrorBar([], dir_idx, {@mean,@std}, 'k')

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 -0.1*y_lim_DI y_lim_DI]);
xlabel(x_variable)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions))
title('On/Off Intensity 5/0 (Dir Idx)')

save2pdf([exp_directory filesep output_base_dir filesep 'All_Tubes_All_Sequences.pdf']);