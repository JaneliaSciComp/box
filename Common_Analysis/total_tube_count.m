function result = total_tube_count(data_for_some_experiments)
    tube_count_per_experiment = arrayfun(@tube_count_for_one_experiment, ...
                                         data_for_some_experiments) ;
    result = sum(tube_count_per_experiment) ;
end

function result = tube_count_for_one_experiment(data_for_one_experiment)
    result = length(data_for_one_experiment.tubes) ;
end
