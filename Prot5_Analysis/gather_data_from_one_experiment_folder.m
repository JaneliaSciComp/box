function [was_tracked, box_data_for_this_experiment] = ...
        gather_data_from_one_experiment_folder(box_data_folder_path, experiment_name, ...
                                               box_data_merge_output_folder_path, box_data_analysis_output_folder_path, ...
                                               minimum_fly_count)
                                           
    % Make sure each of the per-temperature folders is present                                       
    [protocol, action_sources, temperatures] = get_protocol_action_sources_and_temperatures(box_data_folder_path, experiment_name) ;
    temperature_count = length(temperatures) ;
    per_temperature_folder_names = ...
        arrayfun(@(i)(sprintf('%02d_%s_%d', action_sources(i), protocol, temperatures(i))), ...
                 1:temperature_count, ...
                 'UniformOutput', false) ;
    for phase_index = 1 : temperature_count ,
        per_temperature_folder_name = per_temperature_folder_names{phase_index} ;
        per_temperature_folder_path = fullfile(box_data_folder_path, experiment_name, per_temperature_folder_name) ;
        if ~exist(per_temperature_folder_path, 'dir') ,
            was_tracked = false ;
            box_data_for_this_experiment = [] ;
            return
        end
    end

    % Verify that the output folder exists
    output_folder_names = simple_dir(fullfile(box_data_folder_path, experiment_name, 'Output*')) ;
    if isempty(output_folder_names) ,
        was_tracked = false ;
        box_data_for_this_experiment = [] ;        
        return
    end
    if length(output_folder_names) > 1 ,
        fprintf('More than one output folder for experiment %s.  Using the first one.\n', experiment_name) ;
    end
    output_folder_name = output_folder_names{1} ;
    %output_folder_name = output_folder_names.name;
    %experiment_name = experiment_name ;
    
    % Verify that the analysis result file exists, at least for the first
    % temperature
    analysis_results_mat_file_name = ...
        fullfile(box_data_analysis_output_folder_path, experiment_name, output_folder_name, ...
                 sprintf('%02d_%s_%d_analysis_results.mat', action_sources(1), protocol, temperatures(1)) ) ;
    was_tracked  = exist(analysis_results_mat_file_name, 'file') ;
    if ~was_tracked ,                    
        box_data_for_this_experiment = [] ;        
        return
    end
    
    %cd(phase1_folder.name)
    sequence_details_file_name_template = fullfile(box_data_folder_path, experiment_name, per_temperature_folder_names{1}, '*.m') ;
    sequence_details_file_names = simple_dir(sequence_details_file_name_template) ;

    for j = 1:length(sequence_details_file_names)
        %cur_dir(j).name %just debug
        sequence_details_file_name = sequence_details_file_names{j} ;                        
        sequence_details_path_name = fullfile(box_data_folder_path, experiment_name, per_temperature_folder_names{1}, sequence_details_file_name) ;
        if (strcmp(sequence_details_file_name(1:16), 'sequence_details'))
            try
                fid = fopen(sequence_details_path_name);
                script = fread(fid, '*char')';
                fclose(fid);
                eval(script);
            catch exception
                fprintf(['Error: sequence_details file ' sequence_details_file_name ' does not load or is missing crucial info.'])
                throw(exception)
            end
        end
    end

    % Sometimes the scripts are messed up and don't create the right
    % variables
    if ~exist('exp_detail', 'var') || ~exist('BoxName', 'var') ,
        was_tracked = false ;
        box_data_for_this_experiment = [] ;        
        return
    end    
    
%     % Extract the temperature, to add to the box_data structure
%     temperature_as_string = temperature_suffix(2:end) ;
%     temperature = str2double(temperature_as_string) ;
%     if ~isfinite(temperature),
%         error('Unable to determine temperature for experiment %s', experiment_name) ;
%     end
    
    % save metadata
    box_data_for_this_experiment = struct() ;
    box_data_for_this_experiment.genotype = exp_detail.tube_info(1).Genotype ;
    box_data_for_this_experiment.line_name = exp_detail.tube_info(1).Line ;
    box_data_for_this_experiment.effector = exp_detail.tube_info(1).Effector ;
    box_data_for_this_experiment.boxname = BoxName ;
    box_data_for_this_experiment.experiment_name = experiment_name ;
    box_data_for_this_experiment.path = fullfile(box_data_folder_path, experiment_name) ;
    box_data_for_this_experiment.merge_output_path = fullfile(box_data_merge_output_folder_path, experiment_name) ;
    box_data_for_this_experiment.analysis_output_path = fullfile(box_data_analysis_output_folder_path, experiment_name) ;
    box_data_for_this_experiment.date_time = exp_detail.date_time ;
    box_data_for_this_experiment.action_sources = action_sources ;
    box_data_for_this_experiment.protocol = protocol ;
    box_data_for_this_experiment.temperatures = temperatures ;

%     if ismember(box_data_for_this_experiment.line_name, split_control_genotypes)
%         box_data_for_this_experiment.type = 'split_control';
%     elseif ismember(box_data_for_this_experiment.line_name, gal4_control_genotypes)
%         box_data_for_this_experiment.type = 'gal4_control';
%     else
%         box_data_for_this_experiment.type = 'unknown';        
%     end

    % save results for comparison plots
    %cd(fullfile(box_data_for_this_experiment.path, output_folder))
    file_name_template = fullfile(box_data_for_this_experiment.analysis_output_path, output_folder_name, '*analysis_results.mat') ;
    analysis_results_mat_file_names = simple_dir(file_name_template) ;
    %ar_names = {ar(:).name} ;


    % Typically, there's Phase 1 (01_5.34_34) and Phase 2 (01_5.34_34)
    % seq1-seq4 are in Phase 1, and seq5-seq8 are in Phase 2.
    % See prot_534_analysis.m for more info about what each sequence is.
    for phase_index = 1:length(analysis_results_mat_file_names) ,
        analysis_results_mat_file_name = analysis_results_mat_file_names{phase_index} ;
        analysis_results_mat_file_path = fullfile(box_data_for_this_experiment.analysis_output_path, output_folder_name, analysis_results_mat_file_name) ;
        analysis_results_from_seq_name_from_tube_index = load_anonymous(analysis_results_mat_file_path) ;
        field_names = fieldnames(analysis_results_from_seq_name_from_tube_index) ;
        does_field_name_have_seq_in_it = cellfun(@(indices)(~isempty(indices)), strfind(field_names, 'seq')) ;
        seq_names = field_names(does_field_name_have_seq_in_it) ;
        seq_count = length(seq_names) ;
        nominal_tube_count = 6 ;
        %tube_index_per_seq_tube_pair = zeros(seq_count,tube_count) ;
        %tube_indices_with_enough_flies_per_seq = cell(seq_count, 1) ;
        does_seq_tube_pair_have_enough_flies = false(seq_count, nominal_tube_count) ;

        for seq_index = 1:seq_count ,
            this_seq_name = seq_names{seq_index} ;
            %tube_indices_with_enough_flies = zeros(1, 0) ;
            for tube_index = 1:nominal_tube_count ,
                % check to see if tubes are empty
                analysis_results = analysis_results_from_seq_name_from_tube_index(tube_index).(this_seq_name) ;
                if analysis_results.max_tracked_num >= minimum_fly_count ,
                    % if there are enough flies, store data
                    does_seq_tube_pair_have_enough_flies(seq_index, tube_index) = true ;
                    %tube_index_per_seq_tube_pair(seq_index,tube_index) = tube_index;
                    %tube_indices_with_enough_flies = horzcat(tube_indices_with_enough_flies, tube_index) ;  %#ok<AGROW>
                    if isfield(analysis_results,'mean_dir_index')
                        box_data_for_this_experiment.analysis_results(tube_index).(this_seq_name).mean_dir_index = ...
                            analysis_results.mean_dir_index;
                    end
                    if isfield(analysis_results,'cum_dir_index_max')
                        box_data_for_this_experiment.analysis_results(tube_index).(this_seq_name).cum_dir_index_max = ...
                            analysis_results.cum_dir_index_max;
                    end
                    if isfield(analysis_results,'cum_dir_index_peak')
                        box_data_for_this_experiment.analysis_results(tube_index).(this_seq_name).cum_dir_index_peak = ...
                            analysis_results.cum_dir_index_peak;
                    end
                end
            end
            %tube_indices_with_enough_flies_per_seq{seq_index} = tube_indices_with_enough_flies ;
        end
        
        % Populate the field that says which tubes have enough flies in all seqs
        does_tube_have_enough_flies_in_all_seqs = all(does_seq_tube_pair_have_enough_flies, 1) ;
        tube_indices_with_enough_flies_in_all_seqs = find(does_tube_have_enough_flies_in_all_seqs) ;
        box_data_for_this_experiment.tubes = tube_indices_with_enough_flies_in_all_seqs ;
          % In saving only which tubes have enough flies for the *last* phase, I think
          % there's an assumption here that the empty tubes will be same for all phases.
          % Which I suppose is usually the case.  --ALT, 2022-05-24
    end                    

end  % function
