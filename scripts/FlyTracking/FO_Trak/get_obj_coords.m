 function   [X,Y] = get_obj_coords(obj_info, curr_time, curr_obj)
 
 %%% gets the coordinates of the current object at the current time
 
 global trackedFrames;
 
 
 if( nargin < 3 ) %%% get coords for all objects
     obj_num = obj_info.obj_num;
     X = zeros(obj_num,1);
     Y = X;
     active_obj = find(obj_info.start_frame <= curr_time & obj_info.end_frame >= curr_time);
     num_active = length(active_obj);
      
     for i=1:num_active,
         curr_obj = active_obj(i);
         % index = curr_time - obj_info.start_frame(curr_obj) + 1;  %%% delete
         % index = curr_time - obj_info.first_frame + 1;
         index = [];
         for j=1:length(curr_time)
            index = [index, find(trackedFrames(curr_obj,:) == curr_time(j))];
         end
         X(curr_obj) = obj_info.x{curr_obj}(index);
         Y(curr_obj) = obj_info.y{curr_obj}(index);
     end
 else  %%% get coords only for curr_obj
     for i=1:length(curr_obj),
         % index = curr_time - obj_info.start_frame(curr_obj(i)) + 1; %%% delete
         % index = curr_time - obj_info.first_frame + 1;
         index = [];
         for j=1:length(curr_time)
            index = [index, find(trackedFrames(curr_obj(i),:) == curr_time(j))];
         end
         X(i,:) = obj_info.x{curr_obj(i)}(index);
         Y(i,:) = obj_info.y{curr_obj(i)}(index);
     end
 end    
 
 
 
