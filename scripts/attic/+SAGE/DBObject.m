classdef DBObject < handle
    % The DBObject class represents unique objects in a SAGE database.
    % It should not be instantiated directly, but rather from one of its sub-classes.
    
    properties (SetAccess=immutable)
        % The database and identifier of any DBObject instance are not allowed to change.
        db
        id
    end
    
    properties
        name    % It is assumed that all DBObject sub-classes will have a 'name' property.
                % If this is not the case then the 'name' field should be removed from the 
                % 'updatableFields' property by the sub-class's constructor.
    end
    
    properties (Access=private)
        dbSavepoint     % Used for rollback/commit.
    end
    
    properties (Access=protected)
        tableName                   % The SAGE table name to which a DBObject sub-class maps.
        updatableFields = {'name'}  % A cell array of property names that can be updated by the update() method.
                                    % Sub-classes can add additional names in their constructor.
    end
    
    
    methods
        
        function obj = DBObject(db, id, name)
            % Create an instance of a new DB object.
            
            % TODO: cache instances by ID and return those instead of creating new ones.
            %       The cache would need to get cleaned up in remove().
            
            % Check the arguments.
            if nargin ~= 3
                error('SAGE:Error', 'Wrong number of argument used to create an DBObject.');
            end
            if ~isscalar(id) || ~strncmp(class(db), 'com.mysql.jdbc.JDBC4Connection', length('com.mysql.jdbc.JDBC4Connection'))
                error('SAGE:Error', 'The ''db'' argument used to create a database object must be a MySQL JDBC4Connection.')
            end
            if ~isscalar(id) || ~isinteger(id)
                error('SAGE:Error', 'The ''id'' argument used to create a database object must be a scalar integer.')
            end
            if size(name, 1) > 1 || ~ischar(name)
                error('SAGE:Error', 'The ''name'' argument used to create a database object must be a string.')
            end
            
            obj.db = db;
            obj.id = id;
            obj.name = name;
        end
        
        
        % TODO: add a fault (clear? delete?) method to allow local instances to be purged and refetched.
        
        
        function remove(obj)
            % Remove the object from the database.
            obj.executeSQL(['delete from ' obj.tableName ' where id=' num2str(obj.id)]);
        end
        
        
        %% Transaction support
        
        
        function beginChanges(obj)
            obj.db.setAutoCommit(false);
            obj.dbSavepoint = obj.db.setSavepoint([obj.tableName '.' obj.name]);
        end
        
        
        function undoChanges(obj)
            obj.db.rollback(obj.dbSavepoint);
            obj.dbSavepoint = [];
            obj.db.setAutoCommit(true);
        end
        
        
        function endChanges(obj)
            obj.db.commit();
            obj.db.setAutoCommit(true);
        end
        
        
        %% SQL execution methods
        
        
        function result = executeSQL(obj, sql)
            result = [];
            
            statement = obj.db.createStatement();
            try
                if statement.execute(sql) ~= 0
                    % TODO: any way to get an error message?
                    error('SAGE:Database:ExecuteSQLError', 'Could not execute SQL: %s', sql);
                else
                    sql = strtrim(sql);
                    if strncmpi(sql, 'select', 6)
                        % TODO: return the result set (requires executeQuery instead?)
                    elseif strncmpi(sql, 'insert', 5)
                        result = int64(statement.getLastInsertID());
                    end
                end
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
        
        %% Updating
        
        
        function update(obj, varargin)
            % Figure out which fields are to be updated.
            parser = inputParser;
            for field = obj.updatableFields
                parser. addParamValue(field{1}, []);
            end
            try
                parser.parse(varargin{:});
            catch ME
                if strcmp(ME.identifier, 'MATLAB:InputParser:UnmatchedParameter')
                    error('SAGE:Database:Error', 'Cannot update %s ''%s'': unknown field name: %s.', obj.tableName, obj.name, ME.message);
                else
                    rethrow(ME);
                end
            end
            
            % Build the query string.
            updates = '';
            for field = fieldnames(parser.Results)
                fieldName = field{1};
                fieldValue = parser.Results.(fieldName);
                if ~isempty(updates)
                    updates = [updates ', ']; %#ok<AGROW>
                end
                if ischar(fieldValue)
                    updates = [updates fieldName '=''' fieldValue '''']; %#ok<AGROW>
                elseif isnumeric(fieldValue)
                    updates = [updates fieldName '=' num2str(fieldValue)]; %#ok<AGROW>
                else
                    error('SAGE:Database:Error', 'Cannot update %s ''%s'': unsupported field type: %s', obj.tableName, obj.name, class(fieldValue));
                end
                    
            end
            
            % Update the database.
            obj.executeSQL(['update ' obj.tableName ' set ' updates ' where id=' num2str(obj.id)]);
            
            % Update this instance.
            obj.(fieldName) = fieldValue;
        end
        
        
        % TODO: get this working, but currently it gets unnecessarily called during the constructor.
%         function set.name(obj, name)
%             obj.update('name', name);
%         end
        
    end
    
end