function prot_534_comparison_summary(BoxData, ...
                                     desired_control_experiment_names_or_control_type_string, ...
                                     desired_test_experiment_name_or_names, ...
                                     plot_mode, ...
                                     saveplot, ...
                                     pdfname, ...
                                     savepath, ...
                                     colors)

    % In typical usage, makes a single figure per experiment specified in
    % test_experiment_name_or_names, with 'historical' control data pulled from
    % BoxData for comparison.  But in some cases can also be used to just plot
    % the control data.  And maybe also just the test data?
    %
    % author: Austin Edwards
    % 
    % input:
    %       exp_group1 - cell array of strings containing paths to experiments
    %                    in group 1
    %       exp_group2 - cell array of strings containing paths to experiments
    %                    in group 2 (-1 if no experiments in group 2)
    %       analysis_feature - string of feature to plot
    %       plot_mode: 1 - mean + standard deviation
    %                  2 - individual experiments
    %                  3 - individual experiments + mean of tubes for each experiment
    %       save_plot

    protocol = '5.34';

    if ~exist('saveplot', 'var') || isempty(saveplot) ,
        saveplot = 1;
    end

    if ~exist('colors', 'var') || isempty(colors) ,
        colors = {'k','r'};
    end

    % Extract test experiment data
    if ischar(desired_test_experiment_name_or_names) ,
        desired_test_experiment_name = desired_test_experiment_name_or_names ;
        desired_test_experiment_names = { desired_test_experiment_name } ;
    else
        desired_test_experiment_names = desired_test_experiment_name_or_names ;
    end
    experiment_names = {BoxData.experiment_name} ;
    is_test_experiment = ismember(experiment_names, desired_test_experiment_names) ;  % same size as experiment_names
    data_for_test_experiments = BoxData(is_test_experiment) ;
    test_experiment_count = length(data_for_test_experiments);
%    test_experiment_names = experiment_names(is_test_experiment) ;
    
%     % Print the test experiment names
%     fprintf('Test experiment names:\n') ;
%     if test_experiment_count == 0 ,
%         fprintf('  (none)\n') ;
%     else
%         cellfun(@(name)(fprintf('  %s\n', name)), test_experiment_names) ;
%     end
    
    % If the user specified a nonzero number of test experiments, but none of
    % the then are in BoxData, return early without making a figure.
    % If the user actually specified zero test experiments, that's a different
    % story: That means they want to just plot some controls.
    if length(desired_test_experiment_names)>0 && test_experiment_count==0 ,  %#ok<ISMT>
        fprintf('No data in BoxData for the following experiments, so prot_534_comparison_summary() is exiting early:\n') ;
        for i = 1 : length(desired_test_experiment_names) ,
            fprintf('    %s\n', desired_test_experiment_names{i}) ;
        end
        return
    end

    % Determine control experiment names
    if ischar(desired_control_experiment_names_or_control_type_string) ,
        desired_control_type_string = desired_control_experiment_names_or_control_type_string ;
        if isequal(desired_control_type_string, 'none') ,        
            desired_control_experiment_names = cell(1,0) ;
        else
            % the usual case: control_type_string is either 'gal4' or
            % 'split'
            if test_experiment_count == 0 ,
                error(['If control_experiment_names_or_control_type_string specifies a control_type_string, ' ...
                       'need at least one test experiment to determine the effector']) ;
            end

            test_effectors = {data_for_test_experiments.effector} ;  % a cell array of strings
            if are_all_equal(test_effectors) ,
                test_effector = test_effectors{1} ;
            else
                error('All test effectors are not equal, so no way to pick controls')
            end

            test_temperatureses = { data_for_test_experiments.temperatures } ;  % a cell array of 1x2 double vectors, usually
            if are_all_equal(test_temperatureses) ,
                test_temperatures = test_temperatureses{1} ;
            else
                error('All test temperature arrays are not equal, so no way to pick controls')
            end

            test_action_sourceses = { data_for_test_experiments.action_sources } ;  % a cell array of 1x2 double vectors, usually
            if are_all_equal(test_action_sourceses) ,
                test_action_sources = test_action_sourceses{1} ;
            else
                error('All test action source arrays are not equal, so no way to pick controls')
            end

            if isequal(desired_control_type_string, 'gal4') ,
                control_line_names = {'pBDP_GAL4', 'pBDPGAL4U'} ; 
            elseif isequal(desired_control_type_string, 'split') ,
                control_line_names = {'JHS_K_85321', 'JHS_K_85321_10'} ;
                %'GMR_SS00200',...
                %                     'GMR_SS00205', ...
                %                     'Dickson',...
                %                     'GMR_SS00194',...
                %                     'GMR_SS00179',...
                %                     'CantonS',...                
            else
                error('Unknown control type: %s', desired_control_type_string) ;
            end
                
            %full_control_type_string = sprintf('%s_control', control_type_string) ;
            is_control = @(bd1)(ismember(bd1.line_name, control_line_names) && ...
                                isequal(bd1.protocol, protocol) && ...
                                isequal(bd1.effector, test_effector) && ...
                                isequal(bd1.temperatures, test_temperatures) && ...
                                isequal(bd1.action_sources, test_action_sources)) ;
            is_control_experiment = arrayfun(is_control, BoxData) ;
            desired_control_experiment_names = experiment_names(is_control_experiment) ;
        end
    else
        desired_control_experiment_names = desired_control_experiment_names_or_control_type_string ;
    end
    
    % Extract control data
    is_control_from_experiment_index = ismember(experiment_names, desired_control_experiment_names) ;
    control_experiment_names = experiment_names(is_control_from_experiment_index) ;
    data_for_control_experiments = BoxData(is_control_from_experiment_index) ;
    control_experiment_count = length(data_for_control_experiments) ;

    % Print the control experiment names
    fprintf('Control experiment names:\n') ;
    if control_experiment_count == 0 ,
        fprintf('  (none)\n') ;
    else
        cellfun(@(name)(fprintf('  %s\n', name)), control_experiment_names) ;
    end
    
    if plot_mode == 2 && (~isempty(desired_test_experiment_names) || control_experiment_count > 1)
        error('Cannot plot individual tubes for more than one experiment') ;
    end

    close all

    fig = figure('Color', 'w') ;
    set(fig, 'Units', 'Points') ;
    set(fig, 'Position', [30 55 1500 1500]);
    subplot_count = 1;

    %phase = 1;

    % Seq 2 : Phototaxis
    seq = 'seq2';
    %min_num_flies = 2; % minimum number of flies in tubes
    %del_t = 1/25; %inverse frames per second
    dir1_starts = [125 875 1625 2375];
    %dir2_starts = [500 1250 2000 2750];
    %ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    %plot_conditions = {'G = 20', 'G = 120', 'UV = 15', 'UV = 200'};
    %X_label_short = {'GL', 'GH', 'UL', 'UH'};
    %tube_length = 112.55; %length of tube in mm

    num_conditions = length(dir1_starts);
    analysis_feature = 'cum_dir_index_max';

    phototaxis_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        num_conditions, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors);
    subplot_count = subplot_count + 1;

    % Seq 3 : Color Preference

    seq = 'seq3';
    %min_num_flies = 2; % minimum number of flies in tubes
    %del_t = 1/25; %inverse frames per second
    dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
    %dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
    plot_conditions = [0 3 10 20 30 50 100 200 200 100 50 30 20 10 3 0];
    x_variable = 'Green Intensity';
    %y_variable = 'cum_dir_index_peak';
    sequence_title = 'Color Preference, UV Constant';

    num_conditions = length(dir1_starts);
    half_num_conditions = num_conditions/2;
    analysis_feature = 'cum_dir_index_peak';
    y_lim_DI = 1;
    y_lim_cum_DI = 4*y_lim_DI;

    color_preference_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        y_lim_cum_DI, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions);
    subplot_count = subplot_count + 1;

    % Seq 4

    seq = 'seq4';
    %min_num_flies = 2; % minimum number of flies in tubes
    %del_t = 1/25; %inverse frames per second
    dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
    %dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
    plot_conditions = [0 5 10 15 25 50 100 200 200 100 50 25 15 10 5 0];
    x_variable = 'UV Intensity';
    %y_variable = 'cum_dir_index_peak';
    sequence_title = 'Color Preference, Green Constant';

    num_conditions = length(dir1_starts);
    half_num_conditions = num_conditions/2;
    analysis_feature = 'cum_dir_index_peak';
    y_lim_DI = 1;
    y_lim_cum_DI = 4*y_lim_DI;

    color_preference_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        y_lim_cum_DI, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions);
    subplot_count = subplot_count + 1;


    %phase = 2;

    analysis_feature = 'mean_dir_index';
    seq = 'seq5';

    plot_conditions = [0 0.67 2 5 10 20 42 42 20 10 5 2 0.67 0]; %stimulus speeds
    x_variable = 'Temporal Frequency (Hz)';
    %y_variable = 'Direction Index';
    sequence_title = 'Optomotor (Temporal Tuning)';
    num_conditions = length(plot_conditions);
    half_num_conditions = num_conditions/2;
    y_lim = 1;
    n_y_lim = -0.2;

    linear_motion_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions, ...
        n_y_lim, ...
        y_lim);
    subplot_count = subplot_count + 1;

    % Seq 3 : Contrast

    seq = 'seq6';

    plot_conditions = [0.07, 0.2, 0.5, 0.7, 1, 1, 0.7, 0.5, 0.2, 0.07]; %stimulus speeds
    x_variable = 'Contrast';
    %y_variable = 'Direction Index';
    sequence_title = 'Contrast (Constant Intensity)';
    num_conditions = length(plot_conditions);
    half_num_conditions = num_conditions/2;
    y_lim = 1;
    n_y_lim = -0.2;

    linear_motion_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions, ...
        n_y_lim, ...
        y_lim);
    subplot_count = subplot_count + 1;

    % Seq 4 : Contrast

    seq = 'seq7';

    plot_conditions = [0.1, 0.3, 0.4, 0.7, 1, 1, 0.7, 0.4, 0.2, 0.1]; %stimulus speeds
    x_variable = 'Contrast';
    %y_variable = 'Direction Index';
    sequence_title = 'Contrast (Increasing Intensity)';
    num_conditions = length(plot_conditions);
    half_num_conditions = num_conditions/2;
    y_lim = 1;
    n_y_lim = -0.2;

    linear_motion_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions, ...
        n_y_lim, ...
        y_lim);
    subplot_count = subplot_count + 1;

    % Seq 5 : Spatial

    seq = 'seq8';

    plot_conditions = [3, 4, 6, 8, 12, 16, 32, 32, 16, 12, 8, 6, 4, 3]; %stimulus speeds
    x_variable = 'Pixels per Cycle';
    %y_variable = 'Direction Index';
    sequence_title = 'Optomotor (Spatial Tuning)';
    num_conditions = length(plot_conditions);
    half_num_conditions = num_conditions/2;
    y_lim = 1;
    n_y_lim = -0.2;

    linear_motion_comparison(...
        data_for_control_experiments, ...
        data_for_test_experiments, ...
        seq, ...
        analysis_feature, ...
        subplot_count, ...
        plot_mode, ...
        colors, ...
        half_num_conditions, ...
        x_variable, ...
        sequence_title, ...
        plot_conditions, ...
        n_y_lim, ...
        y_lim);
    %subplot_count = subplot_count + 1;


    if plot_mode == 1,
        if ~isempty(data_for_test_experiments) ,
            genotype = data_for_test_experiments.genotype ;
            date_time = data_for_test_experiments.date_time ;
        else
            genotype = data_for_control_experiments.genotype ;
            date_time = data_for_control_experiments.date_time ;
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
        if ~isempty(desired_control_experiment_names) , 
            text(17, 0.30, ...
                'controls', ...
                'HorizontalAlignment', 'right', ...
                'Interpreter', 'none', ...
                'FontSize', 14, ...
                'Color', colors{1}, ...
                'BackgroundColor',[1 1 1]) ;
        end
    end

    if plot_mode == 2,
        if isempty(data_for_test_experiments) ,
            genotype = data_for_control_experiments.genotype;
            date_time = data_for_control_experiments.date_time;
        else
            genotype = data_for_test_experiments.genotype;
            date_time = data_for_test_experiments.date_time;
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

        for i = 1:test_experiment_count ,

            genotype = data_for_test_experiments(i).genotype;
            date_time = data_for_test_experiments(i).date_time;

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
        if ~isempty(desired_control_experiment_names) ,         
            text(17, 0.30, ... 
                    'controls', ...
                    'HorizontalAlignment', 'right', ...
                    'Interpreter', 'none', ...
                    'FontSize', 14, ...
                    'Color', 'k', ...
                    'BackgroundColor',[1 1 1])
        end
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

    if saveplot == 1 ,
        if plot_mode == 3 ,
            save2pdf([savepath pdfname '.pdf']) ;
        else
            path = data_for_test_experiments.analysis_output_path ;
            if ismac() ,
                path = strrep(path,'\','/');
                path = strrep(path,'//tier2.hhmi.org/','/Volumes/');
                path = strrep(path, 'X:', '/Volumes/flyvisionbox') ;
                path = strrep(path,'/groups/reiser/flyvisionbox','/Volumes/flyvisionbox');
            elseif ispc(),
                path = strrep(path,'/','\');
                path = strrep(path,'\Volumes\','\\tier2.hhmi.org\');
            else
                % linux, presumably
                path = strrep(path,'\','/');
                path = strrep(path,'/Volumes/flyvisionbox','/groups/reiser/flyvisionbox');
                path = strrep(path,'//dm11.hhmi.org/flyvisionbox','/groups/reiser/flyvisionbox');
                path = strrep(path, 'X:', '/groups/reiser/flyvisionbox') ;
            end
            save2pdf(fullfile(path, 'Output_1.1_1.7', [pdfname, '.pdf']));
        end
    end
end
