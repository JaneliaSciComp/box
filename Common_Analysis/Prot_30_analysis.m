function exp_detail = Prot_30_analysis(exp_directory, save_plots, folder_path, temp, AD, protocol, analysis_version)
% analysis code for Protocol 3.0 starting feb, 2010

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
    

%% Initialize and run seq1
del_t = 1/25;
min_num_flies = 2; %10; minimum number of flies in tubes
y_lim_vel = 30; % limit in mm/s on the y axes
y_lim_disp = 180; % length of displacement in mm
ma_points = 8; % number of points to use in ma smoothing of the velocity plot

cd([analysis_detail.exp_path]) 

% movie 1 (equilibration): seq1.avi goes from 180 s to 300 s (should have 3000 frames)
% all in the dark.  Video aquisition begins 3 minutes after beginning of
% experiment

try

    load([analysis_detail.seq(1).path '_analysis_info.mat'])
catch
    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
end

for tube_num = 1:6
    analysis_results(tube_num).seq1 = Common_analysis(analysis_info_tube(tube_num));
end


%% analysis for seq2, vibrations

%cd([analysis_detail.exp_path analysis_detail.analysis_path analysis_detail.seq(2).path])
try
    load([analysis_detail.seq(2).path '_analysis_info.mat'])
catch
    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
end
Seq2_analysis;

%% seq3, Linear Motion Analysis
try
    load([analysis_detail.seq(3).path '_analysis_info.mat'])
catch
    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
end
Seq3_analysis;

    
%% now seq4, median_velocity_x, preference index, and displacement
try
    load([analysis_detail.seq(4).path '_analysis_info.mat'])
catch
    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
end
Seq4_analysis;
  
%% now seq5, median_velocity_x and preference index
try
    load([analysis_detail.seq(5).path '_analysis_info.mat'])
catch
    error(['No analysis_info in directory ' pwd ' bad name or analysis not run'])
end
Seq5_analysis;

close all

%% Disabling call to tube_average until it's ready.
%tube_average

%% now save all of the data:
analysis_results(1).analysis_version = analysis_version;
analysis_results(1).BoxName = BoxName;
analysis_results(1).TopPlateID = TopPlateID;

save([analysis_detail.exp_path filesep folder_path '_analysis_results.mat'],'analysis_results')

    