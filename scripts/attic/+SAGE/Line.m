classdef Line < handle
    % The Line class represents a genetic line.
    
    % TODO: make this a sub-class of DBObject
    
    properties
        lab = ''
        name = ''
    end
    
    methods
        
        function obj = Line(lab, name)
            obj.lab = lab;
            obj.name = name;
        end
        
        
        function q = idQuery(obj)
            q = sprintf('select id from line_vw where lab=''%s'' and name=''%s''', obj.lab.name, obj.name);
        end
        
    end
end
