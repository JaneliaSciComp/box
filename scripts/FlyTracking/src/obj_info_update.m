function obj_info = obj_info_update(obj_info, new_obj_pos, new_obj_ind, ...
     obj_data, curr_time, index, obj_length, max_obj_ind)
% obj_info = obj_info_update(obj_info, new_obj_pos, new_obj_ind, ...
%    obj_data, curr_time, index, obj_length, max_obj_ind)
% Update obj_info structure with tracking information.
%
% new_obj_pos: position info for new frame
% new_obj_ind: object indices for new frame
% obj_data: object data for new frame
% curr_time: absolute frame index for new frame
% index: should be equal to curr_time
% obj_length: scalar, median object length for tracked objects in this frame
% max_obj_ind: current maximum object index used

global file_index;
global saveFrameNum;

assert(curr_time==index);
index = index - saveFrameNum*file_index; % rescale to relative index for this obj_info

assert(all(new_obj_pos(:,1)>0));
%active_obj_ind = find(new_obj_pos(:,1) > 0);
numNewObj = size(new_obj_pos,1);
obj_info.num_active(index) = numNewObj;
%obj_info.num_active(index) = length(active_obj_ind);

for i=1:numNewObj
    %curr_obj_ind = active_obj_ind(i);
    objIdx = new_obj_ind(i);
    if objIdx > obj_info.obj_num % new object
        obj_info.start_frame(objIdx) = curr_time;
    end

    obj_info.data{objIdx}(index) = obj_data(i,:); % obj_data should be col vec
    obj_info.x{objIdx}(index) = new_obj_pos(i,1);
    obj_info.y{objIdx}(index) = new_obj_pos(i,2);
    
    obj_info.end_frame(objIdx) = curr_time;
end

if numNewObj==0 %isempty(active_obj_ind)
    % AL hard error stops all tracking?
    error('tracking has lost objects - no objects to track in the image');
%     obj_info.obj_num = [];
%     obj_info.last_frame = [];
%     obj_info.obj_length = [];
else    
    %obj_info.obj_num = curr_obj;
    obj_info.obj_num = max_obj_ind;
    obj_info.last_frame = curr_time;
    obj_info.obj_length = obj_length;
end
