function [obj_info] = post_main(outputDir, inputFile, bgFile);

%%% load final object positions 
str = sprintf('%s%strack_info',outputDir, filesep);
load(str);


I_bg = imread(bgFile);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% find region of interest
% changed by MBR to just load the defined file instead of looking for it
% again - 
%[I_roi] = find_roi(I_bg);

temp_roi_file_name = [outputDir filesep 'roi.bmp'];
I_roi = imread(temp_roi_file_name);   %$ put a try, catch here

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% Post-processing.
%%%% Concatante tracks of objects lost along boundaries and 
%%%% objects that merged/separted with/from other objects
[obj_info] = traj_post_process(obj_info,I_roi);


%%% save final object positions into a file named obj_pos in the output
%%% directory
str = sprintf('%s%strack_info_upd',outputDir, filesep);
save(str,'obj_info');

