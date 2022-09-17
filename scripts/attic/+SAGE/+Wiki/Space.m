classdef Space < handle
    
    properties (SetAccess = private)
        key
        name
        type
        url
        homePageID
    end
    
    properties (Hidden, SetAccess = private)
        login
    end
    
    
    methods
        
        function obj = Space(spaceData, login)
            if nargin == 2
                obj.login = login;
            else
                obj.login = SAGE.login('Wiki');
            end
            
            if ischar(spaceData)
                spaceData = sendWikiMessage('getSpace', {spaceData}, {'spaceKey'}, obj.login);
            end
            
            obj.key = spaceData.key;
            obj.name = spaceData.name;
            obj.type = spaceData.type;
            obj.url = spaceData.url;
            obj.homePageID = spaceData.homePage;
        end
        
        
        function p = pages(obj)
            pageData = sendWikiMessage('getPages', {obj.key}, {'spaceKey'}, obj.login);
            p = SAGE.Wiki.Page.empty(0,length(pageData));
            for i = 1:length(pageData)
                p(i) = SAGE.Wiki.Page(obj, pageData(i));
            end
            
            % TODO: resolve parentId's?
        end
        
        
        function p = page(obj, title)
            pageData = sendWikiMessage('getPage', {obj.key, title}, {'spaceKey', 'pageTitle'}, obj.login);
            p = SAGE.Wiki.Page(obj, pageData);
        end
        
        
        function p = addPage(obj, title, content)
            if nargin < 3
                content = '';
            end
            page.space = obj.key;
            page.title = title;
            page.content = content;
            page.parentId = obj.homePageID;
            pageData = sendWikiMessage('storePage', {page}, {'page'}, obj.login);
            p = SAGE.Wiki.Page(obj, pageData);
        end
        
    end
    
end