function result = load_anonymous(file_name)
    % Load a mat file with a single variable in it, in a way that leads to
    % more readable, explicit code.

    s = load(file_name, '-mat') ;
    field_names = fieldnames(s) ;
    if isscalar(field_names) ,
        field_name = field_names{1} ;
        result = s.(field_name) ;        
    else
        error('More than one variable in %s', file_name) ;
    end
end
