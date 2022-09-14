function process_frame(I_curr_in, index)

global outputDir;
global I_label;
global I_obj_prob;
global I_curr;
global I_bg;
global I_bg_top;
global I_bg_bottom;
global I_occlud;
global pre_last_obj_pos;
global pre_last_obj_ind;
global last_obj_pos;
global last_obj_ind;
global obj_info;
global predict_pos;
global max_obj_num;
global props1d; 
global props2d;
global obj_length;
global new_obj_pos;
global obj_orient;
global obj_data;
global colors;
global numFrames;
global displayTracking;
global file_index;
global frame_index;

if (mod(frame_index, 500) == 0)
    disp(['processing frame ' num2str(frame_index)]);
end

I_curr = I_curr_in;

if( size(I_curr,3)>1 )
    I_curr = rgb2gray(I_curr);
end

[I_label, I_obj_prob] = candidate_objects(I_curr,I_bg,I_occlud,I_bg_top,I_bg_bottom);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% get predicted object position
[predict_pos, predict_ind] = predict_obj_pos(pre_last_obj_pos,pre_last_obj_ind,last_obj_pos,last_obj_ind);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% combine the candidate object info and the predicted
%%% positions of objects
[I_label,candidate_num] = predict_candidate(I_label,I_obj_prob,predict_pos,predict_ind,max_obj_num);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% get object properties
props2d = regionprops(I_label,'Centroid');    
props1d = regionprops(I_label,'Orientation','MajorAxisLength');    
%%%% go over centroids, kill line ellipses and place the centroids in an array
[new_obj_pos,obj_length,obj_orient] = get_centroids(props2d,props1d);
%obj_length = 18;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% track objects
%%%% match previous positions with the new positions. 
%%%% update the label image accordingly
%%%% track_obj assigns only one old obj to each new one so we have
%%%% merged objects.
obj_data = obj_orient;
[new_obj_pos, new_obj_ind, obj_data] = track_obj(last_obj_pos, last_obj_ind, new_obj_pos,...
    obj_length, predict_pos, obj_data, max_obj_num);

if isempty(obj_data)
    return
else
    obj_info = update_obj_info(obj_info, new_obj_pos, new_obj_ind, frame_index, index, obj_length, obj_data);
end

if( displayTracking )
    I_mark = gen_output_image(I_label,colors,I_curr,new_obj_pos(:,1),new_obj_pos(:,2));
    figure(333); 
    title(['processed frame ' num2str(frame_index) ' out of ' num2str(numFrames)]);
    imshow(I_mark); 
else
    %waitbar(frame_index/numFrames);   
end
pre_last_obj_pos = last_obj_pos;
pre_last_obj_ind = last_obj_ind;
last_obj_pos = new_obj_pos;
last_obj_ind = new_obj_ind;

%% no need for the next section, since the last_obj_pos and
%% pre_last_obj_pos don't have to be of the same size and are already with
%% only non-zero elements

% if( size(pre_last_obj_pos,1) < size(last_obj_pos,1) ) %% new object were found
%     if (size(pre_last_obj_pos,1) == 0)
%         pre_last_obj_pos = [];
%         pre_last_obj_ind = [];
%     else 
%         for i=1:size(pre_last_obj_ind,2)
%             ind = find(last_obj_ind == pre_last_obj_ind(i));
%             if (numel(ind) == 0)
%                 pre_last_obj_pos(i,:) = 0;
%             end
%         end
%         %% keep only the tracked objects
%         pre_last_tracked = find(pre_last_obj_pos(:,1));
%         pre_last_obj_pos = pre_last_obj_pos(pre_last_tracked,:);
%         pre_last_obj_ind = pre_last_obj_ind(pre_last_tracked);
%     end
% end



%%% save the obj_info every saveFrameNum frames
saveFrameNum = 500;
if( (mod(frame_index,saveFrameNum)==0) & (numFrames ~= frame_index))
    
    file_index = file_index + 1;
    
    %%% resizing the obj_info fields now that we know how many objects we have
    info = obj_info;
    num_obj = info.obj_num;    
    info.start_frame = info.start_frame(1:num_obj);
    info.end_frame = info.end_frame(1:num_obj);
    data = cell(1,num_obj);
    x = data;
    y = data;
    start_frame = max(info.start_frame,(file_index-1)*saveFrameNum+1) - (file_index-1)*saveFrameNum;
    end_frame = info.end_frame - (file_index-1)*saveFrameNum;
    

    for i=1:num_obj
        if( end_frame(i) <= 0 )
            data{i} = [];
            x{i} = [];
            y{i} = [];
        else
            data{i} = info.data{i}(start_frame(i):end_frame(i));
            x{i} = info.x{i}(start_frame(i):end_frame(i));
            y{i} = info.y{i}(start_frame(i):end_frame(i));
        end
    end
    info.data = data;
    info.x = x;
    info.y = y;
    
    %% saving the info to file
    str = sprintf('%s%sinfo%s',outputDir, filesep, num2str(file_index) );
    save(str,'info');
    
    % save([outputDir '/results/info' num2str(file_index)],'info');
    % save(['results/info' num2str(file_index)],'info');
    

    %%% getting the next portion of frames for the new obj_info
    if  ((numFrames - (file_index*saveFrameNum)) > saveFrameNum)
        partial_numFrames = saveFrameNum;
    else 
        partial_numFrames = numFrames - (file_index*saveFrameNum);
    end
    
    %%%% new obj_info - only the num_active, data, x and y fileds get
    %%%% renewed so that we wouldn't loose information for the objects that
    %%%% are still tracked (it is easier this way instead of renewing all
    %%%% the fields and trying to keep track of the indexes where the still
    %%%% tracked obj were in all the previously saved infos)
    obj_info.num_active = zeros(1, partial_numFrames);
    n=size(obj_info.data,2);
    obj_info.data = mat2cell(zeros(n,partial_numFrames),ones(1,n),partial_numFrames)';
    obj_info.x = obj_info.data;
    obj_info.y = obj_info.data;
end    

