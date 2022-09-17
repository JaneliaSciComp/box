classdef Clause < handle
    % Queries are constructed from Clause objects.  
    % A clause can be a direct field comparison or it can group other clauses together.
    
	properties
		type = '';
        fieldName = '';
        comparison = '';
        value = [];
	end
	
	methods
        
        function obj = Clause(type, varargin)
            % Create a query clause.  The convenience functions SAGE.Query.Compare, SAGE.Query.All and SAGE.Query.Any should be used instead.
            
            % Error checking of the parameters is done in the convenience functions.
            
            obj.type = type;
            
            if strcmp(type, 'Compare')
                obj.fieldName = varargin{1};
                obj.comparison = varargin{2};
                obj.value = varargin{3};
            elseif strcmp(type, 'All')
                obj.value = varargin(:);
            elseif strcmp(type, 'Any')
                obj.value = varargin(:);
            else
                error('SAGE:Query:InvalidClauseType', 'Unknown query clause type ''%s'' (must be one of ''Compare'', ''All'', ''Any''', type);
            end
        end
        
        
		function str = toString(obj)
            % Convert this clause and any sub-clauses into a string format.
            
            if strcmp(obj.type, 'Compare')
                if isnumeric(obj.value)
                    str = [obj.fieldName obj.comparison num2str(obj.value)];
                else
                    str = [obj.fieldName obj.comparison obj.value];
                end
            elseif strcmp(obj.type, 'All')
                if length(obj.value) == 1
                    str = obj.value{1}.toString();
                else
                    str = '(';
                    for i = 1:length(obj.value)
                        if i == 1
                            str = [str obj.value{i}.toString()]; %#ok<AGROW>
                        else
                            str = [str '&' obj.value{i}.toString()]; %#ok<AGROW>
                        end
                    end
                    str = [str ')'];
                end
            elseif strcmp(obj.type, 'Any')
                if length(obj.value) == 1
                    str = obj.value{1}.toString();
                else
                    str = '(';
                    for i = 1:length(obj.value)
                        if i == 1
                            str = [str obj.value{i}.toString()]; %#ok<AGROW>
                        else
                            str = [str '|' obj.value{i}.toString()]; %#ok<AGROW>
                        end
                    end
                    str = [str ')'];
                end
            end
        end
        
        
        function names = queriedFieldNames(obj)
            % Return a cell array containing the names of fields queried by this clause or any sub-clause.
            
            if strcmp(obj.type, 'Compare')
                names = {obj.fieldName};
            else
                names = {};
                for i = 1:length(obj.value)
                    subFields = obj.value{i}.queriedFieldNames();
                    names = vertcat(names, subFields); %#ok<AGROW>
                end
            end
        end
		
	end

end