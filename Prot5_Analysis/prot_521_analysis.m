function exp_detail = prot_521_analysis(exp_directory, save_plots, folder_path, temp, phase, AD, protocol, analysis_version)
% analysis for protocols 3.1 and 4.1

close all

%% step 1: find the experiment_details file
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
cur_dir = dir('*.exp'); % grab local experiment file

if length(cur_dir) ~= 1
    error('EXP file not found (or found too many), check file name or directory!');
end

load(cur_dir.name, '-mat') % load the experiment file

% CD to the directory of the experiment (typically one of the two
% temperatures
try
    cd([exp_directory filesep folder_path])
catch
    error('The directory for the data path is incorrect, check filesystem')
end

cur_dir = dir('*.m');


cnt = 0; % counter for error checking
for j = 1:length(cur_dir)
    %cur_dir(j).name %just debug
    if (strcmp(cur_dir(j).name(1:16), 'sequence_details'))
        try 
            fid = fopen([cur_dir(j).name(1:end-2) '.m']);
            script = fread(fid, '*char')';
            fclose(fid);
            eval(script);
            
            % compensate for unwise choice of the analysis detail path info so
            % update after the eval is run...
            analysis_detail = AD;        
            analysis_detail.exp_path = [exp_directory AD.analysis_path]; % test this...do we need anything else?
        catch exception
            fprintf(['Error: sequence_details file ' cur_dir(j).name ' does not load or is missing crucial info.'])            
            throw(exception)
        end
        cnt = cnt + 1;
    end
end

if cnt == 0
    error('No experiment_details file found, check file name or directory!');
elseif cnt > 1
    error('Too many experiment files, please re-check this');
end


for j = 1: length(cur_dir)
    if length(cur_dir(j).name) > 5
        if (strcmp(cur_dir(j).name(end-2:end), 'pdf'))
            delete(cur_dir(j).name)
        end
    end
end
    


cd([analysis_detail.exp_path]) 


if phase == 1,
    %{
    %% now seq6, phototaxis: median_velocity_x, preference index, and displacement
    sequence = 'seq1';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125 3625 7125];
    dir2_starts = [1875 5375 8875];
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    X_label = {'G = 25', 'G = 120', 'UV = 36', 'UV = 200'};
    X_label_short = {'GL', 'GH', 'UL', 'UH'};
    tube_length = 112.55; %length of tube in mm
    
    try
        load([analysis_detail.seq(1).path '_analysis_info.mat'])
    catch
        error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
    end
    phototaxis_analysis;
    %}
    %% seq1, contrast series w. same average intensity

    %sequence = 'seq1';
    %min_num_flies = 2; % minimum number of flies in tubes
    %del_t = 1/25; %inverse frames per second
    %dir1_starts = [125 3625 7125];
    %dir2_starts = [1875 5375 8875];
    %ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    %X_label = [2 4 8];
    %tube_length = 112.55; %length of tube in mm
    %pref_index = [2 4 4 8]; % indices to use for preference index
    %X_variable = 'Green Intensity';
    %main_title = 'Color Preference with Constant UV, Variable Green Intensities';

    %try
    %    load([analysis_detail.seq(1).path '_analysis_info.mat'])
    %catch
    %    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
    %end
    %color_preference_analysis;

    %% seq2, contrast series w. increasing intensity

    %sequence = 'seq2';
    %min_num_flies = 2; % minimum number of flies in tubes
    %del_t = 1/25; %inverse frames per second
    %%%dir1_starts = [125,625,1125,1625,2125,2625];
    %dir2_starts = [375,875,1375,1875,2375,2875];
    %trial_length = 100;
    %ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    %plot_conditions = [2,4,8,8,4,2]; %stimulus speeds
    %x_variable = 'Contrast';
    %main_title = 'Contrast with Increasing Average Intensity';

    %try
    %    load([analysis_detail.seq(2).path '_analysis_info.mat'])
    %catch
    %    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
    %end
    %linear_motion_analysis;
    
    sequence = 'seq2';
    min_num_flies = 2; % minimum number of flies in tubes
    del_t = 1/25; %inverse frames per second
    dir1_starts = [125,625,1125,1625,2125,2625];
    dir2_starts = [375,875,1375,1875,2375,2875];
    ma_points = 8; % number of points to use in ma smoothing of the velocity plot
    X_label = {'2pixL','4pixL','8pixL','8pixR','4pixR','2pixR'};
    X_label_short = {'2L','4L','8L','8R','4R','2R'};
    tube_length = 112.55; %length of tube in mm
    
    try
        load([analysis_detail.seq(2).path '_analysis_info.mat'])
    catch
        error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
    end
    phototaxis_analysis;


    
    
    
end


%% now save all of the data:
analysis_results(phase).analysis_version = analysis_version;
analysis_results(phase).BoxName = BoxName;
analysis_results(phase).TopPlateID = TopPlateID;

save([analysis_detail.exp_path filesep folder_path '_analysis_results.mat'],'analysis_results')
