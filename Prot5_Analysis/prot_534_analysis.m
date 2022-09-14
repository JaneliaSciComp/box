function exp_detail = prot_534_analysis(exp_directory, save_plots, protocol_folder_name, temp, phase, AD, protocol, analysis_version, ...
                                        exp_merge_output_directory, exp_analysis_output_directory)
% analysis for protocols 3.1 and 4.1

close all

%% step 1: find the experiment_details file
if all(exp_directory == -1)
    directory_name = uigetdir;
    if (directory_name ~= 0)
        %cd(directory_name)
        exp_directory = directory_name;
    else
        error('program terminated, must select a directory name');
    end
else
    %cd(exp_directory)
end
exp_file_names = simple_dir(fullfile(exp_directory, '*.exp')) ; % grab local experiment file

if length(exp_file_names) ~= 1 ,
    error('.exp file not found (or found too many), check file name or directory!');
end

exp_file_name = exp_file_names{1} ;
exp_file_path = fullfile(exp_directory, exp_file_name) ;
load(exp_file_path, '-mat') ;  % load the experiment file

% CD to the directory of the experiment (typically one of the two
% temperatures
% try
%     cd([exp_directory filesep protocol_folder_name])
% catch
%     error('The directory for the data path is incorrect, check filesystem')
% end
protocol_folder_path = fullfile(exp_directory, protocol_folder_name) ;
if ~exist(protocol_folder_path, 'dir') ,
    error('The protocol folder, expected to be at %s, does not exist', protocol_folder_path) ;
end

m_file_template = fullfile(protocol_folder_path, '*.m') ;
m_file_names = simple_dir(m_file_template) ;

cnt = 0; % counter for error checking
for j = 1:length(m_file_names)
    %cur_dir(j).name %just debug
    m_file_name = m_file_names{j} ;
    m_file_path = fullfile(protocol_folder_path, m_file_name) ;
    if (strcmp(m_file_name(1:16), 'sequence_details'))
        try 
            fid = fopen(m_file_path);
            script = fread(fid, '*char')';
            fclose(fid);
            eval(script);
            
            % compensate for unwise choice of the analysis detail path info so
            % update after the eval is run...
            analysis_detail = AD;        
            analysis_detail.exp_path = [exp_directory AD.analysis_path]; % test this...do we need anything else?
            analysis_detail.exp_merge_output_path = [exp_merge_output_directory AD.analysis_path]; % test this...do we need anything else?
            analysis_detail.exp_analysis_output_path = [exp_analysis_output_directory AD.analysis_path]; % test this...do we need anything else?
        catch exception
            fprintf(['Error: sequence details file ' m_file_name ' does not load or is missing crucial info.'])            
            rethrow(exception)
        end
        cnt = cnt + 1;
    end
end

if cnt == 0
    error('No sequence_details*.m file found in folder %s', protocol_folder_path);
elseif cnt > 1
    error('More than one sequence_details*.m files found in folder %s', protocol_folder_path);
end


for j = 1: length(m_file_names)
    m_file_name = m_file_names{j} ;
    if length(m_file_name) > 5
        if (strcmp(m_file_name(end-2:end), 'pdf'))
            delete(m_file_name)
        end
    end
end
    


%cd([analysis_detail.exp_path]) 


if phase == 1,
    
    %% analysis for seq1, vibrations
    sequence = 'seq1';

    min_num_flies = 2; %10; minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    pulse_times = [125 375 625 875 1125]; %frames at which the stimulus begins
    stim_length = 0;
    trial_length = 250;
    ma_points = 4; % number of points to use in ma smoothing of the velocity plot

    try
        file_name = fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(1).path '_analysis_info.mat']) ;
        analysis_info_tube = load_anonymous(file_name) ;
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    buzz_stimulus_analysis(pulse_times, analysis_info_tube, sequence, ...
                           min_num_flies, ...
                           del_t, ...
                           trial_length, ...
                           ma_points, ...
                           exp_detail, ...
                           save_plots, ...
                           analysis_detail, ...
                           protocol_folder_name) ;    
    
    %% now seq2, phototaxis: median_velocity_x, preference index, and displacement
    sequence = 'seq2';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125 875 1625 2375];
    dir2_starts = [500 1250 2000 2750];
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    X_label = {'G = 20', 'G = 120', 'UV = 15', 'UV = 200'};
    X_label_short = {'GL', 'GH', 'UL', 'UH'};
    tube_length = 112.55; %length of tube in mm
    
    try
        %load([analysis_detail.seq(2).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(2).path '_analysis_info.mat'])) ;
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    phototaxis_analysis;

    %% now seq3, UV constant, median_velocity_x and preference index
    sequence = 'seq3';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
    dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    X_label = [0 3 10 20 30 50 100 200 200 100 50 30 20 10 3 0];
    tube_length = 112.55; %length of tube in mm
    pref_index = [1 2 7 8]; % indices to use for preference index
    X_variable = 'Green Intensity';
    main_title = 'Color Preference with Constant UV, Variable Green Intensities';
    
    try
        %load([analysis_detail.seq(3).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(3).path '_analysis_info.mat'])) ;
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    color_preference_with_repeats_analysis;

    %% now seq4, green constant, median_velocity_x and preference index
    sequence = 'seq4';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125 625 1125 1625 2125 2625 3125 3625 4125 4625 5125 5625 6125 6625 7125 7625]; 
    dir2_starts = [375 875 1375 1875 2375 2875 3375 3875 4375 4875 5375 5875 6375 6875 7375 7875];
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    X_label = [0 5 10 15 25 50 100 200 200 100 50 25 15 10 5 0];
    tube_length = 112.55; %length of tube in mm
    pref_index = [1 2 7 8]; % indices to use for preference index
    X_variable = 'UV Intensity';
    main_title = 'Color Preference with Constant Green, Variable UV Intensities';
    
    try
        %load([analysis_detail.seq(4).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(4).path '_analysis_info.mat'])) ;
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    color_preference_with_repeats_analysis;

    
    
end

%cd([analysis_detail.exp_path]) 

if phase == 2
    %% seq5, Linear Motion Analysis
    sequence = 'seq5';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625,5125,5625,6125,6625];
    dir2_starts = [375,875,1375,1875,2375,2875,3375,3875,4375,4875,5375,5875,6375,6875];
    trial_length = 250;
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    plot_conditions = [0 0.67 2 5 10 20 42 42 20 10 5 2 0.67 0]; %stimulus speeds
    x_variable = 'Temporal Freqency';
    main_title = 'Optomotor Response';
    
    try
        %load([analysis_detail.seq(5).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(5).path '_analysis_info.mat'])) ;        
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    linear_motion_analysis;

    %% seq6, contrast series w. same average intensity

    sequence = 'seq6';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625];
    dir2_starts = [375,875,1375,1875,2375,2875,3375,3875,4375,4875];
    trial_length = 100;
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    plot_conditions = [0.07, 0.2, 0.5, 0.7, 1, 1, 0.7, 0.5, 0.2, 0.07]; %stimulus speeds
    x_variable = 'Contrast';
    main_title = 'Contrast with Constant Average Intensity';

    try
        %load([analysis_detail.seq(6).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(6).path '_analysis_info.mat'])) ;        
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    linear_motion_analysis;

    %% seq7, contrast series w. increasing intensity

    sequence = 'seq7';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625];
    dir2_starts = [375,875,1375,1875,2375,2875,3375,3875,4375,4875];
    trial_length = 100;
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    plot_conditions = [0.1, 0.3, 0.4, 0.7, 1, 1, 0.7, 0.4, 0.2, 0.1]; %stimulus speeds
    x_variable = 'Contrast';
    main_title = 'Contrast with Increasing Average Intensity';

    try
        %load([analysis_detail.seq(7).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(7).path '_analysis_info.mat'])) ;        
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    linear_motion_analysis;

    %% seq8, spatial tuning

    sequence = 'seq8';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125,625,1125,1625,2125,2625,3125,3625,4125,4625, 5125, 5625, 6125, 6625];
    dir2_starts = [375,875,1375,1875,2375,2875,3375,3875,4375,4875, 5375, 5875, 6375, 6875];
    trial_length = 250;
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    plot_conditions = [3, 4, 6, 8, 12, 16, 32, 32, 16, 12, 8, 6, 4, 3]; %stimulus speeds
    x_variable = 'Pixels per cycle';
    main_title = 'Spatial Tuning';

    try
        %load([analysis_detail.seq(8).path '_analysis_info.mat'])
        load(fullfile(analysis_detail.exp_merge_output_path, [analysis_detail.seq(8).path '_analysis_info.mat'])) ;        
    catch
        error(['No analysis_info in directory ' analysis_detail.exp_merge_output_path ' bad name or analysis not run'])
    end
    linear_motion_analysis;

end

%% now save all of the data:
analysis_results(phase).analysis_version = analysis_version;
analysis_results(phase).BoxName = BoxName;
analysis_results(phase).TopPlateID = TopPlateID;

analysis_results_file_name = [analysis_detail.exp_analysis_output_path filesep protocol_folder_name '_analysis_results.mat'] ;
save(analysis_results_file_name, 'analysis_results') ;

end
