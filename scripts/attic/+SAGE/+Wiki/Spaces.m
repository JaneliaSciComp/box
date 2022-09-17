function s = Spaces(login)
    if nargin == 0
        login = SAGE.login('Wiki');
    end
    
    spaceData = sendWikiMessage('getSpaces', {}, {}, login);
    s = SAGE.Wiki.Space.empty(0,length(spaceData));
    for i = 1:length(spaceData)
        s(i) = SAGE.Wiki.Space(spaceData(i));
    end
end
