function [names, attachments] = getProtocolNames(assayName, varargin)
    % Return the names of the protocol files for the specified assay.
    % 
    % Optional arguments:
    %   'spaceKey' - The key of the wiki space, 'flyolympiad' by default.
    %   'pageTitle' - The title of the wiki page to which the defaults files are attached, 'Olympiad Protocols' by default.
    %
    % >> names = SAGE.Metadata.getProtocolNames('fly_olympiad_gap', 'pageTitle', 'Olympiad Secondary Protocols');
    
    try
        parser = inputParser;
        parser.addRequired('assayName', @ischar);
        parser.addParamValue('spaceKey', 'flyolympiad', @ischar);
        parser.addParamValue('pageTitle', 'Olympiad Protocols', @ischar);
        parser.parse(assayName, varargin{:});
        inputs = parser.Results;
        
        % TODO: make sure we are reusing an existing login when possible
        login = SAGE.login('Wiki', 'userName' ,'anonymous', 'password', 'anonymous');
        
        % Look up the defaults page ID.
        defaultsPage = SAGE.Wiki.Space(inputs.spaceKey, login).page(inputs.pageTitle);
    
        % Get the list of attachments to the page.
        allAttachments = defaultsPage.attachments();
    
        % Get the protocol names for this assay.
        names = {};
        attachments = SAGE.Wiki.Attachment.empty(0, 1);
        for i = 1:numel(allAttachments)
            if regexp(allAttachments(i).fileName, ['^[EHR]P_' assayName '.*_v[0-9]+p[0-9]\.xlsx$'], 'ignorecase', 'once')
                names{end+1} = allAttachments(i).fileName; %#ok<AGROW>
                attachments(end+1) = allAttachments(i); %#ok<AGROW>
            end
        end
        [names, indices] = sort(names'); %#ok<TRSRT>
        attachments = attachments(indices);
    catch ME
        newException = MException('SAGE:GetProtocolNamesFailed', 'Failed to get the protocol names for ''%s''. (%s)', inputs.assayName, ME.message);
        addCause(newException, ME);
        throw(newException);
    end
end