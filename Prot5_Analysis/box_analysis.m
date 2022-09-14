function box_analysis(box_data_folder_path, ...
                      experiment_name, ...
                      output_base_dir, ...
                      do_save_plots, ...
                      do_skip_if_already_analyzed, ...
                      exp_merge_output_directory, ...
                      exp_analysis_output_directory)

    % Analyze one run of box data.
    % If do_save_plots is true then plots will be saved to disk.
    % If do_skip_if_already_analyzed is true then we will skip the analysis if
    % it already has been done.  (Normally we run the analysis regardless.)

    % Need the path to the experiment folder
    experiment_folder_path = fullfile(box_data_folder_path, experiment_name) ;

    % Process arguments
    if ~exist('output_base_dir', 'var') || isempty(output_base_dir) ,
        output_base_dir = 'Output_1.1_1.7' ;
    end
    if ~exist('do_save_plots', 'var') || isempty(do_save_plots) ,
        do_save_plots = true ;
    end
    if ~exist('do_skip_if_already_analyzed', 'var') || isempty(do_skip_if_already_analyzed) ,
        do_skip_if_already_analyzed = false ;
    end
    if ~exist('exp_merge_output_directory', 'var') || isempty(exp_merge_output_directory) ,
        exp_merge_output_directory = experiment_folder_path ;
    end
    if ~exist('exp_analysis_output_directory', 'var') || isempty(exp_analysis_output_directory) ,
        exp_analysis_output_directory = experiment_folder_path ;
    end

    % if nargin < 4, skip_analyzed=0; end % default: always save plots
    % if nargin < 3, save_plots = 1; end % default: analyze all
    % if nargin < 2, output_base_dir = 'Output_1.1_1.7'; end
    % if nargin < 1, exp_directory = -1; end

    % % Set the working directory
    % if all(experiment_folder_path == -1)
    %     directory_name = uigetdir;
    %     if (directory_name ~= 0)
    %         %cd(directory_name)
    %         experiment_folder_path = directory_name;
    %     else
    %         error('program terminated, must select a directory name');
    %     end
    % else
    %     %cd(exp_directory)
    % end

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

    % % Get the protocol and temperature(s) from the .exp file
    % [parent_dir, experiment_name, dir_ext] = fileparts(experiment_folder_path);
    % if isempty(experiment_name)
    %     % The path was specified with a trailing slash.
    %     experiment_folder_path = parent_dir;
    %     [~, experiment_name, dir_ext] = fileparts(experiment_folder_path);
    % end
    % % The directory will never have an extension so put the pieces back together. (BOXPIPE-70)
    % experiment_name = [experiment_name dir_ext];

    [protocol, action_sources, temperatures] = get_protocol_action_sources_and_temperatures(box_data_folder_path, experiment_name) ;
    %experiment_file_name = fullfile(experiment_folder_path, [experiment_name '.exp']) ;
    %data = load(experiment_file_name, '-mat') ;
    %experiment_data = data.experiment ;
    %action_sources = experiment_data.actionsource ;
    %action_list = experiment_data.actionlist ;
    temperature_count = length(temperatures) ;
    if temperature_count == 0 ,
        error('Experiment %s has no actions/temperatures in it', experiment_name) ;
    end
    %action_source_1 = action_sources(1);
    %protocol = action_list(action_source_1).name;  % this is the same across the temperatures

    % Set up the low temp analysis
    %temperature_1 = action_list(action_source_1).T ;
    per_temperature_folder_names = ...
        arrayfun(@(i)(sprintf('%02d_%s_%d', action_sources(i), protocol, temperatures(i))), ...
                 1:temperature_count, ...
                 'UniformOutput', false) ;             
    %per_temperature_folder_name_1 = sprintf('%02d_%s_%d', action_sources(1), protocol, temperatures(1));

    % Get the sequence count from the first per-temperature folder
    seq_mat_file_template = fullfile(exp_merge_output_directory, output_base_dir, per_temperature_folder_names{1}, '*.mat') ;
    seq_mat_file_names = simple_dir(seq_mat_file_template) ;
    sequence_count = length(seq_mat_file_names);

    % Populate the AD structure
    AD = struct('seq', cell(1, temperature_count), ...
                'analysis_path', cell(1, temperature_count)) ;
    for i = 1 : temperature_count ,
        AD(i) = create_AD_struct(output_base_dir, sequence_count, protocol, per_temperature_folder_names{i}, action_sources(i)) ;
    end

    % Determine whether or not to run the analysis
    if do_skip_if_already_analyzed ,
        % We won't run the analysis if the experiment has already been
        % analyzed.  So we need to determine whether the experiment has already
        % been analyzed.    
        did_run_temperature_already = false(1, length(temperatures)) ;
        did_generate_comparison_summary = false ;
        try
            out_directory = [experiment_folder_path filesep output_base_dir];
            cd(out_directory)

            for k = 1:length(temperatures)
                analysis_results_file_name = fullfile(experiment_folder_path, [per_temperature_folder_names{k} '_analysis_results.mat']) ;
                if exist(analysis_results_file_name, 'file') ,
                    load(analysis_results_file_name, 'analysis_results') ;
                    if isfield(analysis_results, 'analysis_version')
                         if (analysis_results(1).analysis_version == analysis_version)
                             disp(['Analysis results are up to date for ' num2str(temperatures(k)) ', nothing further required.'])
                             did_run_temperature_already(k) = true ;
                         end        
                     end
                end
            end

            if exist('comparison_summary.pdf', 'file') ,
                did_generate_comparison_summary = true ;
            end
        catch
            error('The directory for the data path is incorrect, check filesystem');
        end
        was_already_analyzed = all(did_run_temperature_already) && did_generate_comparison_summary ;
        do_run_analysis = ~was_already_analyzed ;
    else
        % This is the usual case, where we run the analysis whether or not it's
        % been run before.
        do_run_analysis = true ;
    end

    % Run the analysis, maybe
    if do_run_analysis ,
        %experiment_folder_path = fullfile(box_data_folder_path, experiment_name) ;
        for k = 1:length(temperatures)
            function_handle = str2func(['prot_',strrep(protocol,'.',''),'_analysis']);
            function_handle(experiment_folder_path, do_save_plots, per_temperature_folder_names{k}, temperatures(k), k, AD(k), protocol, analysis_version, ...
                            exp_merge_output_directory, exp_analysis_output_directory) ;
        end
    end

    close all
end



function result = create_AD_struct(output_base_dir, sequence_count, protocol, temp_folder, source)
    result = struct() ;
    for seq_num = 1:sequence_count ,
        result.seq(seq_num).path = fullfile(temp_folder, sprintf('%02d_%s_seq%d', source, protocol, seq_num));
    end
    result.analysis_path = [filesep output_base_dir];
end


