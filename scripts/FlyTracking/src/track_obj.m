function  [obj_pos, obj_ind, obj_data, max_obj_ind] = ...
    track_obj(last_obj_pos, last_obj_ind, new_obj_pos, obj_length, ...
              predict_pos, new_obj_data, max_obj_num, max_obj_ind)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% for each old obj match the most probable one
%% of the new objects
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

global LOST;
global UNMATCHED;
global LARGE_DIST;
LOST = -1;
UNMATCHED = 0;
LARGE_DIST = 1000; %9E9;

obj_num = size(last_obj_pos,1);
obj_pos = zeros(size(last_obj_pos));
obj_ind = last_obj_ind;
obj_data = nan(obj_num,1); % currently, obj_data has a single value, orientation 
new_obj_num = size(new_obj_pos,1);

assert(isequal(size(last_obj_pos),[obj_num 2]));
assert(isequal(size(last_obj_ind),[obj_num 1]));
assert(isequal(size(new_obj_pos),[new_obj_num 2]));
assert(isequal(size(new_obj_data),[new_obj_num 1]));
assert(isequal(size(predict_pos),size(last_obj_pos)));

%%% if no old values initialize with the new positions
%%% (if there are no predicted positions then we are on the first frame
%%% or there are no flies...
if(numel(predict_pos)==0) % condition should be same as obj_num > 0
    if (new_obj_num == 0) % added to adress issue with empty tubes
        % AL: this branch shouldn't be a special case, roll into
        % init_track.
        obj_pos = zeros(0,2); 
        obj_ind = zeros(0,1); 
        obj_data = zeros(0,1); 
        % max_obj_ind unchanged, no new tracks
    else   
        [obj_pos, obj_ind, obj_data, max_obj_ind] = init_track(new_obj_pos, new_obj_data, max_obj_ind);
    end
    return;
end

%%% if no new objects (all objects are lost)
if( new_obj_num == 0 )
    % AL: why keep these tracks, so they can be continued? This is unlike
    % treatment in case when there *are* new tracks -- in this case, tracks
    % that are not continued are discarded.
    % obj_pos = zeros(size(last_obj_pos)); 
    %
    % AL: I AM CHANGING THIS TO RESTART ALL TRACKS
    obj_pos = zeros(0,2);
    
    obj_ind = zeros(0,1);
    obj_data = zeros(0,1);
    % max_obj_ind unchanged, no new tracks
    return;
end

%%% find the distance between new positions and predicted ones
new_to_pred_dist = dist2(new_obj_pos, predict_pos);
new_to_pred_dist = new_to_pred_dist.^(1/2);
%%%  use only the distance to the predicted positions
new_to_old_dist = new_to_pred_dist;

%%% find for each old object the new object whose distance is minimal
%%% do not allow a new object to be matched to more than one old object
[nearest_new_dist, nearest_new_ind] = match_single(new_to_old_dist);

% AL
assert(isequal(size(nearest_new_dist),size(nearest_new_ind),[1 obj_num]));

%%% detect which objects are still tracked objects
% AL: Why would we ever have a flat zero in last_obj_pos?
if any(last_obj_pos(:,1)==0)
    assert(false);
    %fprintf(1,'ALLEN SURPRISE!\n');
end
tracked_obj = find(last_obj_pos(:,1)~=0);

%%% try using the statistics of step size to estimate the max_dist an
%%% object can travel - this didn't work out
%tmp = find(nearest_new_dist < LARGE_DIST);
%max_dist = mean(nearest_new_dist(tmp))+3*std(nearest_new_dist(tmp));

%%% A hack - assume an object can't move more than 2 times its size
max_dist = 2*obj_length;

%%% Call this to allow a many-to-one match (i.e., a single new obj can be
%%% matched to multiple old ones)
% new_gen_obj = [];
% [new_obj_pos, nearest_new_ind, nearest_new_dist, new_gen_obj] = ...
%    match_multi(new_to_old_dist,max_dist,nearest_new_dist, nearest_new_ind, new_obj_pos)

%%%%%%%%% Update tracking data
%%% go over all old objects and add to the obj_pos structure the 
%%% coordinates of the new object matched to each of them
%%% we throw away matches with distance between old and new too big.
is_new = ones(size(new_obj_pos,1),1);
%lost_ind = [];
%% no need to work on lost objects
for j=1:length(tracked_obj),
    curr_obj = tracked_obj(j);
    %% A hack - assume objs move at most max_dist pixels
    %% if nearest distance is too large lose the object
    if( nearest_new_dist(curr_obj) > max_dist )
        obj_pos(curr_obj,1) = 0;
        obj_pos(curr_obj,2) = 0; 
        % lost_ind = [lost_ind,curr_obj];
        %% if the nearest new one was duplicated then kill it
        % if( new_gen_obj )
        %     if( find( new_gen_obj == nearest_new_ind(curr_obj) )),
        %         is_new(nearest_new_ind(curr_obj)) = 0;
        %     end      
        % end
    else        
        obj_pos(curr_obj,1) = new_obj_pos(nearest_new_ind(curr_obj),1);
        obj_pos(curr_obj,2) = new_obj_pos(nearest_new_ind(curr_obj),2);
        obj_data(curr_obj,:) = new_obj_data(nearest_new_ind(curr_obj),:);
        is_new(nearest_new_ind(curr_obj)) = 0;
    end
end

%%%% generate new tracks for new objects that were not matched to old ones
%%%% give them a new identity 
tracked_num = nnz(is_new==0); % number of new objects which are continuations of old objects
%tracked_num = length(find(is_new==0));
if( tracked_num < max_obj_num )
    is_new_ind = find(is_new);
    if( length(is_new_ind)+tracked_num > max_obj_num )
        %%% if too many object were detected, we throw away some, randomly. HACK!!!
        is_new_ind = is_new_ind(1:max_obj_num-tracked_num);
    end
    
%     % AL
%     if any(is_new)
%         fprintf(1,'%d new tracks, indices %s.\n',length(is_new_ind),mat2str(obj_ind(length(obj_ind))+[1:length(is_new_ind)]));
%     end

    % AL
    % Augment the new tracks per is_new_ind to obj_pos, obj_ind, obj_data.
    assert(isequal(size(obj_pos),[obj_num 2]));
    assert(isequal(size(obj_ind),[obj_num 1]));
    assert(isequal(size(obj_data),[obj_num 1]));
    Nnew = numel(is_new_ind);
    augIdx = obj_num+(1:Nnew);
    obj_pos(augIdx,:) = new_obj_pos(is_new_ind,:);
    obj_data(augIdx,:) = new_obj_data(is_new_ind,:);
    newObjIdxs = max_obj_ind + (1:Nnew);
    obj_ind(augIdx,1) = newObjIdxs;
    max_obj_ind = max_obj_ind + Nnew;
    %obj_ind(augIdx) = obj_ind(length(obj_ind))+[1:length(is_new_ind)];    
end
 

%% keep only the tracked objects
tf_tracked = obj_pos(:,1)~=0;
obj_pos = obj_pos(tf_tracked,:);
obj_ind = obj_ind(tf_tracked);
obj_data = obj_data(tf_tracked,:);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% nearest_new_dist: 1xnum_old vector. nearest_new_dist(i) gives the distance
% between <the ith old object> and <the new object assigned to the ith old
% object, which tends to be that new object nearest to the ith old oject>.
% nearest_new_ind: 1xnum_old vector. nearest_new_ind(i) gives the index (eg
% into the rows of new_to_old_dist) of the new object assigned to the ith
% old object
function [nearest_new_dist, nearest_new_ind] = match_single(new_to_old_dist)

%%% for each old object match the closest new one
%%% do not allow double assignements.
%%% This provides a one-to-one match for as many objects as possible
%%% objects which merge will get UNMATCHED as their matched object ind

global UNMATCHED;
global LARGE_DIST;

[new_num,old_num] = size(new_to_old_dist);

%% handle only a single new object
% AL: why is this a special case? Maybe b/c of edge case in min() api?
if( new_num == 1 ),
    nearest_new_dist = LARGE_DIST*ones(1,old_num);
    nearest_new_ind = zeros(1,old_num);
    %nearest_new_ind = UNMATCHED*ones(1,old_num);
   [dist, ind] = min(new_to_old_dist);
   nearest_new_dist(ind) = dist;
   nearest_new_ind(ind) = 1;
   return;
end


%%% if the number of new objects is smaller than the number of old objects
%%% then we must have some unmatched objects
num_cant_match = max(0,old_num - new_num);
un_matched = old_num;
while( un_matched > num_cant_match )   
    %%% find for each old obj the closest new obj
    [nearest_new_dist, nearest_new_ind] = min(new_to_old_dist);
    %%% don't allow new obj to match more than one old obj
    %%% this assigns high dist to already selected objs
    %%% and marks lost old objs
    [new_to_old_dist,nearest_new_dist, nearest_new_ind] = ...
        kill_double_selection(new_to_old_dist,nearest_new_dist, nearest_new_ind);
    %%% how many old obj's are unmatched (and not lost)
    un_matched = length(find(nearest_new_ind==UNMATCHED));
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [new_to_old_dist, nearest_new_dist, nearest_new_ind] = ...
    kill_double_selection(new_to_old_dist, nearest_new_dist, nearest_new_ind)
%% don't let an object be selected twice 

global UNMATCHED;
global LARGE_DIST;

for i=1:max(nearest_new_ind),
    ind = find(nearest_new_ind == i);
    if( numel(ind) < 2 )
        continue;
    end
    [min_val,min_ind] = min(nearest_new_dist(ind));
    for j=[1:min_ind-1,min_ind+1:length(ind)]
        new_to_old_dist(nearest_new_ind(ind(j)),ind(j)) = LARGE_DIST; 
        nearest_new_dist(ind(j)) = LARGE_DIST;            
        nearest_new_ind(ind(j)) = UNMATCHED;
    end
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [obj_pos,obj_ind,obj_data,max_obj_ind] = ...
    init_track(new_obj_pos,new_obj_data,max_obj_ind)

%%% initialize the obj_pos structure
%%% this should be called only at time=1
% AL: not sure about this comment, theoretically seems possible for
% init_track to be called at later frames, anytime tracking goes from no
% flies to some flies

obj_num = size(new_obj_pos,1);
assert(size(new_obj_pos,2)==2);
obj_pos = new_obj_pos;
% obj_pos(:,1) = new_obj_pos(:,1);
% obj_pos(:,2) = new_obj_pos(:,2);
obj_ind = max_obj_ind + (1:obj_num)'; % All flies are new. Note at frame 1, max_obj_ind==0
max_obj_ind = max_obj_ind + obj_num;
obj_data = new_obj_data;

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [new_obj_pos, nearest_new_ind, nearest_new_dist, new_gen_obj] = ...
%     match_multi(new_to_old_dist,max_dist,nearest_new_dist, nearest_new_ind, new_obj_pos)
% %%% Allow double assignments for old objects that were not
% %%% matched and that their predicted position is close enough to one of the new
% %%% objects.
% %%% This can be run only after a one-to-one match was already done
% 
% new_gen_obj = [];
% [nearest_new_dist_2, nearest_new_ind_2] = min(new_to_old_dist);
% %% now we need to duplicate new objects that were assigned to more then one
% %% old one.
% unmatched = find( nearest_new_dist > max_dist | nearest_new_ind == UNMATCHED);
% dup_matches = nearest_new_ind_2(unmatched);
% delta = [0,1;1,1;1,0;1,-1;0,-1;-1,-1;-1,0;-1,1];
% new_gen_obj = [];
% for i=1:length(dup_matches),        
%     duplicated_pos(1) = new_obj_pos(dup_matches(i),1);
%     duplicated_pos(2) = new_obj_pos(dup_matches(i),2);
%     duplicated_pos = duplicated_pos + delta(rem(i,length(delta))+1);
%     new_obj_num = size(new_obj_pos,1)+1;
%     new_obj_pos(new_obj_num,:) = duplicated_pos;
%     nearest_new_ind(unmatched(i)) = new_obj_num;
%     nearest_new_dist(unmatched(i)) = nearest_new_dist_2(unmatched(i));
%     I_label(round(duplicated_pos(2)),round(duplicated_pos(1))) = new_obj_num;
%     new_gen_obj = [new_gen_obj, new_obj_num];
% end




