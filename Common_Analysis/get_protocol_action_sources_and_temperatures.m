function [protocol, action_sources, temperatures] = get_protocol_action_sources_and_temperatures(box_data_folder_path, experiment_name)
    experiment_folder_path = fullfile(box_data_folder_path, experiment_name) ;
    experiment_file_name = fullfile(experiment_folder_path, [experiment_name '.exp']) ;
    data = load(experiment_file_name, '-mat') ;
    experiment_data = data.experiment ;
    action_sources = experiment_data.actionsource ;
    action_list = experiment_data.actionlist ;
    temperature_count = length(action_sources);    
    if temperature_count == 0 ,
        error('Experiment %s has no actions/temperatures in it', experiment_name) ;
    end
    
    temperatures = zeros(1, temperature_count) ;
    for i = 1 : temperature_count ,
        action_source = action_sources(i) ;
        if i==1 ,
            protocol = action_list(action_source).name ;  % same in all phases
        end
        temperatures(i) = action_list(action_source).T ;        
    end    
end