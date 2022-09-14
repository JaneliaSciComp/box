function result = gather_analysis_feature(data_for_some_experiments, num_conditions, seq_name, analysis_feature_name) 
    experiment_count = length(data_for_some_experiments) ;    
    tube_count = total_tube_count(data_for_some_experiments) ;
    result = nan(tube_count, num_conditions) ;
    row_index = 1  ;
    for i = 1:experiment_count ,
        for tube_index = data_for_some_experiments(i).tubes,
            result(row_index,:) = ...
                data_for_some_experiments(i).analysis_results(tube_index).(seq_name).(analysis_feature_name)(:)';
            row_index = row_index + 1 ;
        end
    end
end
