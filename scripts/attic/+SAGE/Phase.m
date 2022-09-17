classdef Phase < SAGE.DBPropertyObject
    % The Phase class represents a part of an experiment run by a lab or group project.
    
    % TODO: examples
    
    
    properties (SetAccess=immutable)
        experiment
    end
    
    
    methods
        function obj = Phase(experiment, id, name, type)
            if nargin ~= 4
                error('SAGE:Phase:Error', 'Wrong number of argument used to create a Session object.');
            end
            
            if ~isscalar(experiment) || ~isa(experiment, 'SAGE.Experiment')
                error('SAGE:Phase:Error', 'The experiment used to create a phase must be a SAGE.Experiment instance.');
            end
            
            obj = obj@SAGE.DBPropertyObject(experiment.db, id, name, type);
            
            obj.tableName = 'phase';
            obj.experiment = experiment;
        end
        
        
        function storeData(obj, data, dataFormat, dataType)
            obj.experiment.storeData(data, dataFormat, dataType, [], obj);
        end
        
    end
    
end
