function logout(serviceName, varargin)
    global sageLoginParams
    
    if isempty(sageLoginParams)
        sageLoginParams = {};
    end
    
    % Parse the function inputs.
    parser = inputParser;
    parser.addRequired('serviceName', @ischar);
    parser.addParamValue('configFile', '', @ischar);
    parser.addParamValue('host', '', @ischar);
    parser.addParamValue('database', '', @ischar);
    parser.addParamValue('userName', '', @ischar);
    parser.parse(serviceName, varargin{:});
    inputs = parser.Results;
    
    % Read the settings from a config file if provided.
    % These settings will take precedence over the other arguments to this function.
    if ~isempty(inputs.configFile)
        params = SAGE.Utility.IniConfig();
        params.ReadFile(inputs.configFile);
        
        if params.IsSections({serviceName})
            values = params.GetValues(serviceName, {'host', 'database', 'username'}, {inputs.host, inputs.database, inputs.userName});
            [inputs.host, inputs.database, inputs.userName] = values{:};
        end
    end
    
    loginParams = struct;
    
    if strcmp(serviceName, 'SAGE')
        % TODO: logout from the web service if needed once it's possible.
    elseif strcmp(serviceName, 'Wiki')
        loginParams.serviceName = serviceName;
        
        if ~isempty(inputs.host)
            % Build the base web service URL's.
            if isempty(inputs.host)
                wikiBase = SAGE.urlbase('Wiki');
            else
                wikiBase = ['http://' inputs.host '/wiki/'];
            end
            loginParams.serviceURL = [wikiBase 'rpc/soap-axis/confluenceservice-v1'];
            loginParams.wsdlURL = [serviceURL '?wsdl'];
        end
        if ~isempty(inputs.userName)
            loginParams.userName = inputs.userName;
        end
        
        % Check for an existing connection to this wiki.
        loginParams = findLoginWithParams(loginParams);
        if ~isempty(loginParams)
            % Logout of the wiki.
            msg = createSoapMessage(loginParams.wsdlURL, 'logout', {loginParams.token}, {'token'});
            try
                callSoapService(loginParams.serviceURL, '', msg);
            catch ME
                warning('SAGE:LogoutFailed', 'Failed to log out of a Wiki service. (%s)', ME.message);
            end
        end
    elseif strcmp(serviceName, 'Database')
        loginParams.serviceName = serviceName;
        
        if ~isempty(inputs.host)
            loginParams.host = inputs.host;
        end
        if ~isempty(inputs.database)
            loginParams.databaseName = inputs.database;
        end
        if ~isempty(inputs.userName)
            loginParams.userName = inputs.userName;
        end
        
        % Check for an existing connection to this wiki.
        loginParams = findLoginWithParams(loginParams);
        if ~isempty(loginParams)
            try
                close(loginParams.database);
            catch ME
                warning('SAGE:logoutFailed', 'Could not close the database connection: %s', ME.message);
            end
        end
    else
        error('SAGE:Logout:Error', 'Unknown SAGE service: %s', serviceName);
    end
    
    if ~isempty(loginParams)
        % Remove the params from the cache.
        for i = 1:length(sageLoginParams)
            if isequal(loginParams, sageLoginParams{i})
                sageLoginParams(i) = [];
                break
            end
        end
    end
end