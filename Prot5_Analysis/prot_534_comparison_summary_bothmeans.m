function prot_534_comparison_summary(BoxData,exp_group1,exp_group2, ...
    analysis_feature, plot_mode, saveplot,pdfname,savepath,colors)
% author: Austin Edwards
% 
% input:
%       exp_group1 - cell array of strings containing paths to experiments
%                    in group 1
%       exp_group2 - cell array of strings containing paths to experiments
%                    in group 2 (-1 if no experiments in group 2)
%       analysis_feature - string of feature to plot
%       plot_mode
%       save_plot

protocol = '5.34';

if nargin < 6
    saveplot = 1;
end

if nargin < 8,
    colors = {'k','r'};
end


% set exp_group2 to be -1 if no experiments in group2
if isnumeric(exp_group2) == 1, exp_group2 = -1;
end

if strendswith(exp_group1,'control')    
    
 % get number of experiments in each group
    exp_group2_data = BoxData(ismember({BoxData.experiment_name},exp_group2));
    nexp_group2 = length(exp_group2_data);

    if isempty(exp_group2_data)
        return
    end
    
    exp_group2_effector = BoxData(ismember({BoxData.experiment_name},exp_group2)).effector;
    
    % get number of experiments in each group
    exp_group1_data = BoxData(strcmp({BoxData.type},exp_group1) & ...
        strcmp({BoxData.protocol},protocol) & ...
        strcmp({BoxData.effector},exp_group2_effector));
    nexp_group1 = length(exp_group1_data);
    
    
    
elseif strendswith(exp_group2,'control')
    
    % get number of experiments in each group
    exp_group1_data = BoxData(ismember({BoxData.experiment_name},exp_group1)); %returns the box data for just this experiment
    nexp_group1 = length(exp_group1_data);
    
    exp_group1_effector = BoxData(ismember({BoxData.experiment_name},exp_group1)).effector;
    
    exp_group2_data = BoxData(strcmp({BoxData.type},exp_group2) & ...
        strcmp({BoxData.protocol},protocol) & ...
        strcmp({BoxData.effector},exp_group1_effector));
    nexp_group2 = length(exp_group2_data);
   
else
    exp_group1_data = BoxData(ismember({BoxData.experiment_name},exp_group1));
    nexp_group1 = length(exp_group1_data);
  if exp_group2~=-1,
    error('If one group is not set to "controls", exp_group2 must be -1')
  end
  if isnumeric(exp_group1) && isnumeric(exp_group2),
      error('One of the groups has to be experiments')
  end
end

% Create structs with metadata for experiments
%exp_group1 = parse_explist(exp_group1,plot_mode,protocol);
%if ~isnumeric(exp_group2)
%    exp_group2 = parse_explist(exp_group2,plot_mode,protocol);
%end

if plot_mode == 2 && (~isnumeric(exp_group2) || nexp_group1 > 1)
    error('Cannot plot individual tubes for more than one experiment')
end

close all

figure(1)
set(1, 'Position', [30 55 1500 1500]);
subplot_count = 1;

phase = 1;

% Seq 2 : Phototaxis
seq = 'seq2';
min_num_flies = 2; % minimum number of flies in tubes
del_t = 1/25; %inverse frames per second
dir1_starts = [125 875 1625 2375];
dir2_starts = [500 1250 2000 2750];
ma_points = 8; % number of points to use in ma smoothing of the velocity plot
plot_conditions = {'G = 20', 'G = 120', 'UV = 15', 'UV = 200'};
X_label_short = {'GL', 'GH', 'UL', 'UH'};
tube_length = 112.55; %length of tube in mm

num_conditions = length(dir1_starts);
analysis_feature = 'cum_dir_index_max';

phototaxis_comparison;
subplot_count = subplot_count + 1;

% Seq 3 : Color Preference

seq = 'seq3';
min_num_flies = 2; % minimum number of flies in tubes
del_t = 1/25; %inverse frames per second
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
plot_conditions = [0 3 10 20 30 50 100 200 200 100 50 30 20 10 3 0];
x_variable = 'Green Intensity';
y_variable = 'cum_dir_index_peak';
sequence_title = 'Color Preference, UV Constant';

num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;
analysis_feature = 'cum_dir_index_peak';
y_lim_DI = 1;
y_lim_cum_DI = 4*y_lim_DI;

color_preference_comparison;
subplot_count = subplot_count + 1;

% Seq 4

seq = 'seq4';
min_num_flies = 2; % minimum number of flies in tubes
del_t = 1/25; %inverse frames per second
dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
plot_conditions = [0 5 10 15 25 50 100 200 200 100 50 25 15 10 5 0];
x_variable = 'UV Intensity';
y_variable = 'cum_dir_index_peak';
sequence_title = 'Color Preference, Green Constant';

num_conditions = length(dir1_starts);
half_num_conditions = num_conditions/2;
analysis_feature = 'cum_dir_index_peak';
y_lim_DI = 1;
y_lim_cum_DI = 4*y_lim_DI;

color_preference_comparison;
subplot_count = subplot_count + 1;


phase = 2;

analysis_feature = 'mean_dir_index';
seq = 'seq5';

plot_conditions = [0 0.67 2 5 10 20 42 42 20 10 5 2 0.67 0]; %stimulus speeds
x_variable = 'Temporal Frequency (Hz)';
y_variable = 'Direction Index';
sequence_title = 'Optomotor (Temporal Tuning)';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison_bothmean;
subplot_count = subplot_count + 1;

% Seq 3 : Contrast

seq = 'seq6';

plot_conditions = [0.07, 0.2, 0.5, 0.7, 1, 1, 0.7, 0.5, 0.2, 0.07]; %stimulus speeds
x_variable = 'Contrast';
y_variable = 'Direction Index';
sequence_title = 'Contrast (Constant Intensity)';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

% Seq 4 : Contrast

seq = 'seq7';

plot_conditions = [0.1, 0.3, 0.4, 0.7, 1, 1, 0.7, 0.4, 0.2, 0.1]; %stimulus speeds
x_variable = 'Contrast';
y_variable = 'Direction Index';
sequence_title = 'Contrast (Increasing Intensity)';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

% Seq 5 : Spatial

seq = 'seq8';

plot_conditions = [3, 4, 6, 8, 12, 16, 32, 32, 16, 12, 8, 6, 4, 3]; %stimulus speeds
x_variable = 'Pixels per Cycle';
y_variable = 'Direction Index';
sequence_title = 'Optomotor (Spatial Tuning)';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;


if plot_mode == 1,
    if strendswith(exp_group1,'control'),
        genotype = exp_group2_data.genotype;
        date_time = exp_group2_data.date_time;
    else
        genotype = exp_group1_data.genotype;
        date_time = exp_group1_data.date_time;
    end
    text(17, 0.5, ... 
             genotype, ...
             'HorizontalAlignment', 'right', ...
             'Interpreter', 'none', ...
             'FontSize', 14, ...
             'Color', colors{2}, ...
             'BackgroundColor',[1 1 1])
    text(17, 0.40, ... 
             date_time, ...
             'HorizontalAlignment', 'right', ...
             'Interpreter', 'none', ...
             'FontSize', 14, ...
             'Color', colors{2}, ...
             'BackgroundColor',[1 1 1])

    text(17, 0.30, ... 
            'controls', ...
            'HorizontalAlignment', 'right', ...
            'Interpreter', 'none', ...
            'FontSize', 14, ...
            'Color', colors{1}, ...
            'BackgroundColor',[1 1 1])
end

if plot_mode == 2,
    if exp_group2==-1,
        genotype = exp_group1_data.genotype;
        date_time = exp_group1_data.date_time;
    else
        genotype = exp_group2_data.genotype;
        date_time = exp_group2_data.date_time;
    end
    text(17, 0.5, ... 
             genotype, ...
             'HorizontalAlignment', 'right', ...
             'Interpreter', 'none', ...
             'FontSize', 14, ...
             'Color', colors{2}, ...
             'BackgroundColor',[1 1 1])
    text(17, 0.40, ... 
             date_time, ...
             'HorizontalAlignment', 'right', ...
             'Interpreter', 'none', ...
             'FontSize', 14, ...
             'Color', colors{2}, ...
             'BackgroundColor',[1 1 1])
end

if plot_mode == 3
    colorOrder = get(gca, 'ColorOrder');
    
    for i = 1:nexp_group2
        
        if strendswith(exp_group1,'control'),
          genotype = exp_group2_data(i).genotype;
          date_time = exp_group2_data(i).date_time;
        else
          genotype = exp_group1_data(i).genotype;
          date_time = exp_group1_data(i).date_time;
        end
        
        text(17, (0.5+0.2*(i-1)), ... 
                 genotype, ...
                 'HorizontalAlignment', 'right', ...
                 'Interpreter', 'none', ...
                 'FontSize', 14, ...
                 'Color', colorOrder(i,:), ...
                 'BackgroundColor',[1 1 1])
             
        text(17, (0.40+0.2*(i-1)), ... 
                 date_time, ...
                 'HorizontalAlignment', 'right', ...
                 'Interpreter', 'none', ...
                 'FontSize', 14, ...
                 'Color', colorOrder(i,:), ...
                 'BackgroundColor',[1 1 1])
    end             
    text(17, 0.30, ... 
            'controls', ...
            'HorizontalAlignment', 'right', ...
            'Interpreter', 'none', ...
            'FontSize', 14, ...
            'Color', 'k', ...
            'BackgroundColor',[1 1 1])
end

if plot_mode == 1
    suptitle('Protocol 5.34 Comparison Summary')
end

if plot_mode == 2
    suptitle('Protocol 5.34 Comparison Summary - Individual Tubes with Mean')
end

if plot_mode == 3
    suptitle('Protocol 5.34 Comparison Summary - Repeated Experiments')
end

if saveplot == 1
     if plot_mode == 3              
        save2pdf([savepath pdfname '.pdf']);
     else
        if strendswith(exp_group1,'control'),
          path = exp_group2_data.path;
        else
            path = exp_group1_data.path;
        end
        if ismac,
            path = strrep(path,'\','/');
            path = strrep(path,'//tier2.hhmi.org/','/Volumes/');
        elseif ispc,
            path = strrep(path,'/','\');
            path = strrep(path,'\Volumes\','\\tier2.hhmi.org\');
        end
        save2pdf(fullfile(path, 'Output_1.1_1.7', [pdfname, '.pdf']));
     end
end
