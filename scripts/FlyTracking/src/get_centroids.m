function   [obj_pos,median_obj_length, obj_orient] = get_centroids(props2d,props1d)

found_obj_num = length(props1d);

if( found_obj_num == 0 )
    obj_pos = zeros(0,2);
    median_obj_length = nan;
    obj_orient = zeros(0,1);
    return;
end

obj_length = 0;

obj_pos = zeros(found_obj_num,2);


props_array = cell2mat(struct2cell(props2d));
obj_pos = squeeze(props_array(1,:,:))';
obj_pos = reshape(obj_pos,2,found_obj_num)';

props_array = cell2mat(struct2cell(props1d));
f = fieldnames(props1d);
i_orient = find(strcmp(f,'Orientation'));
i_length = find(strcmp(f,'MajorAxisLength'));
obj_orient = squeeze(props_array(i_orient,:,:))';
obj_length = squeeze(props_array(i_length,:,:))';
% obj_orient = squeeze(props_array(1,:,:))';
% obj_length = squeeze(props_array(2,:,:))';

median_obj_length = median(obj_length);





return;













%%%%%%%%%%%%%%%%%%%%%%% Here are things I tried and fail to give good
%%%%%%%%%%%%%%%%%%%%%%% results

% non_obj_num = 0;
% for lb=1:found_obj_num,
%     %% check eccentricity (throw away line ellipses)
%     if( props(lb).Eccentricity > 0.995),
%         I_label(find(I_label==lb)) = 0;
%         non_obj_num = non_obj_num + 1;
%     end
%     %% check area (throw away too small ellipses)
%     if( props(lb).Area < 3),
%         I_new_label(find(I_label==lb)) = 0;
%         non_obj_num = non_obj_num + 1;
%         continue;
%     end
%     obj_pos(lb-non_obj_num,:) = props(lb).Centroid;
%     obj_orient(lb-non_obj_num,:) = props(lb).Orientation;
%     obj_length(lb-non_obj_num) = props(lb).MajorAxisLength;
% end


