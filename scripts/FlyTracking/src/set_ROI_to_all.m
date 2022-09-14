function I_roi = set_ROI_to_all(params, I_bg)
% this function sets the roi file to everything if not otherwise specified

% move to working directory
I_roi = ones(size(I_bg));

%save ROI_coords in the output dir
ROI_coords.Left = 1;
ROI_coords.Right = size(I_roi,1);
ROI_coords.Top = 1;
ROI_coords.Bottom = size(I_roi,2);
save([params.outputDir filesep 'ROI_coords'], 'ROI_coords'); 