function batch_analysis(test_experiment_date_or_test_experiment_name_list, ...
                        control_type_string, ...
                        minimum_fly_count, ...
                        output_folder_name, ...
                        do_comparisons_only, ...
                        do_force, ...
                        flyvisionbox_folder_path, ...
                        minimum_tube_count)
    % BATCH_ANALYSIS Run the fly vision box analysis.  
    % 
    %   BATCH_ANALYSIS(test_experiment_date) 
    %       Runs the analysis for the experiment indicated by test_experiment_date.
    %       test_experiment_date should be a string of the form yyyymmdd, e.g.
    %       '20170810'.
    %
    %   BATCH_ANALYSIS(test_experiment_name_list) 
    %       Runs the analysis for all of the experiments indicated by
    %       test_experiment_name_list, a cell array of strings.  Each experiment
    %       name should be the name of a folder in the boxdata folder. E.g.
    %       {'pBDPGAL4U_shi_Apollo_20160610T102049',
    %       'pBDPGAL4U_shi_Orion_20160610T090339'}.
    %
    %   BATCH_ANALYSIS(test_experiment_date, control_type_string)
    %       Runs the analysis for the given date, using either split or gal4
    %       controls.  control_type_string should either be the string 'split'
    %       or 'gal4'.  If unspecified or empty, the default is 'split'.  This
    %       form (and all forms below) can also be used with a test experiment name
    %       list as the first argument.
    %
    %   BATCH_ANALYSIS(test_experiment_date, control_type_string, minimum_fly_count)
    %       Runs the analysis for the given date, using minimum_fly_count as
    %       the minimum number of flies required for a tube to be considered
    %       valid and included in the analysis.  If unspecified or empty,
    %       minimum_fly_count defaults to 11.
    %
    %   BATCH_ANALYSIS(test_experiment_date, control_type_string, minimum_fly_count, output_folder_name)
    %       Runs the analysis for the given date, using the specified type of
    %       control, etc, and stores the output files in the folder named
    %       output_folder_name in the experiment folder.  If unspecified or
    %       empty, output_folder_name defaults to 'Output_1.1_1.7' for
    %       historical reasons.
    %
    %   BATCH_ANALYSIS(test_experiment_date, control_type_string, minimum_fly_count, output_folder_name, do_comparisons_only)
    %       Runs the analysis, etc.  If do_comparisons_only is true, all of the
    %       analysis except the comparisons will be skipped.  If
    %       do_comparisons_only is false, the full analysis will be done.  If
    %       unspecified or empty, do_comparisons_only defaults to false.
    %
    %   BATCH_ANALYSIS(test_experiment_date, control_type_string, minimum_fly_count, output_folder_name, do_comparisons_only, do_force)
    %       Runs the analysis, etc.  If do_force is true, the specified
    %       experiments are overwritten in the BoxData.mat file, even if they
    %       were present already.  If unspecified or empty, do_force defaults
    %       to false.  If do_comparisons_only is true, then do_force is
    %       ignrored.
    
    % Deal with optional arguments
    if ~exist('test_experiment_date_or_test_experiment_name_list', 'var') || isempty(test_experiment_date_or_test_experiment_name_list) ,
        error(horzcat('The first argument to batch_analysis() must be a date string of the form ''20170810'', ', ...
                      'or a cell array of strings holding folder names like ', ...
                      '{''pBDPGAL4U_shi_Apollo_20160610T102049'' ''pBDPGAL4U_shi_Orion_20160610T090339''}')) ;        
    end
    if ~exist('control_type_string', 'var') || isempty(control_type_string) ,
        control_type_string = 'split' ;
    end
    if ~exist('minimum_fly_count', 'var') || isempty(minimum_fly_count) ,
        minimum_fly_count = 11 ;
    end
    if ~exist('output_folder_name', 'var') || isempty(output_folder_name) ,
        output_folder_name = 'Output_1.1_1.7' ;
    end
    if ~exist('do_comparisons_only', 'var') || isempty(do_comparisons_only) ,
        do_comparisons_only = false ;
    end
    if ~exist('do_force', 'var') || isempty(do_force) ,
        do_force = false ;
    end
    if ~exist('flyvisionbox_folder_path', 'var') || isempty(flyvisionbox_folder_path) ,
        was_flyvisionbox_folder_path_specified = false ;
        flyvisionbox_folder_path = '' ;
    else
        was_flyvisionbox_folder_path_specified = true ;        
    end
    if ~exist('minimum_tube_count', 'var') || isempty(minimum_tube_count) ,
        minimum_tube_count = 3 ;
    end
    
    % Sort out the location fo the flyvisionbox folder
    if ~was_flyvisionbox_folder_path_specified ,
        if ismac() ,
            %         [retcode, hostname] = system('echo $HOSTNAME') ;
            %         if retcode==0 && isequal(strtrim(hostname), 'orange.hhmi.org') ,
            %             % Special case for debugging on Adam's computer
            %             flyvisionbox_folder_path = '/Volumes/taylora/ptr/flyvisionbox/fake-flyvisionbox-2018-06-01' ;
            %             %flyvisionbox_folder_path = '/Volumes/taylora/ptr/flyvisionbox/fake-flyvisionbox-2018-04-27' ;
            %             fprintf('Using %s as the root flyvisionbox folder\n', flyvisionbox_folder_path) ;
            %         else
            % Normal case
            flyvisionbox_folder_path = '/Volumes/flyvisionbox' ;
            %         end
        elseif ispc() ,
            %flyvisionbox_folder_path = 'V:' ;  % should be mapped to //dm11.hhmi.org/flyvisionbox
            flyvisionbox_folder_path = '//dm11.hhmi.org/flyvisionbox' ;
            %flyvisionbox_folder_path = 'E:/fake-box-data-2' ;
            %flyvisionbox_folder_path = 'E:/fake-box-data-2' ;
        else
            % Assume linux box, with typical Janelia filesystem organization
            flyvisionbox_folder_path = '/groups/reiser/flyvisionbox' ;
        end
    end
    
    box_data_folder_path = fullfile(flyvisionbox_folder_path, 'box_data') ;
    %addpath(box_data_folder_path)  % groan
    %box_data_merge_output_folder_path = fullfile(flyvisionbox_folder_path, 'box_data_merge_output') ;
    %box_data_analysis_output_folder_path = fullfile(flyvisionbox_folder_path, 'box_data_analysis_output') ;
    box_data_merge_output_folder_path = box_data_folder_path ;
    box_data_analysis_output_folder_path = box_data_folder_path ;

    %rootdir = '/Volumes/flyvisionbox/box_data/';
    %outdir = 'Output_1.1_1.7';
    %experimentdate = '20170810';

    %cd(box_data_folder_path);
    if iscell(test_experiment_date_or_test_experiment_name_list) ,
        test_experiment_names = test_experiment_date_or_test_experiment_name_list ;
    else
        test_experiment_date = test_experiment_date_or_test_experiment_name_list ;
        file_name_template = sprintf('*%s*', test_experiment_date) ;
        raw_folder_names = dir(fullfile(box_data_folder_path, file_name_template)) ;
        test_experiment_names = {raw_folder_names.name} ;
    end
    
    % Add the directory name to each file name to get an absolute path for each
%     box_data_folder_paths = ...
%         cellfun(@(folder_name)(fullfile(box_data_folder_path, folder_name)), experiment_names, 'UniformOutput', false) ;
%     box_data_merge_output_folder_paths = ...
%         cellfun(@(folder_name)(fullfile(box_data_merge_output_folder_path, folder_name)), experiment_names, 'UniformOutput', false) ;
%     box_data_analysis_output_folder_paths = ...
%         cellfun(@(folder_name)(fullfile(box_data_analysis_output_folder_path, folder_name)), experiment_names, 'UniformOutput', false) ;
    
    %If controls different from morning vs evening box, do the following
    %instead:
    % filelist = {'pBDPGAL4U_shi_Apollo_20160610T102049',...
    % 'pBDPGAL4U_shi_Orion_20160610T090339',...
    % 'tdc_GAL4_shi_Apollo_20160610T094652',...
    % 'VT019749_shi_Orion_20160610T102039',...
    % 'VT046828_shi_Orion_20160610T094630',...
    % 'pBDPGAL4U_shi_Apollo_20160603T090820',...
    % 'pBDPGAL4U_shi_Orion_20160603T102743',...
    % 'VT019749_shi_Orion_20160603T090902',...
    % 'VT046828_shi_Orion_20160603T094902',...
    % 'VT034810_shi_Apollo_20160603T102721',...
    % 'VT049105_shi_Apollo_20160603T094838'};

    %load ('/Volumes/flyvisionbox/BoxData.mat');
    
    box_data_mat_path = fullfile(flyvisionbox_folder_path, 'BoxData.mat') ;
    
    if ~do_comparisons_only ,
        for i=1:length(test_experiment_names) ,
            test_experiment_name = test_experiment_names{i} ;            
            experiment_folder_path = fullfile(box_data_folder_path, test_experiment_name) ;
            merge_output_folder_path = fullfile(box_data_merge_output_folder_path, test_experiment_name, output_folder_name) ;
            merge_tracking_output(experiment_folder_path, output_folder_name, merge_output_folder_path) ;
        end

        for i=1:length(test_experiment_names) ,
            test_experiment_name = test_experiment_names{i} ;
            this_box_data_merge_output_folder_path = fullfile(box_data_merge_output_folder_path, test_experiment_name) ;
            this_box_data_analysis_output_folder_path = fullfile(box_data_analysis_output_folder_path, test_experiment_name) ;
            box_analysis(box_data_folder_path, ...
                         test_experiment_name, ...
                         output_folder_name, ...
                         [], ...
                         [], ...
                         this_box_data_merge_output_folder_path, ...
                         this_box_data_analysis_output_folder_path) ;
        end
        if do_force ,
            experiment_names_to_force = test_experiment_names ;
        else
            experiment_names_to_force = cell(1, 0) ;
        end
        update_boxdata_mat_file(box_data_mat_path, ...
                                box_data_folder_path, ...
                                box_data_merge_output_folder_path, ...
                                box_data_analysis_output_folder_path, ...
                                minimum_fly_count, ...
                                minimum_tube_count, ...
                                experiment_names_to_force) ;
    end
    
    BoxData = load_anonymous(box_data_mat_path) ;

    % Make the comparison plots, one per test experiment
    plot_mode = 1 ;
    do_save_plot = true ;
    pdf_name = 'comparison_summary' ;
    for i=1:length(test_experiment_names) ,
        test_experiment_name = test_experiment_names{i} ;
        prot_534_comparison_summary(BoxData, ...
                                    control_type_string, ...
                                    test_experiment_name, ...
                                    plot_mode, ...
                                    do_save_plot, ...
                                    pdf_name) ;
    end    
end
