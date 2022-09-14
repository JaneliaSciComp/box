function [filePath, version] = getDefaultsFile(assayName, varargin)
    % Return the contents and version of the latest defaults XML for the specified assay.
    % 
    % Optional arguments:
    %   'spaceKey' - The key of the wiki space, 'flyolympiad' by default.
    %   'pageTitle' - The title of the wiki page to which the defaults files are attached, 'Olympiad Metadata Defaults' by default.
    %   'version' - The version of the defaults file to retrieve.  If not specified then the most recent version is used.
    % >> [filePath, version] = SAGE.Metadata.getDefaultsFromWiki('fly_olympiad_gap', 'username', 'olympiad');
    
    try
        parser = inputParser;
        parser.addRequired('assayName', @ischar);
        parser.addParamValue('spaceKey', 'flyolympiad', @ischar);
        parser.addParamValue('pageTitle', 'Olympiad Metadata Defaults', @ischar);
        parser.addParamValue('version', [], @isnumeric);
        parser.parse(assayName, varargin{:});
        inputs = parser.Results;
        
        fileName = [inputs.assayName '_defaults.xml'];
        version = inputs.version;
        
        % TODO: make sure we are reusing an existing login when possible
        login = SAGE.login('Wiki', 'userName' ,'anonymous', 'password', 'anonymous');
        
        % Look up the defaults page ID.
        defaultsPage = SAGE.Wiki.Space(inputs.spaceKey, login).page(inputs.pageTitle);
        
        % Get the list of attachments to the page.
        attachments = defaultsPage.attachments();
        
        % See if there is a defaults file for this assay name.
        attachment = [];
        for i = 1:numel(attachments)
            if strcmp(attachments(i).fileName, fileName)
                attachment = attachments(i);
                if isempty(version)
                    parts = regexp(attachment.url, 'version=([0-9]+)', 'tokens');
                    version = char(parts{1}(1));
                end
                break;
            end
        end
        
        % Grab the contents of the defaults file if one was found.
        if ~isempty(attachment)
            filePath = fullfile(tempdir, [inputs.assayName '_defaults_' num2str(version) '.xml']);
            try
                attachment.saveToPath(filePath, version);
            catch ME
                if strcmp(ME.identifier, 'MATLAB:parseSoapResponse:SoapFault') && strfind(ME.message, 'No attachment on content')
                    error('Version %d of the defaults file does not exist.', version)
                else
                    rethrow ME
                end
            end
        else
            error('Could not find any defaults files.');
        end
    catch ME
        newException = MException('SAGE:GetDefaultsFailed', 'Failed to get the metadata defaults file for ''%s''. (%s)', assayName, ME.message);
        addCause(newException, ME);
        throw(newException);
    end
end
