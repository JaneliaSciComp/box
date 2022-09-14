function [analysis_info,analysis_info_tube] = track_analysis_params(params)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%5
%%%%%%%% FlyTrackerAnalysis software
% changed by MBR to remove need for params file

%%%% if frame rate was not set in param file read it from avi file
if( params.frameRate <=0 )
    warning('Negative or zero frame rate specified, using default of 25 fps')
    params.frameRate = 25;
end

%%%% if calibration pixels-to-mm was not set in param file or is negative
if( params.pixToMm <= 0 )
    warning('PixToMm is zero or negative, using arbitrary value of 0.1'); % allow for some input here.
end
    
str = sprintf('%s%strack_info_upd',params.outputDir,filesep);
load(str);

%%%%% now analyze the tracks
disp('Analyzing tracks');
%%% analysis of all tubes
Ibg = imread(params.bgFile);
[n_r n_c] = size(Ibg);
boundaries = [0, n_c, 0, n_r];
[analysis_info] = analysis_olympiad(obj_info, params.pixToMm, params.frameRate, params.moveThresh, boundaries);

%%% if multiple tubes were processed we want to separate output for each
I_roi = imread(params.roiFile);
num_roi = double(max(I_roi(:)));
load([params.outputDir filesep 'ROI_coords']);

str = sprintf('%s%sanalysis_info',params.outputDir,filesep);

if( num_roi > 1 ) %%% more than one region of interest
%    IR = imadd(I_roi, uint8(100*(I_roi > 0.5)));  % need this trick to lift ROIs from mean of image
%    [I_tmp,left,right,top,bottom] = find_roi(IR);
% changed by MBR to remove find_roi function call
    for i=1:length(ROI_coords.Left)        
        boundaries = [ROI_coords.Left(i),ROI_coords.Right(i), ROI_coords.Top(i), ROI_coords.Bottom(i)];
        tmp  = analysis_info(obj_info, params.pixToMm, params.frameRate, params.moveThresh, boundaries);
        tmp.index = i;
        analysis_info_tube(i) = tmp;
    end   

% removed by MBR - tubeToProcess unecessary
% elseif( numel(params.tubeToProcess) > 1 )   
%     %%% load 
%     I_bg = imread(params.bgFile);
%     [I_roi,left,right,top,bottom] = find_roi(I_bg);
%     %%% analyze tube by tube
%     for i=1:numel(params.tubeToProcess),        
%         boundaries = [left(params.tubeToProcess(i)),right(params.tubeToProcess(i)),top,bottom];
%         tmp  = analysis(obj_info, params.pixToMm, params.frameRate, params.moveThresh, boundaries);
%         tmp.index = params.tubeToProcess(i);
%         analysis_info_tube(i) = tmp;
%     end    
    save(str,'analysis_info','analysis_info_tube');
    
else
    analysis_info_tube = [];
    save(str,'analysis_info');
end


write_excel(analysis_info,analysis_info_tube,params.outputDir);