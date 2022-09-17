%% Return the base URL used to construct all queries to the SAGE web service or other servers.

function url = urlbase(varargin)
    if nargin == 0 || strcmp(varargin{1}, 'SAGE')
        url = 'http://sage.int.janelia.org/sage-ws/';   % production service
        %url = 'http://sage-val:8080/sage-ws/';         % validation service
        %url = 'http://trautmane-ws1:8080/sage-ws/';    % development service
    elseif strcmp(varargin{1}, 'Wiki')
        url = 'http://wiki.int.janelia.org/wiki/';
    else
        error 'Unknown service type passed to urlbase() function.'
    end
end
