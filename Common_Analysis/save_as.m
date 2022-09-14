function save_as(file_name, variable_name, value)  %#ok<INUSD>
    % Save the value to the mat file file_name, as a variable with name
    % variable_name.
    %
    % Allows for saving in a way that works better with statis code analysis.
    
    eval(sprintf('%s = value ;', variable_name)) ;
    save('-mat', file_name, variable_name) ;
end
