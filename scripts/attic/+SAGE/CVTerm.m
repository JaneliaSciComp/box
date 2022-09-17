classdef CVTerm < handle
    % The CVTerm class represents a specific term in a controlled vocabulary.
    
    % TODO: make this a sub-class of DBObject
    
    properties
        cv = ''
        name = ''
        displayName = ''
        definition = ''
        synonyms = {};
    end
    
    
    methods
        
        function obj = CVTerm(cv, name, displayName, definition, synonyms)
            obj.cv = cv;
            obj.name = name;
            obj.displayName = displayName;
            obj.definition = definition;
            obj.synonyms = synonyms;
        end
        
        
        function q = idQuery(obj)
            q = sprintf('getCvTermId(''%s'', ''%s'', NULL)', obj.cv.name, obj.name);
        end
        
    end
end