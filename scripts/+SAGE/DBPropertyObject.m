classdef DBPropertyObject < SAGE.DBObject
    % The DBProperty class represents objects in the SAGE database that can have properties.
    % It should not be instantiated directly, but rather from one of its sub-classes.
    
    % TODO: Is it worth caching the value to avoid additional get queries?  Could use the faulting method...
    
    
    properties (SetAccess=immutable)    % TODO: allow the type to be changed.
        type
    end
    
    
    methods
        function obj = DBPropertyObject(db, id, name, type)
            if nargin ~= 4
                error('SAGE:PropertyObjects:Error', 'Wrong number of argument used to create a property-based object.');
            end
            if ~isscalar(type) || ~isa(type, 'SAGE.CVTerm')
                error('SAGE:PropertyObjects:Error', 'The type of a property-based object must be a SAGE.CVTerm.');
            end
            
            obj = obj@SAGE.DBObject(db, id, name);
            
            obj.type = type;
            
            % TODO: obj.updatableFields{end + 1} = 'type';
        end
        
        
        function setProperties(obj, varargin)
            % Set the values of the indicated property/value pairs.
            numPairs = length(varargin) / 2;
            if round(numPairs) ~= numPairs
                error('SAGE:PropertyObjects:Error', 'Pairs of CVTerms and strings must be passed to setProperties().');
            end
            
            typeIDs = '';
            values = '';
            for i = 1:numPairs
                propType = varargin{i * 2 - 1};
                propValue = varargin{i * 2};
                
                if ~isscalar(propType) || ~isa(propType, 'SAGE.CVTerm')
                    error('SAGE:PropertyObjects:Error', 'The type argument to setProperty() must be a SAGE.CVTerm.');
                end
                if size(propValue, 1) ~= 1 || ~ischar(propValue)
                    error('SAGE:PropertyObjects:Error', 'The value argument to setProperty() must be a string.');
                end
                
                if ~isempty(typeIDs)
                    typeIDs = [typeIDs ', ']; %#ok<AGROW>
                end
                typeIDs = [typeIDs propType.idQuery()]; %#ok<AGROW>
                if ~isempty(values)
                    values = [values ', ']; %#ok<AGROW>
                end
                values = [values '(' num2str(obj.id) ', ' propType.idQuery() ', ''' propValue ''')']; %#ok<AGROW>
            end
            
            % Insert the values, deleting any existing entries for the objects and types.
            % It would be cool if the "ON DUPLICATE KEY UPDATE" syntax could handle multiple rows, then we could have just one query.
            try
                obj.executeSQL(['delete from ' obj.tableName '_property where ' obj.tableName '_id = ' num2str(obj.id) ' and type_id in (' typeIDs ')']);
                obj.executeSQL(['insert into ' obj.tableName '_property (' obj.tableName '_id, type_id, value) values ' values]);
            catch ME
                error('SAGE:PropertyObjects:Error', 'Could not set the properties of %s %s: %s', obj.tableName, obj.name, ME.message);
            end
        end
        
        
        function setProperty(obj, type, value)
            % Set the value of the indicated property.
            
            obj.setProperties(type, value);
        end
        
        
        function v = getProperty(obj, type)
            % Return the value of the indicated property
            
            v = [];
            
            query = ['select value from ' obj.tableName '_property_vw where ' obj.tableName '_id = ' num2str(obj.id) ' and cv = ''' type.cv.name ''' and type = ''' type.name ''''];
            
            statement = obj.db.createStatement();
            try
                cursor = statement.executeQuery(query);
                try
                    if cursor.next()
                        v = char(cursor.getString(1));
                    end
                catch ME
                    cursor.close();
                    rethrow(ME);
                end
                cursor.close();
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
        
        function pl = properties(obj) %#ok<STOUT,MANU>
            % TODO: return a list of all properties of this object
            error('SAGE:Unimplemented', 'This method has not yet been implemented.');
        end
        
    end
    
end