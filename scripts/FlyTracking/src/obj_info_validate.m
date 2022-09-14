function obj_info_validate(obj_info,curFrm,fileIdx,saveFrameNum)
% obj_info_validate(obj_info,curFrm)
% Validate complete obj_info.

validateattributes(obj_info.obj_num,{'numeric'},{'nonnegative' 'integer'});
Nobj = obj_info.obj_num; 

assert(floor((curFrm-1)/saveFrameNum)==fileIdx);
curFrmRel = mod(curFrm-1,saveFrameNum)+1;

% first_frame, last_frame
assert(obj_info.first_frame==1);
assert(obj_info.last_frame==curFrm);

% start/end_frame (note, these are in absolute indices)
assert( numel(obj_info.start_frame)>=Nobj && all(obj_info.start_frame(Nobj+1:end)==0) );
assert( numel(obj_info.end_frame)>=Nobj && all(obj_info.end_frame(Nobj+1:end)==0) );
realstarts = obj_info.start_frame(1:Nobj);
realends = obj_info.end_frame(1:Nobj);
assert(all(1<=realstarts & realstarts<=curFrm));
assert(all(1<=realends & realends<=curFrm));
nFrmObj = realends-realstarts+1;
% nFrmObj(i) gives number of frames object i was alive
assert(all(nFrmObj>=1)); % checks that end_frame always comes at or after start_frame

% num_active indexed by RELATIVE frame index.
% data, x, y indexed by obj index, then RELATIVE frame index.
% relative frames covered by this obj_info are:
% fileIdx*saveFrameNum+1:(fileIdx+1)*saveFrameNum
assert( numel(obj_info.num_active)>=curFrmRel && all(obj_info.num_active(curFrmRel+1:end)==0) );
for iRel = 1:curFrmRel
    iAbs = iRel+fileIdx*saveFrameNum;
    tfActive = realstarts <= iAbs & iAbs <= realends; % tf for whether each track is active this frame
    assert(nnz(tfActive)==obj_info.num_active(iRel));    
end

% data/x/y
assert(isequal(size(obj_info.data),size(obj_info.x),size(obj_info.y)));
for objIdx = 1:Nobj
    assert(isequal(size(obj_info.data{objIdx}), ...
                   size(obj_info.x{objIdx}), ...
                   size(obj_info.y{objIdx})));
    nframes4obj = nnz(obj_info.x{objIdx}>0); % really, a lower bound for nframes for this object
    assert(nframes4obj<=nFrmObj(objIdx)); % nFrmObj(objIdx) could be greater, if the track extends beyond one obj_info
end
for objIdx = Nobj+1:numel(obj_info.data)
    assert(all(obj_info.data{objIdx}==0));
    assert(all(obj_info.x{objIdx}==0));
    assert(all(obj_info.y{objIdx}==0));
end
