function createJiraTicket(isTemplate, summary, description, projectID, issueType, lineName, apparatus, fileSystemPath, errorMessage, errorCode)
    %% SAGE.createJiraTicket(isTemplate, summary, description, projectID, issueType, lineName, apparatus, fileSystemPath, errorMessage, errorCode)
    % 
    % If isTemplate is true then the user will be presented with a web page allowing them to edit the settings before saving the ticket.
    %
    % Examples:
    % >> SAGE.createJiraTicket(true, 'Test ticket', 'test description', 10230); % Add a ticket to the Climbing Pipeline QC project
    
    % TODO: use an InputParser to handle optional arguments (especially custom fields)
    
    if nargin < 4
        error('The first four arguments must be specified.');
    end
    if nargin < 5
        issueType = '6';    % QC Failure
    end
    if nargin < 6
        lineName = '';
    end
    if nargin < 7
        apparatus = '';
    end
    if nargin < 8
        fileSystemPath = '';
    end
    if nargin < 9
        errorMessage = '';
    end
    if nargin < 10
        errorCode = '';
    end
    
    args = ['pid=' encode(projectID) ...
            '&issuetype=' encode(issueType) ...
            '&summary=' encode(summary) ...
            '&description=' encode(description) ...
            '&customfield_10001=' encode(lineName) ...
            '&customfield_10002=' encode(fileSystemPath) ...
            '&customfield_10003=' encode(errorMessage) ...
            '&customfield_10031=' encode(errorCode) ...
            '&customfield_10032=' encode(apparatus)];
    
    if isTemplate
        web(['http://issuetracker.int.janelia.org/secure/CreateIssueDetails!init.jspa?' args], '-browser');
    else
        results = urlread(['http://issuetracker.int.janelia.org/secure/CreateIssueDetails.jspa?' args]);
        if isempty(strfind(results, 'You have successfully created the issue'))
            if usejava('desktop')
                warning('SAGE:createJiraTicketFailed', 'The ticket could not be created.  See the web page results for details.');
                web(['text://' results], '-new');
            else
                error('SAGE:createJiraTicketFailed', 'The ticket could not be created');
            end
        end
    end
end

function e = encode(s)
    if isnumeric(s)
        s = num2str(s);
    end
    
    e = char(java.net.URLEncoder.encode(s));
end

        