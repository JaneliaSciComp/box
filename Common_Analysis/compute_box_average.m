% compute_box_average.m

% this script is simply for presentation and quick searching of the data
% averaged across the 6 tubes. Not all of the analysis results appear here.
% The summary of all tubes containing flies is placed as the 7th tube!

% create a separate function that will just make averages of the fields
% asked for, only doing so for non-empty tubes.

% seq2, compute average of:
% seq2.average_ts_med_vel, seq2.long_after_med_vel, seq2.startle_resp, seq2.baseline_mov_frac

% seq3, compute average of:
% seq3.mov_frac and seq3.mean_motion_resp. From this compute seq3.std_motion_res and seq3.motion_resp_diff

% seq4, compute average of:
% seq4.mov_frac and seq4.med_disp_x, From this compute seq4.disp_norm_max,
% or compute as average of the individual scores (w. std)...max is not
% linear so these will be different

% seq5, compute average of:
% seq5.mov_frac and seq5.disp_peak, From this compute
% seq5.disp_peak_SE, seq5.UVG_cross, seq5.UVG_pref_diff
% or compute as average of the individual scores (w. std)...nonlinear so these will be different



