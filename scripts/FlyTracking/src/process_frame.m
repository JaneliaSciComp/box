function obj_info = process_frame(obj_info,I_curr_in,index)

%global outputDir;
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
global max_obj_ind; % scalar; current largest object index
global obj_orient;
global obj_data;
global colors;
global numFrames;
global displayTracking;
global file_index;
global saveFrameNum;
global frame_index;

assert(frame_index==index);

OBJINFO_ASSERTS = 1;
if mod(frame_index,500)==0
    fprintf(1,'processing frame %d (objinfo_asserts=%d)\n',frame_index,OBJINFO_ASSERTS);
end

I_curr = I_curr_in;

if( size(I_curr,3)>1 )
    %I_curr = rgb2gray(I_curr);
    I_curr = call_with_diag([],'rgb2gray',I_curr);
end

% AL: candidate_objects does not appear to reference any globals
[I_label, I_obj_prob] = candidate_objects(I_curr,I_bg,I_occlud,I_bg_top,I_bg_bottom);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% get predicted object position
% AL: predict_obj_pos does not appear to reference any globals
[predict_pos, predict_ind] = predict_obj_pos(pre_last_obj_pos,pre_last_obj_ind,last_obj_pos,last_obj_ind);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% combine the candidate object info and the predicted
%%% positions of objects
% AL: effect of predict_candidate is to remove candidates in case that the
% number of candidates exceeds max_obj_num
% AL: does not appear to reference any globals
[I_label,candidate_num] = predict_candidate(I_label,I_obj_prob,predict_pos,predict_ind,max_obj_num);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% get object properties
% props2d = regionprops(I_label,'Centroid');    
% props1d = regionprops(I_label,'Orientation','MajorAxisLength');    
props2d = call_with_diag([],'regionprops',I_label,'Centroid');    
props1d = call_with_diag([],'regionprops',I_label,'Orientation','MajorAxisLength');    

%%%% go over centroids, kill line ellipses and place the centroids in an array
[new_obj_pos,obj_length,obj_orient] = get_centroids(props2d,props1d);
%obj_length = 18;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% track objects
%%%% match previous positions with the new positions. 
%%%% update the label image accordingly
%%%% track_obj assigns only one old obj to each new one so we have
%%%% merged objects.

obj_data = obj_orient;
% AL
% last_obj_pos
% last_obj_ind
% new_obj_pos: Nnewobjx2 x-y locs (centroids) of objects in new frame.
% obj_length: median object length of objects in new_obj_pos.
% predict_pos: array with same size as last_obj_pos; predicted locs of
% those objs for current (new) frame.
% obj_data: Nnewobjx1 vector of orientations for objects in new_obj_pos.
% max_obj_num:
[new_obj_pos, new_obj_ind, obj_data, max_obj_ind] = ...
    track_obj(last_obj_pos, last_obj_ind, new_obj_pos,...
             obj_length, predict_pos, obj_data, max_obj_num, max_obj_ind);

if isempty(obj_data)
    return
else
    obj_info = obj_info_update(obj_info, new_obj_pos, new_obj_ind, obj_data, ...
        frame_index, index, obj_length, max_obj_ind);    
    if OBJINFO_ASSERTS 
        VALIDATE_FRAC = 0.1;
        if rand < VALIDATE_FRAC
            obj_info_validate(obj_info,index,file_index,saveFrameNum);
        end
    end
end

if( displayTracking )
    I_mark = gen_output_image(I_label,colors,I_curr,new_obj_pos(:,1),new_obj_pos(:,2));
    figure(333); 
    title(['processed frame ' num2str(frame_index) ' out of ' num2str(numFrames)]);
    %imshow(I_mark); 
    call_with_diag([],'imshow',I_mark);
else
    %waitbar(frame_index/numFrames);   
end
pre_last_obj_pos = last_obj_pos;
pre_last_obj_ind = last_obj_ind;
last_obj_pos = new_obj_pos;
last_obj_ind = new_obj_ind;

% AL: note for only-non-zero-elements comment
%% no need for the next section, since the last_obj_pos and
%% pre_last_obj_pos don't have to be of the same size and are already with
%% only non-zero elements

% Save obj_info every saveNumFrames, or when complete
if mod(frame_index,saveFrameNum)==0 || numFrames==frame_index
    
    obj_info_save(obj_info,numFrames);
    
    if frame_index < numFrames
        % getting the next portion of frames for the reinitted obj_info
        partial_numFrames = min(numFrames-file_index*saveFrameNum,saveFrameNum);
        
        %%%% reinit obj_info - "only the num_active, data, x and y fileds get
        %%%% renewed so that we wouldn't loose information for the objects that
        %%%% are still tracked (it is easier this way instead of renewing all
        %%%% the fields and trying to keep track of the indexes where the still
        %%%% tracked obj were in all the previously saved infos)"
        obj_info.num_active = zeros(1,partial_numFrames);
        n = size(obj_info.data,2);
        obj_info.data = mat2cell(zeros(n,partial_numFrames),ones(1,n),partial_numFrames)';
        obj_info.x = obj_info.data;
        obj_info.y = obj_info.data;
    end
end    
