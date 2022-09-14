
function [analysis_info] = analysis_olympiad(obj_info, pix_to_mm, frame_rate, move_thresh, boundaries);

%%% Given object position output average distance (in pixels) 
%%%   traveled at each frame
%%% This is modified from Lihi's version to satisfy needs of Olympiad
%%% project, in particular we need positions along the tubes

global trackedFrames;

if( nargin < 4 )
    move_thresh = 1;
end
if( nargin >=5 )
    x_min = boundaries(1);
    x_max = boundaries(2);
    y_min = boundaries(3);
    y_max = boundaries(4);
else
    x_min = 0; x_max = 9E9; y_min = 0; y_max = 9E9;
end

%%% clean obsolete objects
actual_obj_ind = find(obj_info.end_frame>0);
obj_info.obj_num = length(actual_obj_ind);
obj_info.x = obj_info.x(actual_obj_ind);
obj_info.y = obj_info.y(actual_obj_ind);
obj_info.data = obj_info.data(actual_obj_ind);
obj_info.start_frame = obj_info.start_frame(actual_obj_ind);
obj_info.end_frame = obj_info.end_frame(actual_obj_ind);

image_width = x_max - x_min;
image_height = y_max - y_min;

obj_num = obj_info.obj_num;
start_frame = obj_info.start_frame(1);
frame_num = obj_info.last_frame-start_frame+1;
frameIndices = [start_frame:obj_info.last_frame];

trackedFrames(1:obj_num,1:frame_num) = -1;
for i=1:obj_num
    trackedFrames(i,1:(obj_info.end_frame(i)-obj_info.start_frame(i)+1)) = ...
            [obj_info.start_frame(i):obj_info.end_frame(i)];
end

analysis_info.avg_vel_x = zeros(1,frame_num);
analysis_info.avg_vel_y = zeros(1,frame_num);
analysis_info.avg_vel = zeros(1,frame_num);
analysis_info.median_vel_x = zeros(1,frame_num);
analysis_info.median_vel_y = zeros(1,frame_num);
analysis_info.median_vel = zeros(1,frame_num);
analysis_info.Q1_vel = zeros(1,frame_num);
analysis_info.Q3_vel = zeros(1,frame_num);
analysis_info.tracked_num = zeros(1,frame_num);
analysis_info.moving_fraction = zeros(1,frame_num);
analysis_info.moving_num = zeros(1,frame_num);
analysis_info.avg_mov_vel = zeros(1,frame_num);
analysis_info.ang_vel = zeros(1,frame_num);
analysis_info.mutual_dist = zeros(1,frame_num);
analysis_info.mutual_dist_180 = zeros(1,frame_num);
analysis_info.start_move_num = zeros(1,frame_num);
analysis_info.pos_hist = zeros(101, frame_num);
analysis_info.move_pos_hist = zeros(101, frame_num);


X_vect = x_min:(image_width/100):x_max;

max_tracked_num = 0;
tracked_ind = [1,2];
distance = 0;
moving_ind = [];
[X_curr,Y_curr] = get_obj_coords(obj_info, frameIndices(1));
[X_next,Y_next] = get_obj_coords(obj_info, frameIndices(2));
for f=1:frame_num-1
    if( f<frame_num-1 )
        [X_next_next,Y_next_next] = get_obj_coords(obj_info, frameIndices(f+2));
        dx_next = X_next_next - X_next;
        dy_next = Y_next_next - Y_next;
    else
        X_next_next = X_next;
        Y_next_next = Y_next;
    end
    
    %%% we consider only of objects within boundaries
    outside_roi = find((X_next<x_min) | (X_next>x_max) | ...
        (Y_next<y_min) | (Y_next>y_max) );
    X_next(outside_roi) = 0;
    Y_next(outside_roi) = 0;
    
    %%% find number of tracked objects in current frame
    prev_tracked_ind = tracked_ind;
    tracked_ind = find(X_curr & X_next);
    analysis_info.tracked_num(f) = length(tracked_ind);
    if ((numel(tracked_ind) == 0))% | (length(tracked_ind) < (1/2*max_tracked_num)))
        dx = dx_next;
        dy = dy_next;
        X_curr = X_next;
        Y_curr = Y_next;
        X_next = X_next_next;
        Y_next = Y_next_next;
        continue;
    end
    if (max_tracked_num < analysis_info.tracked_num(f))
        max_tracked_num = analysis_info.tracked_num(f); 
    end
            
    %%% mutual distance    
    obj_pos = [X_curr(tracked_ind),Y_curr(tracked_ind)];
    d = dist2(obj_pos,obj_pos);
    d = triu(d.^0.5);
    ind = find(d);
    if( numel(ind) )
        analysis_info.mutual_dist(f) = mean(d(ind));
    end
    %%% mutual distance, trajectories rotated 180 degrees
    obj_pos = [image_height-X_curr(tracked_ind(1)),image_width-Y_curr(tracked_ind(1))];
    obj_pos = [obj_pos;[X_curr(tracked_ind(end)),Y_curr(tracked_ind(end))]];
    d = dist2(obj_pos,obj_pos);
    d = triu(d.^0.5);
    ind = find(d);
    if( numel(ind) )
        analysis_info.mutual_dist_180(f) = mean(d(ind));
    end
    
    %%% velocity
    prev_distance = distance;
    dx = X_next(tracked_ind) - X_curr(tracked_ind);
    dy = Y_next(tracked_ind) - Y_curr(tracked_ind);    
    distance = (dx.^2 + dy.^2) .^ (1/2);    
    analysis_info.avg_vel_x(f) = mean(dx);
    analysis_info.avg_vel_y(f) = mean(dy);
    analysis_info.avg_vel(f) = mean(distance);
 
    analysis_info.median_vel_x(f) = median(dx);
    analysis_info.median_vel_y(f) = median(dy);
    analysis_info.median_vel(f) = median(distance);
    
    sort_vels = sort(distance);
    % compute 25th percentile (first quartile)
    analysis_info.Q1_vel(f) = median(sort_vels(find(sort_vels<median(sort_vels))));
    
    % compute 75th percentile (third quartile)
    analysis_info.Q3_vel(f) = median(sort_vels(find(sort_vels>median(sort_vels))));
    
    %%% moving number/percentage
    prev_moving_ind = moving_ind;
    moving_ind = find(distance > move_thresh);
    rest_ind = find(distance <= move_thresh);
    moving_num(f) = length(moving_ind);
    analysis_info.moving_fraction(f) = moving_num(f)/analysis_info.tracked_num(f);
    analysis_info.moving_num(f) = moving_num(f);
    if( moving_num(f) ~= 0 )
        analysis_info.avg_mov_vel(f) = mean(distance(moving_ind));
    end
    
    %%% collect probability for each pixel position
    x = min(floor(X_curr(tracked_ind))+1,image_width);
%    plot(hist(x, X_vect))

    analysis_info.pos_hist(:,f) = hist(x, X_vect); % collect a histogram of all centroid locations along the X direction
    
    analysis_info.move_pos_hist(:,f) = hist(x(moving_ind), X_vect);
    
    %%% start moving number
    if( f > 1 )
        if( moving_num(f) > moving_num(f-1) ),
            %% check that we're still tracking the same objects
            if( isequal(tracked_ind, prev_tracked_ind) ),
                analysis_info.start_move_num(f) = moving_num(f) - moving_num(f-1);   
            end
        end
    end
        
    %%% angular velocity
    dx_next = X_next_next(tracked_ind) - X_next(tracked_ind);
    dy_next = Y_next_next(tracked_ind) - Y_next(tracked_ind);  
    theta_curr = atan2(dy,dx);
    theta_next = atan2(dy_next, dx_next);
    analysis_info.ang_vel(f) = mean(theta_next - theta_curr);
    
    %%% update variables
    dx = dx_next;
    dy = dy_next;
    X_curr = X_next;
    Y_curr = Y_next;
    X_next = X_next_next;
    Y_next = Y_next_next;
end

analysis_info.avg_vel_x = analysis_info.avg_vel_x * pix_to_mm * frame_rate;
analysis_info.avg_vel_y = analysis_info.avg_vel_y * pix_to_mm * frame_rate; 
analysis_info.avg_vel = analysis_info.avg_vel * pix_to_mm * frame_rate;
analysis_info.median_vel_x = analysis_info.median_vel_x * pix_to_mm * frame_rate;
analysis_info.median_vel_y = analysis_info.median_vel_y * pix_to_mm * frame_rate;
analysis_info.median_vel = analysis_info.median_vel * pix_to_mm * frame_rate;
analysis_info.Q1_vel = analysis_info.Q1_vel * pix_to_mm * frame_rate;
analysis_info.Q3_vel = analysis_info.Q3_vel * pix_to_mm * frame_rate;

analysis_info.avg_mov_vel = analysis_info.avg_mov_vel * pix_to_mm * frame_rate;
analysis_info.max_tracked_num = max_tracked_num;
% not in original code--but it muist be there, no?
analysis_info.ang_vel = analysis_info.ang_vel * frame_rate;



