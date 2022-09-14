function result = are_all_equal(array)
    if iscell(array) ,
        if isempty(array) ,
            result = true ;  % Is this the right call?  all([])==true, so let's try this.
        else
            result = all(cellfun(@(el)(isequal(el, array{1})), array(:))) ;
        end
    else
        if isempty(array) ,
            result = true ;  % Is this the right call?  all([])==true, so let's try this.
        else
            result = all(cellfun(@(el)(isequal(el, array(1))), array(:))) ;
        end        
    end
end
