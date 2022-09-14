function clause = Any(varargin)
    %% query = SAGE.Query.Any(...)
    % Select any records that match the supplied criteria (boolean OR).
    % Each argument should be the result of a previous call to SAGE.Query.Compare, SAGE.Query.All or SAGE.Query.Any.
    
    for i = 1:nargin
        if ~isa(varargin{i}, 'SAGE.Query.Clause')
            error('SAGE:Query:InvalidSubClause', 'All arguments to the SAGE.Query.Any function must be objects created with the SAGE.Query.All, SAGE.Query.Any or SAGE.Query.Compare functions.');
        end
    end
    
    clause = SAGE.Query.Clause('Any', varargin{:});
end