
function [obj_info] = main(outputDir_in, inputFile, ...
    frameIndices, bgFile, displayTracking_in, I_roi,...
    tubeToProcess, max_obj_num_in, sbfmf_info);


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
global obj_info;
global predict_pos;
global max_obj_num;
global props1d; 
global props2d;
global obj_length;
global new_obj_pos;
global obj_orient;
global obj_data;
global colors;
global numFrames;
global displayTracking;
global frame_index;
global file_index; file_index = 0;
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
se1 = strel('disk',1);
se2 = strel('disk',2);
edge_thresh = 0.6;   %%% A huristic
I_occlud = ~imdilate(edge(I_bg,'canny',edge_thresh),se1);
%%%% process only region of interest
I_occlud = immultiply(I_occlud,uint8(I_roi));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% process frame by frame

%%% initialize obj_info
obj_info = [];
obj_info.obj_num = 0;
obj_info.last_frame = 0;

%%% last_obj_pos and pre_last_obj_pos contain only the nonzero (i.e. tracked)
%%% object position, while last_obj_ind and pre_last_obj_ind contain the
%%% objects who's position is in the first two matrixes..... for example:
%%% last_obj_pos(i,:) has the position of the last_obj_ind(i) fly
last_obj_pos = [];
last_obj_ind = [];
pre_last_obj_pos = [];
pre_last_obj_ind = [];
numFrames = length(frameIndices);
start_frame = frameIndices(1);
obj_info.first_frame = start_frame;


% %%% getting the number of tubes
if( min(tubeToProcess) == 0 )
    tubes = 8;
else 
    tubes = length(tubeToProcess);
end

%%% getting the partial number of frames for the sequenced obj_info
saveFrameNum = 500;
if  (numFrames > saveFrameNum)
    partial_numFrames = saveFrameNum;
else partial_numFrames = numFrames;
end

%%% guessing the maximum number of objects 
if( max_obj_num > 0 )
    total_obj = 10*max_obj_num*tubes;
else
    total_obj = 10*20*tubes;
end

%% mkdir for temporary files -- maybe simpler for clearing debris
%% afterwards...
% cmd = ['!mkdir ' outputDir filesep 'results'];
% eval(cmd);


%%% preallocating obj_info in termes of the max number of objects and
%%% partial number of frames
obj_info.num_active = zeros(1, partial_numFrames);
obj_info.data = cell(1,total_obj); 
obj_info.x = cell(1,total_obj);
obj_info.y = cell(1,total_obj);
for i = 1:total_obj
    obj_info.data{1,i} = zeros(1,partial_numFrames);
    obj_info.x{1,i} = zeros(1,partial_numFrames);
    obj_info.y{1,i} = zeros(1,partial_numFrames);
end        
obj_info.start_frame = zeros(1,total_obj);
obj_info.end_frame = zeros(1,total_obj);

if(~displayTracking )
     %%%% display progress
     %h=waitbar(0,'Tracking in progress...');
end

%%% Now loop over all frames

for f=1:numFrames,
    frame_index = frameIndices(f);
    I_curr = load_image(inputFile, frame_index, sbfmf_info);
    process_frame(I_curr,frame_index);
end


%%% resizing the obj_info fields now that we know how many objects we have
%%% and putting it together with the rest of the sequenced obj_infos saved
%%% on files
num_obj = obj_info.obj_num;
if (num_obj == 0) % kick out with a warning
    warning('No flies detected');
    return
end

obj_info.start_frame = obj_info.start_frame(1:num_obj);
obj_info.end_frame = obj_info.end_frame(1:num_obj);

trackedFrames(1:num_obj,1:numFrames) = -1;
for i=1:num_obj
    trackedFrames(i,1:(obj_info.end_frame(i)-obj_info.start_frame(i)+1)) = ...
            [obj_info.start_frame(i):obj_info.end_frame(i)];
end

num_active = zeros(1,numFrames);
for j=1:file_index %%% loading from files
    load([outputDir filesep 'info' num2str(j)]);
    num_active(saveFrameNum*(j-1)+1:saveFrameNum*j) = info.num_active;
end
num_active(saveFrameNum*file_index+1:numFrames) = obj_info.num_active;
obj_info.num_active = num_active;

%     data = mat2cell(zeros(num_obj,numFrames),ones(1,num_obj),numFrames)';
data = cell(1,num_obj);
x = data;
y = data;
    
for j=1:file_index %%% loading from files
    load([outputDir filesep 'info' num2str(j)]);
    % load(['results/info' num2str(j)]);
    for i=1:num_obj
        if (i <= info.obj_num & numel(info.data{1,i})>0 )
            data{1,i} = [data{1,i},info.data{1,i}];
            x{1,i} = [x{1,i},info.x{1,i}];
            y{1,i} = [y{1,i},info.y{1,i}];
        end
    end
end

start_frame = max(obj_info.start_frame,(file_index)*saveFrameNum+1) - (file_index)*saveFrameNum;
end_frame = obj_info.end_frame - (file_index)*saveFrameNum;
    
    
for i=1:num_obj
    %% adding the last part of obj_info
    if( end_frame(i) > 0 )
        data{1,i} = [data{1,i},obj_info.data{1,i}(start_frame(i):end_frame(i))];
        x{1,i} = [x{1,i},obj_info.x{1,i}(start_frame(i):end_frame(i))];
        y{1,i} = [y{1,i},obj_info.y{1,i}(start_frame(i):end_frame(i))];     
    end
end

obj_info.data = data;
obj_info.x = x;
obj_info.y = y;

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
str = sprintf('%s%strack_info',outputDir, filesep);
save(str,'obj_info');









%%
