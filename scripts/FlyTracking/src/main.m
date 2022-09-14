function [obj_info] = main(outputDir_in, inputFile, ...
    frameIndices, bgFile, displayTracking_in, I_roi,...
    tubeToProcess, max_obj_num_in, sbfmf_info)

global outputDir;
global I_label;
global I_obj_prob;
global I_curr;
global I_bg;
global I_bg_top;
global I_bg_bottom;
global I_occlud;
global pre_last_obj_pos;
global pre_last_obj_ind;
global last_obj_pos;
global last_obj_ind;
%global obj_info;
global predict_pos;
global max_obj_num; 
global props1d; 
global props2d;
global obj_length;
global new_obj_pos;
global max_obj_ind; % scalar; current maximum object index ever achieved
global obj_orient;
global obj_data;
global colors;
global numFrames;
global displayTracking;
global frame_index;
global file_index; file_index = 0;
global saveFrameNum; saveFrameNum = 500;
global trackedFrames; trackedFrames = [];

max_obj_num = max_obj_num_in;
displayTracking = displayTracking_in;
outputDir = outputDir_in;
%%%% read background file
I_bg = imread(bgFile);
dots = find(bgFile ==  '.');
if( numel(dots) == 0 )
    file_top = [bgFile '_top'];
    file_bottom = [bgFile '_bottom'];
else
    last_dot = dots(end);
    prefix = bgFile(1:last_dot-1);
    file_top = [prefix '_top.bmp'];
    file_bottom = [prefix '_bottom.bmp'];
end
I_bg_top = imread(file_top);
I_bg_bottom = imread(file_bottom);

%%% set colors for display
colors = colorcube(10000);

if isempty(sbfmf_info)
    % just a placehodler, do nothing...
else
    sbfmf_info.fid = fopen(inputFile, 'r' ); %this is where we put in handle to sbfmf
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% define occluded regions
% se1 = strel('disk',1);
% se2 = strel('disk',2);
%#function strel immultiply ordfilt2 bwlabel rgb2gray edge imdilate regionprops imshow
se1 = call_with_diag([],'strel','disk',1);
se2 = call_with_diag([],'strel','disk',2);
edge_thresh = 0.6;   %%% A huristic
%I_occlud = ~imdilate(edge(I_bg,'canny',edge_thresh),se1);
tmp_edge = call_with_diag([],'edge',I_bg,'canny',edge_thresh);
I_occlud = ~call_with_diag([],'imdilate',tmp_edge,se1);
%%%% process only region of interest
%I_occlud = immultiply(I_occlud,uint8(I_roi));
I_occlud = call_with_diag([],'immultiply',I_occlud,uint8(I_roi));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% process frame by frame

%%% last_obj_pos and pre_last_obj_pos contain only the nonzero (i.e. tracked)
%%% object position, while last_obj_ind and pre_last_obj_ind contain the
%%% objects who's position is in the first two matrixes..... for example:
%%% last_obj_pos(i,:) has the position of the last_obj_ind(i) fly
last_obj_pos = zeros(0,2);
last_obj_ind = zeros(0,1);
pre_last_obj_pos = zeros(0,2);
pre_last_obj_ind = zeros(0,1);
numFrames = length(frameIndices);
start_frame = frameIndices(1);

%%% getting the number of tubes
if( min(tubeToProcess) == 0 )
    tubes = 8;
else 
    tubes = length(tubeToProcess);
end

%%% getting the partial number of frames for the sequenced obj_info
if  (numFrames > saveFrameNum)
    partial_numFrames = saveFrameNum;
else
    partial_numFrames = numFrames;
end
%%% guessing the maximum number of objects 
if max_obj_num > 0
    total_obj = 10*max_obj_num*tubes;
else
    total_obj = 10*20*tubes;
end

obj_info = obj_info_construct(total_obj,partial_numFrames,start_frame);
max_obj_ind = 0;

%%% Now loop over all frames
for f=1:numFrames,
    frame_index = frameIndices(f);
    I_curr = load_image(inputFile, frame_index, sbfmf_info);
    obj_info = process_frame(obj_info,I_curr,frame_index);
    if mod(frame_index,100)==0
        fprintf(1,'Done tracking frame %d\n',frame_index);
    end
end

num_obj = obj_info.obj_num;
if num_obj == 0
    % kick out with a warning
    warning('No flies detected'); %#ok<WNTAG>
    return;
end

obj_info.start_frame = obj_info.start_frame(1:num_obj);
obj_info.end_frame = obj_info.end_frame(1:num_obj);

% compute trackedFrames global
trackedFrames(1:num_obj,1:numFrames) = -1;
for i=1:num_obj
    trackedFrames(i,1:(obj_info.end_frame(i)-obj_info.start_frame(i)+1)) = ...
            obj_info.start_frame(i):obj_info.end_frame(i);
end

obj_info = obj_info_load(obj_info,numFrames,outputDir,file_index,saveFrameNum);

if isempty(sbfmf_info)
    % just a placehodler, do nothing...
else % if necessary, close the movie file
   fclose(sbfmf_info.fid);
   sbfmf_info.fid = [];
end

if( displayTracking )
    close(333);
else
  %  close(h);
end
%close all; commented out by MBR

%%% save final object positions into a file named obj_pos in the output
%%% directory
str = sprintf('%s%strack_info',outputDir,filesep);
save(str,'obj_info');

