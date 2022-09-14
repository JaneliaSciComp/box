
function [Trak_success] = olympiadTrak(paramFile, inputFile, outputDir)
%% this is simply an updated version of FlyTracker
% in this version the paramFile does not specify the movie location to
% simplify the batch processing
close all;
Trak_success.success = 1; 
Trak_success.error = []; % do something fancier...

% XXXAL
call_with_diag([],'_init');

%% make sure we can find the utility functions
srcPath = mfilename('fullpath');
parentDir = fileparts(srcPath);
addpath(fullfile(parentDir, 'utils'));


%% read parameter file

if( nargin==0 )
    if isdeployed
        disp('Usage: fo_trak param_file_path movie_file_path output_dir_path');
        return
    else
        disp('Not deployed');
        paramFile = 'params.txt';
    end
end
[params] = read_params_olympiad(paramFile, inputFile, outputDir);

%% deal with movie formats
if issbfmf(params.inputFile)
    sbfmf_info = sbfmf_read_header(params.inputFile);
else
    sbfmf_info = [];
end

%% Initialize background
if( params.updateBg | ~exist(params.bgFile))
    disp('Estimating background image');
    histScale = 4;
    %I_bg = bg(params.inputFile,params.frameIndices,histScale,params.bgFile, sbfmf_info);
    I_bg = bg_simple(params.inputFile,params.frameIndices,histScale,params.bgFile, params.bgThresh, sbfmf_info);
end

%% select region of interest
I_bg = imread(params.bgFile);
if( params.updateRoi == 0 & exist(params.roiFile))
    I_roi = imread(params.roiFile);
else
    if( params.updateRoi == 0) %then use whole image as ROI
        I_roi = set_ROI_to_all(params, I_bg);
    %else   % update w. ROI info from txt file
        %I_roi %= 
    end
end
% save roi image
imwrite(uint8(I_roi),params.roiFile);


%% track
try
    disp('Tracking ...');
    if( ~islogical(I_roi) )
        I_roi_bw = I_roi > 0.5; % makes this into class logical
    else 
        I_roi_bw = I_roi;
    end
    obj_info = main( params.outputDir, params.inputFile, ...
        params.frameIndices, params.bgFile, params.displayTracking,...
        I_roi_bw, params.tubeToProcess, params.maxObjNum, sbfmf_info);
catch
    Trak_success.success = 0; 
    Trak_success.error = lasterror;    
end


%% post-processing of tracks
if (Trak_success.success)
    try
        disp('Post processing tracks');
        if (obj_info.obj_num > 0)
            obj_info_upd = post_main(params.outputDir, params.inputFile, params.bgFile);
            [analysis_info,analysis_info_tube] = track_analysis_params(params);
        else % no flies detected, save simple, output file
            analysis_info.max_tracked_num = 0;
            analysis_info_tube = [];
        end
        analysis_info.version = '1.1.1'; 
        % 1.1: modified/bugfixed for retracking. AL
        % 1.1.1: remove pos_hist, mov_pos_hist. AL 20140410 
        
        str = sprintf('%s%sanalysis_info',params.outputDir,filesep);
        % AL: branching here is historical, seems unnecessary
        if isempty(analysis_info_tube)
            save(str,'analysis_info');
        else
            save(str,'analysis_info','analysis_info_tube');
        end

        % clean up all temp files...
        dir_struct = dir([params.outputDir filesep 'info*.mat']);
        for j = 1: length(dir_struct)
            if (length(dir_struct(j).name) >= 9) & (length(dir_struct(j).name) <= 10)
                delete([params.outputDir filesep dir_struct(j).name])
            end
        end        
    catch
       Trak_success.success = 0; 
       Trak_success.error = lasterror;
    end    
end

%write status output
cd(params.outputDir)
fid = fopen('trak_results.txt', 'w');
fprintf(fid, 'Success %d \n', Trak_success.success);
if Trak_success.success
    if analysis_info.max_tracked_num == 0 % deal w. the empty tube cases...
        fprintf(fid, 'Median number flies tracked %d \n', 0);
    else
        fprintf(fid, 'Median number flies tracked %d \n', median(analysis_info.tracked_num));
    end
end
fclose(fid);

save trak_success Trak_success

% XXXAL
call_with_diag([],'_dump');


%% generate video output --skip this for now...
%if( params.genVideoOutput )
%    disp('Saving video output');
%    output_video(obj_info_upd,params.outputDir,params.inputFile,params.frameIndices, params.frameRate, sbfmf_info);
%end
