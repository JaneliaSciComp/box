function obj_info = obj_info_construct(numObj,numFrm,firstFrm)
% obj_info = obj_info_construct(numObj,numFrm)
% Construct a new obj_info structure.
% numObj: scalar int. Maximum number of objects to be stored.
% numFrm: scalar int. Number of frames to be stored in this obj_info.

obj_info = struct();

obj_info.obj_num = 0; % current maximum object index ever used
obj_info.last_frame = 0; % last frame ever currently tracked (absolute index, not relative)
obj_info.first_frame = firstFrm;
obj_info.obj_length = nan;

% Note on frame-indexed quantities.
% The obj_info fields num_active, data, x, and y are indexed first by
% object number, then by frame. Since a single tracking session typically
% involves using/saving multiple obj_infos, numFrm is typically less than
% the total number of frames in the video sequence being tracked.
% Frame-indexed obj_info fields are therefore indexed by "relative frame"
% where an idx of 1 indicates the first frame covered by the obj_info.
% Serialized obj_infos involve a further twist (see xxx).

% Number of tracks active in each frame.
obj_info.num_active = zeros(1,numFrm);

% Data matrix for each tracked object. Currently, this data is a vector 
% with the object orientation per frame.
obj_info.data = cell(1,numObj);

% X coordinate for each tracked object.
obj_info.x = cell(1,numObj);

% Y coordinate for each tracked object.
obj_info.y = cell(1,numObj);

for i = 1:numObj
    obj_info.data{1,i} = zeros(1,numFrm);
    obj_info.x{1,i} = zeros(1,numFrm);
    obj_info.y{1,i} = zeros(1,numFrm);
end

% The fields start_frame and end_frame record the *absolute* start/end
% frame index for a track. Note however that serialized obj_infos may not
% have a fully updated end_frame value (see xxx).
obj_info.start_frame = zeros(1,numObj);
obj_info.end_frame = zeros(1,numObj);
