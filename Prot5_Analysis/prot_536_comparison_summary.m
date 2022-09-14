function prot_536_comparison_summary(BoxData,exp_group1,exp_group2, ...
    analysis_feature, plot_mode, saveplot,pdfname,save_path,colors)
% author: Austin Edwards; updates: Lori Laughrey
% 
% input:
%       exp_group1 - cell array of strings containing paths to experiments
%                    in group 1
%       exp_group2 - cell array of strings containing paths to experiments
%                    in group 2 (-1 if no experiments in group 2)
%       analysis_feature - string of feature to plot
%       plot_mode
%       save_plot

protocol = '5.36';

if nargin < 6
    saveplot = 1;
end

if nargin < 9,
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
    exp_group1_data = BoxData(ismember({BoxData.experiment_name},exp_group1));
    nexp_group1 = length(exp_group1_data);
    
    exp_group1_effector = unique(BoxData(ismember({BoxData.experiment_name},exp_group1)).effector);
    
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

% Include all of above code, then create sections for each sequence.
% Choose the type of analysis to be used with this sequence, and delete the
% other analyses.

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 1;                 % indicates which set of sequences
seq = 'seq1';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 0.6 2 5 10 20 42 42 20 10 5 2 0.67 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '4 on / 4 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;
%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 1;                 % indicates which set of sequences
seq = 'seq2';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '1 on / 7 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 1;                 % indicates which set of sequences
seq = 'seq3';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '1 on / 15 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 1;                 % indicates which set of sequences
seq = 'seq4';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '1 on / 31 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 2;                 % indicates which set of sequences
seq = 'seq5';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '7 on / 1 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 2;                 % indicates which set of sequences
seq = 'seq6';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '15 on / 1 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;

%% --- Indicate the sequence being analyzed                            <-  for each sequence, begin copying here.
phase = 2;                 % indicates which set of sequences
seq = 'seq7';              % indicates which sequence in the set

%% - Motion Analysis
analysis_feature = 'mean_dir_index';

plot_conditions = [0 2 5 10 10 5 2 0]; %stimulus speeds
x_variable = 'Temporal Freqency (Hz)';
y_variable = 'Direction Index';
sequence_title = '31 on / 1 off';
num_conditions = length(plot_conditions);
half_num_conditions = num_conditions/2;
y_lim = 1;
n_y_lim = -0.2;

linear_motion_comparison;
subplot_count = subplot_count + 1;



%% -- include all of remaining code after sequence analyses sections
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
    
    for i = 1:nexp_group1                       %  <-  change 2 to 1
        
        %if strendswith(exp_group1,'control'),
        %  genotype = exp_group2_data(i).genotype;
        %  date_time = exp_group2_data(i).date_time;
        %else
          genotype = exp_group1_data(i).genotype;
          date_time = exp_group1_data(i).date_time;
        %end
        
        text(10, (0.2*(i-1)), ... 
                 genotype, ...
                 'HorizontalAlignment', 'right', ...
                 'Interpreter', 'none', ...
                 'FontSize', 14, ...
                 'Color', colorOrder(mod(i,7)+1,:), ...
                 'BackgroundColor',[1 1 1])
             
        text(10, (0.1+0.2*(i-1)), ... 
                 exp_group1_data(i).date_time, ...              %   <-  change 2 to 1
                 'HorizontalAlignment', 'right', ...
                 'Interpreter', 'none', ...
                 'FontSize', 14, ...
                 'Color', colorOrder(mod(i,7)+1,:), ...
                 'BackgroundColor',[1 1 1])
    end
%    text(10, 0.30, ... 
%            'controls', ...
%            'HorizontalAlignment', 'right', ...
%%%            'Interpreter', 'none', ...
%            'FontSize', 14, ...
%            'Color', 'k', ...
%            'BackgroundColor',[1 1 1])
end

if plot_mode == 1
    suptitle('Protocol 5.36 Comparison Summary')
end

if plot_mode == 2
    suptitle('Protocol 5.36 Comparison Summary - Individual Tubes with Mean')
end

if plot_mode == 3
    suptitle('Protocol 5.36 Comparison Summary - Optomotor (Temporal Tuning) - Repeated Experiments')
end

if saveplot == 1
     if plot_mode == 3
         savefig(fullfile(save_path,[pdfname '.fig']))          % <- save as fig 
        save2pdf(fullfile(save_path, [pdfname '.pdf']));
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