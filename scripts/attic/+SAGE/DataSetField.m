classdef DataSetField < handle
    % The DataSetField class represents a field (column) in a data set.
    %
    % >> fields = SAGE.Lab('olympiad').assay('box').dataSet('analysis_info').fields();
    % >> fields(1).name
    % 
    % ans = 
    % 
    % automated_pf 
    
    properties
        dataSet             % The data set that this field is part of.
        name                % The unique identifier of the data set.
        displayName = ''    % The human-readable name of the data set.
        description = ''    % A human-readable description of the data set useful in, for example, tooltips.
        dataType = 'char'   % The type of data stored in the field, e.g. "double", "char", etc.
        deprecated = false  % Whether or not this field has been deprecated and will soon be removed from the data set.
    end
    
    properties (Access = private)
        cvTerms = SAGE.CVTerm.empty(0, 0);
        termsFetched = false;
        fieldValues = {}    % A list of valid values for the field.
    end
    
    methods
        
        function obj = DataSetField(dataSet, name, displayName, description, dataType, deprecated)
            % Create a DataSetField object.
            obj.dataSet = dataSet;
            obj.name = name;
            if nargin > 2
                obj.displayName = displayName;
            end
            if nargin > 3
                obj.description = description;
            end
            if nargin > 4 && ~isempty(dataType)
                obj.dataType = dataType;
            end
            if nargin > 5 && ~isempty(deprecated)
                obj.deprecated = deprecated;
            end
        end
        
        
        function addValidValue(obj, value)
            if (strcmp(obj.dataType(1:3), 'int') || (length(obj.dataType) > 5 && strcmp(obj.dataType(1:6), 'bigint'))) && strcmp(num2str(str2double(value)), value)
                value = str2double(value);
            end
            obj.fieldValues = {obj.fieldValues{:}, value};
        end
        
        
        function values = validValues(obj)
            values = obj.fieldValues;
        end
        
    end
    
end
