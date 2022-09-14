function loginParams = login(serviceName, varargin)
    % Login to the given service, either 'SAGE', 'Wiki' or 'Database'.
    % If the username and password are not specified then the user will be prompted for them.
    %
    % To connect to a SAGE database the config file should contain the following two sections:
    % 
    %   [Database]
    %   host = mysql3
    %   database = sage
    %   username = <user>
    %   password = <password>
    %   
    %   [DatabaseOptions]
    %   init_command = SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
    
    
    global sageLoginParams
    
    try
        if isempty(sageLoginParams) %#ok<*NODEF>
            sageLoginParams = {}; %#ok<NASGU>
        end
        
        % Parse the function inputs.
        parser = inputParser;
        parser.addRequired('serviceName', @ischar);
        parser.addParamValue('configFile', '', @ischar);
        parser.addParamValue('host', '', @ischar);
        parser.addParamValue('database', '', @ischar);
        parser.addParamValue('userName', '', @ischar);
        parser.addParamValue('password', '', @ischar);
        parser.addParamValue('wikiServiceURL', '', @ischar);
        parser.parse(serviceName, varargin{:});
        inputs = parser.Results;
        
        % Read the settings from a config file if provided.
        % These settings will take precedence over the other arguments to this function.
        if ~isempty(inputs.configFile)
            iniParams = SAGE.Utility.IniConfig();
            iniParams.ReadFile(inputs.configFile);
            
            if iniParams.IsSections({serviceName})
                values = iniParams.GetValues(serviceName, {'host', 'database', 'username', 'password'}, {inputs.host, inputs.database, inputs.userName, inputs.password});
                [inputs.host, inputs.database, inputs.userName, inputs.password] = values{:};
            end
        end
        
        params.serviceName = serviceName;
        
        if strcmp(serviceName, 'SAGE')
            % TODO: login to the web service once it supports it
            error('SAGE:Unimplemented', 'The SAGE web service doesn''t yet support logging in.');
        elseif strcmp(serviceName, 'Wiki')
            % Build the base web service URL's.
            if ~isempty(inputs.wikiServiceURL)
                params.serviceURL = inputs.wikiServiceURL;
            else
                if isempty(inputs.host)
                    wikiBase = SAGE.urlbase('Wiki');
                else
                    wikiBase = ['http://' inputs.host '/wiki/'];
                end
                params.serviceURL = [wikiBase 'rpc/soap-axis/confluenceservice-v2'];
            end
            params.wsdlURL = [params.serviceURL '?wsdl'];
            if ~isempty(inputs.userName)
                params.userName = inputs.userName;
            end
        elseif strcmp(serviceName, 'Database')
            % Make sure we have the settings we need.
            if isempty(inputs.host)
                error('SAGE:Login:MissingParameter', 'The database host must be specified')
            end
            if isempty(inputs.database)
                error('SAGE:Login:MissingParameter', 'The database name must be specified')
            end
            
            params.host = inputs.host;
            params.databaseName = inputs.database;
            if ~isempty(inputs.userName)
                params.userName = inputs.userName;
            end
        else
            error('SAGE:Login:Error', 'Unknown SAGE service: %s', serviceName);
        end
        
        % Check for an existing connection to the service.
        loginParams = findLoginWithParams(params);
        if isempty(loginParams)
            % There is no existing connection so log in.
            loginParams = params;
            
            % Prompt for the user's name and password if they weren't provided explicitly or in the config file.
            if isempty(inputs.userName) || isempty(inputs.password)
                % TODO: how to check if GUI is not possible and error out?
                if isempty(inputs.userName)
                    inputs.userName = getpref('SAGE', 'LastLoginName', '');
                end
                sagePath = fileparts(mfilename('fullpath'));
                [inputs.password, inputs.userName] = SAGE.Utility.passwordEntryDialog('WindowName', ['SAGE ' serviceName ' Login'], ...
                                                                                      'enterUserName', true, ...
                                                                                      'DefaultUserName', inputs.userName, ...
                                                                                      'ImagePath', fullfile(sagePath, 'Janelia.gif'));
            end
            
            if isempty(inputs.userName)
                error('SAGE:Login:MissingParameter', 'The user name must be specified')
            else
                loginParams.userName = inputs.userName;
            end
            if isempty(inputs.password)
                error('SAGE:Login:MissingParameter', 'The password must be specified')
            end
            
            if strcmp(serviceName, 'SAGE')
                % TODO: login to the web service once it supports it
                error('SAGE:Unimplemented', 'The SAGE web service doesn''t yet support logging in.');
            elseif strcmp(serviceName, 'Wiki')
                % Login to the wiki.
                if strcmp(inputs.userName, 'anonymous')
                    loginParams.token = '';
                else
                    msg = createSoapMessage(params.wsdlURL, 'login', {inputs.userName, inputs.password}, {'username', 'password'});
                    rsp = callSoapService(params.serviceURL, '', msg);
                    loginParams.token = parseSoapResponse(rsp);
                    setpref('SAGE', 'LastLoginName', inputs.userName);
                end
                sageLoginParams{end + 1} = loginParams; %#ok<NASGU>
            elseif strcmp(serviceName, 'Database')
                % Make sure Java can find the database driver.
                [parentDir, ~, ~] = fileparts(mfilename('fullpath'));
                jarPath = fullfile(parentDir, '+Utility', 'mysql-connector-java-5.1.15-bin.jar');
                warning off MATLAB:javaclasspath:jarAlreadySpecified
                dynamicPaths = javaclasspath();
                if isempty(dynamicPaths) || ~any(strcmp(jarPath, dynamicPaths))
                    % We have to save our global since javaaddpath indirectly calls clear('java').
                    % See <http://www.mathworks.com/matlabcentral/newsreader/view_thread/163362>
                    % TODO: should we save and restore all globals?
                    prevParams = sageLoginParams;
                    
                    javaaddpath(jarPath);
                    
                    % Now restore it.
                    global sageLoginParams %#ok<REDEF,TLEV>
                    sageLoginParams = prevParams; %#ok<NASGU>
                end
                
                % Connect to the database.
                driver = com.mysql.jdbc.Driver;
                dbURL = ['jdbc:mysql://' inputs.host '/' inputs.database '?user=' inputs.userName '&password=' inputs.password];
                db = driver.connect(dbURL, '');
                
                % Make sure transactions are configured.
                set(db, 'TransactionIsolation', java.sql.Connection.TRANSACTION_READ_COMMITTED);
                
                loginParams.database = db;
                sageLoginParams{end + 1} = loginParams; %#ok<NASGU>
            end
        end
    catch ME
        newException = MException('SAGE:LoginFailed', 'Failed to log in to the ''%s'' service. (%s)', serviceName, ME.message);
        addCause(newException, ME);
        throw(newException);
    end
end
