function  [obj_info] = traj_post_process(obj_info, I_roi)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% post-process trajectories and concatante lost threads
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% parameter definition
global MERGE;  MERGE = 1;
global SPLIT;  SPLIT = 2;
global LOST;  LOST = 3;
global NEW;  NEW = 4;
global LARGE;  LARGE = 9E9;
global E_TYPE;  E_TYPE= 1;
global E_TIME;  E_TIME = 2;
global E_PARENT;  E_PARENT = 3;
global E_CHILD;  E_CHILD = 4;
global E_IND;  E_IND = 5;
global E_X;  E_X = 6;
global E_Y;  E_Y = 7;

%%% initialize parameters
total_time = obj_info.last_frame;
obj_num = obj_info.obj_num;

%%% A hack - assume an object can't move more than 2 times its size
max_dist = 2*obj_info.obj_length;

%% all of the mergers & splits are currently commented out as these lead to
%% long run times and errors.

% %%% find all lost objs
% [lost] = find_lost(obj_info); toc
% %%% find all new objs
% [new] = find_new(obj_info); toc
% %%% find all mergers  
% [mergers,splits] = find_mergers_splits(obj_info, lost, new, max_dist); toc
% size(mergers)
% size(splits)
% %%% get a table of all events sorted by time
% [event_table] = get_event_table(mergers,splits,lost,new); toc
% size(event_table)
%  
% 
% %%%  process all event chains       
% for curr_event_ind = 1:size(event_table,2),
%     %% currently I process only event chains which start with a merge
%     if( event_table(1,curr_event_ind) ~= MERGE )
%         continue;
%     end
%     [event_forecast] = find_event_forecast(event_table,curr_event_ind);
%     if( numel(event_forecast) )
%         [obj_info, event_table] = process_event_chain(obj_info, event_forecast, event_table);
%     end
% end
% toc

%%% try to find objects missed in a single frame
[obj_info] = handle_single_frame_miss(obj_info, max_dist);


%%%% remove objects detected only in a single frame or less
path_length = obj_info.end_frame - obj_info.start_frame;
single_frame_obj = find(path_length < 1);
if( numel(single_frame_obj ) )
    for i=1:length(single_frame_obj)
        obj_info = delete_object(obj_info,single_frame_obj(i));
    end
end

%%% try to handle objects lost while moving outside of roi
[obj_info] = handle_outside_roi(obj_info, I_roi, max_dist);

%%%% remove objects detected only in a single frame or less
path_length = obj_info.end_frame - obj_info.start_frame;
single_frame_obj = find(path_length < 1);
if( numel(single_frame_obj ) )
    for i=1:length(single_frame_obj)
        obj_info = delete_object(obj_info,single_frame_obj(i));
    end
end






































%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%% utility functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% find all mergers and splits
function [mergers,splits] = find_mergers_splits(obj_info, lost, new, max_dist)

global MERGE;
global SPLIT;
global E_TYPE;  
global E_TIME; 
global E_PARENT;  
global E_CHILD;  
global E_IND; 
global E_X;  
global E_Y;  

total_time = obj_info.last_frame;

mergers = [];
splits = [];
for f=obj_info.first_frame+1:total_time-1,    
    [curr_pos(:,1),curr_pos(:,2)] = get_obj_coords(obj_info,f); 
    [prev_pos(:,1),prev_pos(:,2)] = get_obj_coords(obj_info,f-1); 
    curr_to_prev_dist = dist2(curr_pos,prev_pos);
    curr_to_prev_dist = curr_to_prev_dist.^(1/2);
    
    %%%%%%% mergers
    [nearest_curr_dist, nearest_curr_ind] = min(curr_to_prev_dist);
    currently_lost = lost(E_PARENT,find(lost(E_TIME,:)==f));
    %% consider only lost objects 
    nearest_curr_dist = nearest_curr_dist(currently_lost);
    nearest_curr_ind = nearest_curr_ind(currently_lost);
    %% consider only objects who's distance is small enough
    tmp = find(nearest_curr_dist < max_dist);
    nearest_curr_dist = nearest_curr_dist(tmp);
    nearest_curr_ind = nearest_curr_ind(tmp);
    currently_lost_who_merge = currently_lost(tmp);
    num_curr_mergers = length(nearest_curr_ind);  
    if(num_curr_mergers)
        clear curr_mergers;
        curr_mergers(E_TIME,:) = [ones(1,num_curr_mergers)*f] ; 
        curr_mergers(E_PARENT,:) = nearest_curr_ind; 
        curr_mergers(E_CHILD,:) = currently_lost_who_merge;
        curr_mergers(E_X,:) = curr_pos(nearest_curr_ind,1)';
        curr_mergers(E_Y,:) = curr_pos(nearest_curr_ind,2)';
        mergers = [mergers,curr_mergers];
    end
    
    %%%%%%% splits
    currently_new = new(E_PARENT,find(new(E_TIME,:)==f));
    [nearest_prev_dist, nearest_prev_ind] = min(curr_to_prev_dist');
    %% consider only new objects 
    nearest_prev_dist = nearest_prev_dist(currently_new);
    nearest_prev_ind = nearest_prev_ind(currently_new);
    %% consider only objects who's distance is small enough
    tmp = find(nearest_prev_dist < max_dist);
    nearest_prev_dist = nearest_prev_dist(tmp);
    nearest_prev_ind = nearest_prev_ind(tmp);
    currently_new_who_split = currently_new(tmp);
    num_curr_splits = length(nearest_prev_ind);  
    if( num_curr_splits )
        clear curr_splits;
        curr_splits(E_TIME,:) = [ones(1,num_curr_splits)*f] ; 
        curr_splits(E_PARENT,:) = nearest_prev_ind; 
        curr_splits(E_CHILD,:) = currently_new_who_split;
        curr_splits(E_X,:) = curr_pos(nearest_prev_ind,1)';
        curr_splits(E_Y,:) = curr_pos(nearest_prev_ind,2)';
        splits = [splits,curr_splits];   
    end
end
if( numel(mergers) )
    mergers(E_TYPE,:) = MERGE;
    mergers(E_IND,:) = 0;
end
if( numel(splits) )
    splits(E_TYPE,:) = SPLIT;
    splits(E_IND,:) = 0;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% find all lost objs
function [lost] = find_lost(obj_info)

global LOST;
global E_TYPE;  
global E_TIME; 
global E_PARENT;  
global E_CHILD;  
global E_IND; 
global E_X;  
global E_Y;  
lost_obj = find((obj_info.end_frame<obj_info.last_frame)&(obj_info.end_frame>-1));
if( isempty(lost_obj) )
    lost = [];
    return;
end
lost_time = obj_info.end_frame(lost_obj)+1;
num_lost = length(lost_time);
for i=1:num_lost,
    [X(i),Y(i)] = get_obj_coords(obj_info,lost_time(i)-1,lost_obj(i));
end

lost = zeros(7,num_lost);
lost(E_TYPE,1:num_lost) = LOST;
lost(E_TIME,:) = lost_time;
lost(E_PARENT,:) = lost_obj;
lost(E_CHILD,:) = 0;
lost(E_IND,:) = 0;
lost(E_X,:) = X;
lost(E_Y,:) = Y;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% find all new objs
function [new] = find_new(obj_info);

global NEW;
global E_TYPE;  
global E_TIME; 
global E_PARENT;  
global E_CHILD;  
global E_IND; 
global E_X;  
global E_Y;  
new_obj = find(obj_info.start_frame>obj_info.first_frame);
if( isempty(new_obj) )
    new = [];
    return;
end
new_time = obj_info.start_frame(new_obj);
num_new = length(new_time);
for i=1:num_new,
    [X(i),Y(i)] = get_obj_coords(obj_info,new_time(i),new_obj(i));
end

new = zeros(7, num_new);
new(E_TYPE,1:num_new) = NEW;
new(E_TIME,:) = new_time;
new(E_PARENT,:) = new_obj;
new(E_CHILD,:) = 0;
new(E_IND,:) = 0;
new(E_X,:) = X;
new(E_Y,:) = Y;




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [event_table] = get_event_table(mergers,splits,lost,new)

%% generate a table of all events sorted by time
global E_TIME;

event_table = [mergers,splits,lost,new];
[tmp,ind] = sort(event_table(E_TIME,:));
event_table = event_table(:,ind);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [next_event_ind] = find_next_event(event_table, curr_event_ind, related_objects)

% find next event after curr_event_ind which involves any of the related
% objects. We look only for event strictly AFTER the current event so that
% if the current event is a split or a merge the new/lost related to it
% will not be considered as the next event.
% (i.e, the child will be marked as new/lost at the same time the split/merge 
% occured)

global E_TIME;
global E_PARENT;
global E_CHILD;

curr_event_time = event_table(E_TIME,curr_event_ind);
next_event_ind = size(event_table,2)+1;
for i=1:length(related_objects)
    obj = related_objects(i);
    next_event = ...
        find((event_table(E_PARENT,:)==obj | event_table(E_CHILD,:)==obj) ...
        & event_table(E_TIME,:)>curr_event_time);
    next_event_ind = min([next_event_ind, next_event]);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [event_forecast] = find_event_forecast(event_table,curr_event_ind)
%% starting from a given event find the forecast of events related to the
%% participating objects

global MERGE;
global SPLIT;
global LOST;
global NEW;
global E_TYPE;
global E_TIME;
global E_PARENT;
global E_CHILD;

related_objects = event_table([E_PARENT,E_CHILD], curr_event_ind);
event_forecast = [event_table(:,curr_event_ind);curr_event_ind];

merge_num = length(find(event_forecast(E_TYPE,:)==MERGE));
split_num = length(find(event_forecast(E_TYPE,:)==SPLIT));
lost_num = length(find(event_forecast(E_TYPE,:)==LOST));
new_num = length(find(event_forecast(E_TYPE,:)==NEW));

%% if the number of mergers is larger than the number of splits I output
%% an empty forecast as nothing is to be done
while( merge_num > split_num ),    
    [next_event_ind] = find_next_event(event_table, curr_event_ind, related_objects); 
    if( next_event_ind > size(event_table,2) )
        event_forecast = [];
        return;
    end
    event_forecast = [event_forecast,[event_table(:,next_event_ind);next_event_ind]];
    related_objects = [related_objects;event_table([E_PARENT,E_CHILD], next_event_ind)];
    related_objects = unique(related_objects);
    curr_event_ind = next_event_ind;
    
    merge_num = length(find(event_forecast(E_TYPE,:)==MERGE));
    split_num = length(find(event_forecast(E_TYPE,:)==SPLIT));
    lost_num = length(find(event_forecast(E_TYPE,:)==LOST));
    new_num = length(find(event_forecast(E_TYPE,:)==NEW));
end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% update trajectories according to mergers and splits
function [obj_info,event_table] =  process_event_chain(obj_info,event_chain,event_table)
            
global MERGE;
global SPLIT;
global E_TYPE;
global E_TIME;
global E_PARENT;
global E_CHILD;
global E_IND;


%%% I currently handle only chains of type merge-merge-merge-split-split-split
%%% or merge-merge-split-split
%%% of up two three objects merging

%%% i try to deal with the mergers that get lost (but it doesn't work)
% type_order = event_chain(E_TYPE,:);
% if (~(all(type_order == sort(type_order))))
%     ind = 1;
%     while (type_order(ind)==MERGE)
%         ind = ind+1;
%     end
%     ind = ind-1;
%     event_chain = [event_chain(:,1:ind),event_chain(:,(length(type_order)-ind+1):length(type_order))];
%     ind = 1;
%     while (event_chain(E_TYPE,curr_event_ind)==MERGE)
%         merge_parent = event_chain(E_PARENT,ind);
%         split_parent = event_chain(E_PARENT,size(event_chain,2)-ind+1);
%         %% update the parents (make them the same)
%         %% then update the space in between them (don't know how)
%     end
% end
type_order = event_chain(E_TYPE,:);
if ((~(all(type_order == sort(type_order)))) | length(type_order)>6 )
    return;
end

%% process all mergers first-to-last
curr_event_ind = 1;
children = [];
while (event_chain(E_TYPE,curr_event_ind)==MERGE),
    curr_time = event_chain(E_TIME,curr_event_ind);
    curr_child = event_chain(E_CHILD,curr_event_ind);
    children = unique( [children,curr_child] );
    parent = event_chain(E_PARENT,curr_event_ind);   
    next_time = event_chain(E_TIME,curr_event_ind+1);            
    for i=1:length(children)
        obj_info = update_traj(obj_info,children(i),[curr_time:next_time-1],parent);
    end
    curr_event_ind = curr_event_ind+1;
end
merge_children = children;
    
%% now process all splits last-to-first
curr_event_ind = size(event_chain,2);
children = [];
parents = [];
while (event_chain(E_TYPE,curr_event_ind)==SPLIT),
    curr_time = event_chain(E_TIME,curr_event_ind);
    curr_child = event_chain(E_CHILD,curr_event_ind);
    children = unique( [children,curr_child] );
    parent = event_chain(E_PARENT,curr_event_ind);           
    prev_time = event_chain(E_TIME,curr_event_ind-1);  
    if( event_chain(E_TYPE,curr_event_ind-1)==MERGE )
        break;
    end
    for i=1:length(children)
        obj_info = update_traj(obj_info,children(i),[prev_time:curr_time-1],parent);
    end
    curr_event_ind = curr_event_ind-1;
end
split_children = children;

%%% concatante merge_children with split_children
%%% and erase the merge_children
for i=1:length(merge_children)   
    start_time = obj_info.start_frame(merge_children(i));
    end_time = obj_info.end_frame(merge_children(i));
    obj_info = update_traj(obj_info,split_children(i),[start_time:end_time],merge_children(i));
    obj_info = delete_object(obj_info,merge_children(i));
end
    
%%% make related events obsolete in event_table
%%% (I can't remove them as the table size must not change)
event_table(:,event_chain(8,:)) = 0;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [obj_info] = handle_single_frame_miss(obj_info, max_dist)
%%% try to find objects missed in a single frame

global E_TYPE;  
global E_TIME;  
global E_PARENT; 
global E_X;  
global E_Y; 

%%% process lost objects
%%% first update the lost/new object lists
[lost] = find_lost(obj_info);
[new] = find_new(obj_info);

for lost_ind = 1:size(lost,2),
    lost_time = lost(E_TIME,lost_ind);
    lost_obj = lost(E_PARENT,lost_ind);
    possible_new_ind = find(new(E_TIME,:)==lost_time+1);
    if( numel(possible_new_ind) == 0 ),
        continue;
    end
    %%% predict position for two frames after lost
    %%% from their last two frames
    [x2,y2] = get_obj_coords(obj_info,lost_time-1,lost_obj);
    if( obj_info.start_frame(lost_obj) > lost_time-2 )
        x1 = x2;  y1 = y2;
    else
        [x1,y1] = get_obj_coords(obj_info,lost_time-2,lost_obj);
    end
    pred_1= predict_obj_pos([x1,y1],[x2,y2]);
    pred_2 = predict_obj_pos([x2,y2],pred_1);
    pred_x = pred_2(1); pred_y = pred_2(2);
    %%% find positions of possible new objects
    possible_new_obj = new(E_PARENT,possible_new_ind);    
    possible_new_x = new(E_X,possible_new_ind);
    possible_new_y = new(E_Y,possible_new_ind);
    %%% distance between predicted pos and new objs
    pred_to_new_dist = sqrt((pred_x - possible_new_x).^2 + (pred_y - possible_new_y).^2);
    [nearest_dist, nearest_ind] = min(pred_to_new_dist);
    %%% if the nearest one is too far away, continue
    if( nearest_dist > max_dist )
        continue;
    end
    new_obj = possible_new_obj(nearest_ind);
    
    %%% concatante the lost and the new object
    obj_info = update_traj(obj_info,new_obj,lost_time,-1,pred_1'); %%% '
    obj_info = update_traj(obj_info,new_obj,[obj_info.start_frame(lost_obj):lost_time-1],lost_obj);
    %%% remove lost object from object list
    obj_info = delete_object(obj_info,lost_obj);

    %%% make event obsolete in new list
    new(:,possible_new_ind(nearest_ind)) = 0;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% try to handle objects lost while moving outside of roi
function [obj_info] = handle_outside_roi(obj_info, I_roi, max_dist)


global E_TYPE;  
global E_TIME;  
global E_PARENT; 
global E_X;  
global E_Y; 

total_time = obj_info.last_frame;

%%% first update the lost/new object lists
[lost] = find_lost(obj_info);
[new] = find_new(obj_info);
[height,width] = size(I_roi);

for lost_ind = 1:size(lost,2),
    lost_time = lost(E_TIME,lost_ind);
    lost_obj = lost(E_PARENT,lost_ind);
    %% if we are at the last frame, or if the object was observed for a
    %% single frame, continue
    if( lost_time == total_time | lost_time < obj_info.start_frame(lost_obj)+2)
        continue;
    end
    %% extract last observed position and predicted position
    [x1,y1] = get_obj_coords(obj_info,lost_time-2,lost_obj);
    [x2,y2] = get_obj_coords(obj_info,lost_time-1,lost_obj);
    pred= predict_obj_pos([x1,y1],[x2,y2]);
    pred_x = pred(1); pred_y = pred(2);

    x = x2;
    y = y2;
    %% if the predicted position is not outside roi, continue
    if( pred_x >= 1 & pred_y >= 1 & pred_x <= width & pred_y <= height ...
            & I_roi(round(pred_y),round(pred_x)) )
        continue;
    end    
    %%% find next new object appearing close to the lost position
    possible_new_ind = find(new(E_TIME,:)>lost_time);
    if( numel(possible_new_ind) == 0 )
        break;
    end
    possible_new_obj = new(E_PARENT,possible_new_ind);    
    possible_new_time = new(E_TIME,possible_new_ind);   
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FIX
    new_x = new(E_X,possible_new_ind);
    new_y = new(E_Y,possible_new_ind);
    dist_from_new = sqrt((x - new_x).^2 + (y - new_y).^2);
    %%% find all those near engouh to be the same object
    near_enough_ind = find(dist_from_new <= 2*max_dist);
    if (numel(near_enough_ind) == 0)
        break;
    end
    %%% take the one detected closest in time
    [tmp,new_ind] = min(possible_new_time(near_enough_ind));
    new_ind = near_enough_ind(new_ind);
    new_obj = possible_new_obj(new_ind);
    new_time = possible_new_time(new_ind);
    %%% Allow at most 50 frames of disappearing !!! HUERISTIC !!!!
    if( new_time-lost_time > 10 )
        continue;
    end
    
    %%% concatante the lost and the new object
    delta_time = new_time - lost_time;
    delta_x = new_x(new_ind) - x;
    delta_y = new_y(new_ind) - y;
  
    set_val = [ x + (delta_x/delta_time)*[1:delta_time] ; y + (delta_y/delta_time)*[1:delta_time]];
    obj_info = update_traj(obj_info,new_obj,[lost_time:new_time-1],-1,set_val);
    obj_info = update_traj(obj_info,new_obj,[obj_info.start_frame(lost_obj):lost_time-1],lost_obj);
    obj_info = delete_object(obj_info,lost_obj);
   
    %%% make event obsolete in new list
    new(:,possible_new_ind(new_ind)) = 0;
end
    



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [obj_info] =  update_traj(obj_info,obj_to_update,time_range,copy_from_obj, set_value)
%% update object trajectory by either:
%%   copying from another object
%%   setting a fixed value (need to set copy_from_obj to be negative)
%%   set_value can be a a 2xtime_range array where the first row is the x
%%   value and the second row is the y value.

global trackedFrames;

start_frame = time_range(1);
end_frame = time_range(end);

if( end_frame < obj_info.start_frame(obj_to_update)-1 )
    %%% the end_frame of the range to set must be consequtive to the current
    %%% start_frame of the object
    error('error in updating trajectories');
end
if( copy_from_obj <= 0 )
    if( numel(set_value) == 1 )
        X = ones(size(time_range))*set_value;
        Y = ones(size(time_range))*set_value;
    else
        X = set_value(1,:);
        Y = set_value(2,:);
    end
else
    [X,Y] = get_obj_coords(obj_info,time_range,copy_from_obj);
end

index1 = find((trackedFrames(obj_to_update,:) < time_range(1)) & (trackedFrames(obj_to_update,:) > -1));
index2 = find(trackedFrames(obj_to_update,:) > time_range(length(time_range)));

%size([obj_info.x{obj_to_update}(index1), X, obj_info.x{obj_to_update}(index2)])
%size([obj_info.y{obj_to_update}(index1), Y, obj_info.y{obj_to_update}(index2)])
%size([trackedFrames(obj_to_update,index1), time_range, trackedFrames(obj_to_update,index2)])

obj_info.x{obj_to_update}(1:length(time_range)+length(index1)+length(index2)) = ...
    [obj_info.x{obj_to_update}(index1), X, obj_info.x{obj_to_update}(index2)];

obj_info.y{obj_to_update}(1:length(time_range)+length(index1)+length(index2)) = ...
    [obj_info.y{obj_to_update}(index1), Y, obj_info.y{obj_to_update}(index2)];
trackedFrames(obj_to_update,1:length(index1)+length(index2)+length(time_range)) = ...
    [trackedFrames(obj_to_update,index1), time_range, trackedFrames(obj_to_update,index2)];

% obj_info.x{obj_to_update}(time_range-obj_info.first_frame+1) = [X];
% obj_info.y{obj_to_update}(time_range-obj_info.first_frame+1) = [Y];

if( end_frame == obj_info.start_frame(obj_to_update)-1 )
    %%% add values before current values
    % obj_info.x{obj_to_update} = [X,obj_info.x{obj_to_update}]; %% delete
    % obj_info.y{obj_to_update} = [Y,obj_info.y{obj_to_update}]; %% delete
    obj_info.start_frame(obj_to_update) = start_frame;
elseif( start_frame == obj_info.end_frame(obj_to_update)+1 )
    %%% add values after current values
    % obj_info.x{obj_to_update} = [obj_info.x{obj_to_update},X]; %% delete
    % obj_info.y{obj_to_update} = [obj_info.y{obj_to_update},Y]; %% delete
    obj_info.end_frame(obj_to_update) = end_frame;
else
    %%% add values after current values
    % obj_info.x{obj_to_update} = [X]; %% delete
    % obj_info.y{obj_to_update} = [Y]; %% delete
    obj_info.start_frame(obj_to_update) = start_frame;
    obj_info.end_frame(obj_to_update) = end_frame;
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [obj_info] =  delete_object(obj_info,obj_to_delete)
%% delete object from database

global trackedFrames;

obj_info.x{obj_to_delete} = [0];
obj_info.y{obj_to_delete} = [0];
obj_info.start_frame(obj_to_delete) = -1;
obj_info.end_frame(obj_to_delete) = -1;
trackedFrames(obj_to_delete,:) = -1;






