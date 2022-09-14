function   [predict_pos, predict_ind] = predict_obj_pos(pre_last_obj_pos,...
    pre_last_obj_ind, last_obj_pos, last_obj_ind);

%% predict object positions based on previous path
% predict_pos      - the predicted positions (obj_num x 2) array where
%                    the first column holds x position and the second holds
%                    the y position


%% if less than 4 arguments the indexes are not needed, so i keept the old verion
%% of the code
if (nargin < 4)
    
    last_obj_pos = pre_last_obj_ind;
    
    %% initialization
    obj_num = size(last_obj_pos,1);
    predict_pos = zeros(obj_num,2);

    %% if it is the first frame there is no prediction
    %% if it is the second frame, predict objects are stationary
    if( numel(last_obj_pos)==0 & numel(pre_last_obj_pos)==0 ),
        return;
    elseif( numel(last_obj_pos)>0 & numel(pre_last_obj_pos)==0 ),
        predict_pos = last_obj_pos;
        return;
    end

    %% predict positions assuming the local motion is on a straight path

    X = [pre_last_obj_pos(:,1),last_obj_pos(:,1)];
    Y = [pre_last_obj_pos(:,2),last_obj_pos(:,2)];

    %% a new object without previous position is assigned
    %% a prediction to stay in place
    new_obj = find(X(:,1) == 0 | Y(:,1) == 0);
    if( numel(new_obj)>0 )
        X(new_obj,1) = X(new_obj,2);
        Y(new_obj,1) = Y(new_obj,2);
    end
    %%% predicted position along a linear path
    predict_pos(:,1) = X(:,2) + (X(:,2)-X(:,1));
    predict_pos(:,2) = Y(:,2) + (Y(:,2)-Y(:,1));
    
    return;

end

%%% if more than 4 arguments, use the indexes


%% initialization
obj_num = size(last_obj_pos,1);
predict_pos = zeros(obj_num,2);
predict_ind = last_obj_ind;

%% if it is the first frame there is no prediction
%% if it is the second frame, predict objects are stationary
if( numel(last_obj_pos)==0 & numel(pre_last_obj_pos)==0 ),
    return;
elseif( numel(last_obj_pos)>0 & numel(pre_last_obj_pos)==0 ),
    predict_pos = last_obj_pos;
    return;
end

%% predict positions assuming the local motion is on a straight path


%% find the objects still tracked

X(:,2) = last_obj_pos(:,1);
Y(:,2) = last_obj_pos(:,2);

%% get the pre_last_obj_pos only for the objects still tracked 
%% (the objects in the last_obj_pos)
for i=1:obj_num
    ind = find(pre_last_obj_ind == last_obj_ind(i));
    if (numel(ind))
        X(i,1) = pre_last_obj_pos(ind,1);
        Y(i,1) = pre_last_obj_pos(ind,2);
    end
end


%% a new object without previous position is assigned
%% a prediction to stay in place
new_obj = find(X(:,1) == 0 | Y(:,1) == 0);
if( numel(new_obj)>0 )
    X(new_obj,1) = X(new_obj,2);
    Y(new_obj,1) = Y(new_obj,2);
end


%%% predicted position along a linear path
predict_pos(:,1) = X(:,2) + (X(:,2)-X(:,1));
predict_pos(:,2) = Y(:,2) + (Y(:,2)-Y(:,1));



return;




%%%% This part is currently not used.
%%%% Might be used in the future
% I_predict_prob,  - hold the probability of each pixel to be an object
%                    pixel
% I_predict_label  - the most probable label of each pixel (for objects
%                    which merge we will have just one of the labels)
I_predict_label = zeros(im_dim);
I_predict_prob = ones(im_dim);

I_predict_prob = zeros(im_dim);
for i=1:obj_num,
    %%% Mark region in the predicted_label image with the object label
    %%% we currently mark square objects
    %%% this should be changed to circular/ellipse
    I_predict_label = mark_square_object(predict_pos(i,2),predict_pos(i,1),i,I_predict_label);
    %%% Mark object region in the probablity image, currently with prob 1
    %%% in the whole object region
    %%% This should be changed to gaussian prob around the predicted
    %%% position
    I_predict_prob = mark_square_object(predict_pos(i,2),predict_pos(i,1),1,I_predict_prob);
end

