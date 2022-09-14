function obj_info = obj_info_load(obj_info,numFrames,outputDir,...
                                  file_index,saveFrameNum)
% fname = obj_info_load(obj_info,numFrames,outputDir,file_index,saveFrameNum)
% Load serialized obj_infos and combine into a single obj_info. This
% only modifies certain fields in the obj_info.

% The following are the fields to be replaced by loading
obj_info.num_active = [];
obj_info.data = cell(1,obj_info.obj_num); % obj_info.obj_num is now final
obj_info.x = cell(1,obj_info.obj_num);
obj_info.y = cell(1,obj_info.obj_num);

for j=1:file_index
    tmp = load([outputDir filesep 'info' num2str(j)]);
    info = tmp.info;
    
    % num_active
    if j < file_index
        assert(numel(info.num_active)==saveFrameNum);
    else
        assert(numel(info.num_active)==rem(numFrames,saveFrameNum));
    end
    obj_info.num_active = [obj_info.num_active info.num_active];
    
    for objIdx=1:obj_info.obj_num
        if objIdx <= info.obj_num && numel(info.data{1,objIdx})>0
            obj_info.data{1,objIdx} = [obj_info.data{1,objIdx} info.data{1,objIdx}];
            obj_info.x{1,objIdx} = [obj_info.x{1,objIdx} info.x{1,objIdx}];
            obj_info.y{1,objIdx} = [obj_info.y{1,objIdx} info.y{1,objIdx}];
        end
    end    
end
