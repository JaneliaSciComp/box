function loginParams = findLoginWithParams(params)
    global sageLoginParams
    
    loginParams = [];
    
    for i = 1:length(sageLoginParams)
        paramsMatch = true;
        
        paramNames = fieldnames(params);
        for j = 1:length(paramNames)
            paramName = paramNames{j};
            if ~isfield(sageLoginParams{i}, paramName) || ~isequal(sageLoginParams{i}.(paramName), params.(paramName))
                paramsMatch = false;
                break
            end
        end
        
        if paramsMatch
            loginParams = sageLoginParams{i};
            break
        end
    end
end
