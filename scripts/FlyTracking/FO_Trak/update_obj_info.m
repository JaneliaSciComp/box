function   obj_info = update_obj_info(obj_info, new_obj_pos, new_obj_ind, curr_time, index, obj_length, obj_data)

global file_index;


%% if info has been saved to file modify the index to fit the new obj_info
saveFrameNum = 500;
if (file_index > 0)
    index = (index - saveFrameNum*file_index);
end

%% add entries for new objects
prev_obj_num = obj_info.obj_num;

active_obj_ind = find(new_obj_pos(:,1) > 0);
obj_info.num_active(index) = length(active_obj_ind);

for i=1:obj_info.num_active(index),
    curr_obj_ind = active_obj_ind(i);
    curr_obj = new_obj_ind(curr_obj_ind);
    if( curr_obj > prev_obj_num )  %% a new object
        obj_info.start_frame(curr_obj) = curr_time;
    end
    obj_info.data{curr_obj}(index) = obj_data(curr_obj_ind,:);
    obj_info.x{curr_obj}(index) = new_obj_pos(curr_obj_ind,1);
    obj_info.y{curr_obj}(index) = new_obj_pos(curr_obj_ind,2);
    obj_info.end_frame(curr_obj) = curr_time;

%     if( curr_obj > prev_obj_num )  %% a new object    %%%%% comment all the if loop out
%         obj_info.data{curr_obj} = obj_data(curr_obj,:); %%% delete
%         obj_info.x{curr_obj} = new_obj_pos(curr_obj,1); %%% delete
%         obj_info.y{curr_obj} = new_obj_pos(curr_obj,2); %%% delete
%         obj_info.start_frame(curr_obj) = curr_time;
%         obj_info.end_frame(curr_obj) = curr_time; %%% delete
%     else %%% delete all
%         obj_info.data{curr_obj} = [obj_info.data{curr_obj},obj_data(curr_obj,:)]; %%% delete
%         obj_info.x{curr_obj} = [obj_info.x{curr_obj},new_obj_pos(curr_obj,1)]; %%% delete
%         obj_info.y{curr_obj} = [obj_info.y{curr_obj},new_obj_pos(curr_obj,2)]; %%% delete
%         obj_info.end_frame(curr_obj) = curr_time;  %%% delete
%     end

end

if isempty(active_obj_ind)
    error('tracking has lost objects - no objects to track in the image');
    obj_info.obj_num = [];
    obj_info.last_frame = [];
    obj_info.obj_length = [];
else    
    obj_info.obj_num = curr_obj;
    obj_info.last_frame = curr_time;
    obj_info.obj_length = obj_length;
end    

 
 
 
