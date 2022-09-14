function box_analysis(exp_directory, output_base_dir, save_plots, skip_analyzed)

% Analyze one run of box data.
% If save_plots is 1 then plots will be saved to disk.
% If skip_analyzed is 1 then analysis

%% Process arguments
if nargin < 4, skip_analyzed=0; end % default: always save plots
if nargin < 3, save_plots = 1; end % default: analyze all
if nargin < 2, output_base_dir = 'Output'; end
if nargin < 1, exp_directory = -1; end

%% Set the working directory
if all(exp_directory == -1)
    directory_name = uigetdir;
    if (directory_name ~= 0)
        cd(directory_name)
        exp_directory = directory_name;
    else
        error('program terminated, must select a directory name');
    end
else
    cd(exp_directory)
end

%%
close all 

% * modified from 1.1 to denote protocol 3.0 analysis by wlk
% * modified from 1.2 by MR to make the use of sequence details simpler!
% * modified from 1.3 to 1.4 by MR to use the tracking by single tubes...
% * modified from 1.4 to 1.5 by to incorporate changes to analysis_results
% and plot output updates
% * modified from 1.5 to 1.6 by AL for bugfixes and new directional-pref stats 
% * modified from 1.6 to 1.7 by AL on 20131226 for new S4 stats: disp_max_time, disp_end.
analysis_version = 1.7;    

%% Get the protocol and temperature(s) from the .exp file
[parent_dir, experiment_name, dir_ext] = fileparts(exp_directory);
if isempty(experiment_name)
    % The path was specified with a trailing slash.
    exp_directory = parent_dir;
    [~, experiment_name, dir_ext] = fileparts(exp_directory);
end
% The directory will never have an extension so put the pieces back together. (BOXPIPE-70)
experiment_name = [experiment_name dir_ext];

data = load(fullfile(exp_directory, [experiment_name '.exp']), '-mat');
source = data.experiment.actionsource(1);
protocol = data.experiment.actionlist(1, source).name;
temp_count = length(data.experiment.actionsource);

%% Set up the low temp analysis
temp(1) = data.experiment.actionlist(1, source).T;
temp_folder{1} = sprintf('%02d_%s_%d', source, protocol, temp(1));

for seq_num = 1:5
    AD(1).seq(seq_num).path = fullfile(temp_folder{1}, sprintf('%02d_%s_seq%d', source, protocol, seq_num));
end
AD(1).analysis_path = [filesep output_base_dir];

%% Set up the high temp analysis
if temp_count == 2
    source = data.experiment.actionsource(2);
    temp(2) = data.experiment.actionlist(1, source).T;
    temp_folder{2} = sprintf('%02d_%s_%d', source, protocol, temp(2));

    for seq_num = 1:5
        AD(2).seq(seq_num).path = fullfile(temp_folder{2}, sprintf('%02d_%s_seq%d', source, protocol, seq_num));
    end
    AD(2).analysis_path = [filesep output_base_dir];
end


run_flag = zeros(1, length(temp) + 1);
    
out_directory = [exp_directory filesep output_base_dir];

%% Check if the analysis has already been run
if (skip_analyzed)

    try
        cd(out_directory)
        
        for k = 1:length(temp)
            if (exist([temp_folder{k} '_analysis_results.mat'], 'file') == 2)
                load([temp_folder{k} '_analysis_results.mat'])
                if isfield(analysis_results, 'analysis_version')
                     if (analysis_results(1).analysis_version == analysis_version)
                         disp(['Analysis results are up to date for ' num2str(temp(k)) ', nothing further required.'])
                         run_flag(k) = 1;
                     end        
                 end
            end
        end

        if (exist('comparison_summary.pdf', 'file') == 2)
            run_flag(end) = 1;
        end
    catch
        error('The directory for the data path is incorrect, check filesystem');
    end
end

%% Run the analysis if needed
if sum(run_flag) ~= temp_count + 1
    for k = 1:length(temp)
        exp_detail = prot_31_41_analysis(exp_directory, save_plots, temp_folder{k}, temp(k), AD(k), protocol, analysis_version);
    end
    
    prot_31_41_comparison_plot(exp_directory, out_directory, save_plots, temp_folder, temp, exp_detail, protocol);
end

close all
