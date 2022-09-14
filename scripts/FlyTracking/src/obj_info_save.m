function fname = obj_info_save(obj_info,numFrames)
% fname = obj_info_save(obj_info)
% Serialize obj_info. Filename returned in fname.

global file_index
global saveFrameNum
global outputDir

file_index = file_index + 1;

% transform obj_info into serialized form.

info = obj_info; % info struct to be serialized

% resize fields based on number of objects
info.start_frame = info.start_frame(1:info.obj_num);
info.end_frame = info.end_frame(1:info.obj_num);
info.data = info.data(1:info.obj_num);
info.x = info.x(1:info.obj_num);
info.y = info.y(1:info.obj_num);

% For vectors in .data, .x, .y fields, we save only the non-zero, "real"
% data. Recall that eg info.data{i} is currently a vector of size
% saveFrameNum (based on how it was constructed). For eg a track that
% existed only part of the time during the frames covered by this obj_info,
% only a certain subset of that vector will be real data.
startFrmIdxForThisFile = (file_index-1)*saveFrameNum + 1;
endFrmIdxForThisFile = min(file_index*saveFrameNum,numFrames);
assert(all(1<=info.start_frame(:) & info.start_frame(:)<=endFrmIdxForThisFile));
assert(all(1<=info.end_frame(:) & info.end_frame(:)<=endFrmIdxForThisFile));

% objStartIdxs are in range [1,saveFrameNum]. Objects with objStartIdxs==1
% may have started before startFrmIdxForThisFile.
objStartIdxs = max(info.start_frame-startFrmIdxForThisFile+1,1);

% objEndIdxs are in range [-startFrmIdxForThisFile+2,saveFrameNum]. Objects
% with objEndIdxs<=0 ended before the frames covered by this obj_info.
objEndIdxs = info.end_frame - startFrmIdxForThisFile + 1;
            
for i=1:info.obj_num
    if objEndIdxs(i) <= 0
        % object ended before frames covered by this obj_info.
        
        % check integrity of obj_info
        assert(all(info.data{i})==0);
        assert(all(info.x{i})==0);
        assert(all(info.y{i})==0);
        
        info.data{i} = [];
        info.x{i} = [];
        info.y{i} = [];
    else
        idxs = objStartIdxs(i):objEndIdxs(i);
        inverseIdxs = [(1:objStartIdxs(i)-1) (objEndIdxs(i)+1:numel(info.data{i}))];

        % check integrity of obj_info
        assert(all(info.data{i}(inverseIdxs)==0));
        assert(all(info.x{i}(inverseIdxs)==0));
        assert(all(info.y{i}(inverseIdxs)==0));        
        
        info.data{i} = info.data{i}(idxs);
        info.x{i} = info.x{i}(idxs);
        info.y{i} = info.y{i}(idxs);
    end
end

%% save to file
fname = sprintf('%s%sinfo%s',outputDir,filesep,num2str(file_index));
save(fname,'info');
