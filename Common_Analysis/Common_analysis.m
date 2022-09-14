function seq_analysis = Common_analysis(seq_info)
    % function A = common_analysis(I)
    % This function computes common statistics for any sequence's analysis info.
    
    if (length(seq_info.median_vel) > 1)
        % There is data for this tube.
        
        seq_analysis.mov_frac         = nanmean(seq_info.moving_fraction); % average number of flies moving per frame
        seq_analysis.max_mov_frac     = nanmax(seq_info.moving_fraction);  % maximum number of flies moving per frame
        seq_analysis.med_vel          = nanmean(seq_info.median_vel);      % median speed
        seq_analysis.max_vel          = nanmax(seq_info.median_vel);       % maximum speed
        seq_analysis.Q3_vel           = nanmean(seq_info.Q3_vel);          % mean 75th percentile velocity
        seq_analysis.tracked_num      = nanmean(seq_info.tracked_num);     % mean number of flies tracked
        seq_analysis.max_tracked_num  = nanmax(seq_info.tracked_num);      % maximum number of flies tracked
        seq_analysis.moving_num_left  = seq_info.moving_num_left;          % number of flies moving left
        seq_analysis.moving_num_right = seq_info.moving_num_right;         % number of flies moving right
        seq_analysis.moving_num       = seq_info.moving_num;               % number of flies moving left or right

        % The minimum number of flies tracked is computed more carefully.
        if isempty(seq_info.tracked_num)
            seq_analysis.min_tracked_num = NaN;
        elseif length(seq_info.tracked_num) == 1,
            seq_analysis.min_tracked_num = seq_info.tracked_num;
        else
            % ignore the last frame as it's often (always?) zero
            seq_analysis.min_tracked_num = nanmin(seq_info.tracked_num(1:end-1));
        end
        
        % Copies of time series for plotting.
        seq_analysis.mov_frac_ts     = seq_info.moving_fraction;
        seq_analysis.tracked_num_ts  = seq_info.tracked_num;  
    else
        % There is no data for this tube so populate all fields with zero.
        seq_analysis = [];
        seq_analysis = set_field_to_zero(seq_analysis, ...
        {'mov_frac', 'max_mov_frac', 'med_vel', 'max_vel', 'Q3_vel', 'tracked_num', 'moving_num_left', 'moving_num_right', 'moving_num', 'max_tracked_num', 'min_tracked_num', 'mov_frac_ts', 'tracked_num_ts'});
    end
end