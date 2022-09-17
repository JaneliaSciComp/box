function clause = Compare(fieldName, comparison, value)
    %% query = SAGE.Query.Compare(fieldName, comparison, value)
    % Select all records whose fields match the value using the comparison.
    % When querying a data set the fieldName should be the name of one of the fields returned by dataSet.fields().
    % Comparison should be one of '=', '<', '>' or '!='.
    % Value can be any character or numeric value.
    
    if ~ischar(fieldName) || isempty(regexp(fieldName, '^[a-z][a-z0-9_-]*$', 'once'))
        error('SAGE:Query:InvalidFieldName', '''%s'' is not a valid field name for a query (must be all lowercase characters or underscore).', fieldName);
    end
    if ~ischar(comparison) || ~any(strcmp({'=', '>', '<', '!='}, comparison))
        error('SAGE:Query:InvalidComparison', '''%s'' is not a valid comparison for a query (must be one of ''='', ''>'', ''<'' or ''!='').', comparison);
    end
    if ~(ischar(value) && isrow(value)) && ~(isscalar(value) && isnumeric(value))
        error('SAGE:Query:InvalidValue', 'The value to which a field is being compared must be a string or single numeric value.');
    end
    
    clause = SAGE.Query.Clause('Compare', fieldName, comparison, value);
end
