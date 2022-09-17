function result = sendWikiMessage(methodName, values, valueNames, login)
    if nargin == 3
        % TODO: which Wiki?
        login = SAGE.login('Wiki');
    end
    
    msg = createSoapMessage(login.wsdlURL, methodName, [{login.token} values], [{'token'} valueNames]);
    rsp = callSoapService(login.serviceURL, '', msg);
    try
        result = parseSoapResponse(rsp);
    catch ME
        if strfind(ME.message, 'com.atlassian.confluence.rpc.InvalidSessionException')
            % The login has expired, login again.
            SAGE.logout('Wiki');
            login = SAGE.login('Wiki', 'wikiServiceURL', login.serviceURL, 'userName', login.userName);
            
            % Now resend the message.
            msg = createSoapMessage(login.wsdlURL, methodName, [{login.token} values], [{'token'} valueNames]);
            rsp = callSoapService(login.serviceURL, '', msg);
            result = parseSoapResponse(rsp);
        else
            rethrow(ME);
        end
    end
end
