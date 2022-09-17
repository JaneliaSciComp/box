classdef Session < SAGE.DBPropertyObject
    % The Session class represents a part of an experiment run by a lab or group project.
    
    % TODO: examples
    
    
    properties (SetAccess=immutable)
        experiment
    end
    
    properties
        lab
        line
        annotator
    end
    
    
    methods
        
        function obj = Session(experiment, id, name, type, lab, line, annotator)
            if nargin ~= 7
                error('SAGE:Session:Error', 'Wrong number of argument used to create a Session object.');
            end
            
            if ~isscalar(experiment) || ~isa(experiment, 'SAGE.Experiment')
                error('SAGE:Session:Error', 'The experiment used to create a session must be a SAGE.Experiment instance.');
            end
            if ~isscalar(lab) || ~isa(lab, 'SAGE.Lab')
                error('SAGE:Session:Error', 'The lab used to create a session must be a SAGE.Lab instance.');
            end
            if ~isscalar(line) || ~isa(line, 'SAGE.Line')
                error('SAGE:Session:Error', 'The line used to create a session must be a SAGE.Line instance.');
            end
            if size(annotator, 1) > 1 || ~ischar(annotator)
                error('SAGE:Session:Error', 'The annotator used to create a session must be a string.');
            end
            
            obj = obj@SAGE.DBPropertyObject(experiment.db, id, name, type);
            
            obj.tableName = 'session';
            % TODO: obj.updatableFields{end + 1} = 'lab';
            % TODO: obj.updatableFields{end + 1} = 'line';
            % TODO: obj.updatableFields{end + 1} = 'annotator';
            
            obj.experiment = experiment;
            obj.lab = lab;
            obj.line = line;
            obj.annotator = annotator;
        end
        
        
        function createRelationship(obj, otherSession, type)
            % Check the arguments.
            if ~isa(otherSession, 'SAGE.Session')
                error('SAGE:Session:Error', 'The other object given to createRelationship must be a SAGE.Session instance.');
            end
            if ~isa(type, 'SAGE.CVTerm')
                error('SAGE:Session:Error', 'The type given to createRelationship must be a SAGE.CVTerm instance.');
            end
            
            % Create the relationship if it doesn't already exist.
            try
                obj.executeSQL(['insert into session_relationship (subject_id, object_id, type_id) ' ...
                                                          'values (' num2str(otherSession.id) ', ' ...
                                                                   num2str(obj.id) ', ' ...
                                                                   type.idQuery() ')']);
            catch ME
                if ~strncmp(ME.ExceptionObject.getMessage(), 'Duplicate entry', length('Duplicate entry'))
                    error('SAGE:Session:Error', 'Could not create a ''%s'' relationship between sessions ''%s'' and ''%s'': %s', type.name, obj.name, otherSession.name, ME.message);
                else
                    % The relationship already exists.
                end
            end
        end
        
        
        function storeData(obj, data, dataFormat, dataType)
            obj.experiment.storeData(data, dataFormat, dataType, obj, []);
        end
        
        
        % TODO:
%         function set.lab(obj, lab)
%             obj.update('lab', lab);
%         end
%         
%         
%         function set.line(obj, line)
%             obj.update('line', line);
%         end
        
    end
    
end
