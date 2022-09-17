classdef Page < handle
    
    properties (SetAccess = protected)
        space
        id
        parentId
        title
        url
        locks
        version
    end
    
    properties (SetObservable = true, GetObservable = true)
        content
    end
    
    properties (Hidden)
        gettingContent = false
    end
    
    
    methods
        
        function obj = Page(space, pageData)
            obj.space = space;
            
            fn = fieldnames(pageData);
            for i = 1:length(fn)
                if ~strcmp(fn{i}, 'space') && ~isempty(findprop(obj, fn{i}))
                    obj.(fn{i}) = pageData.(fn{i});
                end
            end
            
            addlistener(obj, 'content', 'PreGet', @(src, evnt)preGetFunc(obj, src, evnt));
            addlistener(obj, 'content', 'PostSet', @(src, evnt)postSetFunc(obj, src, evnt));
        end
        
        
        function p = childPages(obj)
            pageData = sendWikiMessage('getChildren', {obj.id}, {'pageId'}, obj.space.login);
            p = SAGE.Wiki.Page.empty(0,length(pageData));
            for i = 1:length(pageData)
                p(i) = SAGE.Wiki.Page(obj.space, pageData(i));
            end
        end
        
        
        function p = addChildPage(obj, title, content)
            if nargin == 2
                content = '';
            end
            
            page.space = obj.space.key;
            page.title = title;
            page.content = content;
            page.parentId = obj.id;
            result = sendWikiMessage('storePage', {page}, {'page'}, obj.space.login);
            if isstruct(result)
                p = SAGE.Wiki.Page(obj.space, result);
            else
                % TODO: error?
            end
        end
        
        
        function a = attachments(obj)
            attachmentData = sendWikiMessage('getAttachments', {obj.id}, {'pageId'}, obj.space.login);
            a = SAGE.Wiki.Attachment.empty(0,length(attachmentData));
            for i = 1:length(attachmentData)
                a(i) = SAGE.Wiki.Attachment(obj, attachmentData(i));
            end
        end
        
        
        function a = attachFile(obj, filePath, comment)
            if nargin == 2
                comment = '';
            end
            
            [~, name, ext] = fileparts(filePath);
            attachment.fileName = [name ext];
            attachment.contentType = char(java.net.URLConnection.getFileNameMap().getContentTypeFor(filePath));
            if isempty(attachment.contentType)
                attachment.contentType = 'application/octet-stream';
            end
            attachment.comment = comment;
            fid = fopen(filePath, 'r', 'b');
            attachmentData = uint8(fread(fid));
            fclose(fid);
            result = sendWikiMessage('addAttachment', {obj.id, attachment, attachmentData}, {'contentId', 'attachment', 'attachmentData'}, obj.space.login);
            if isstruct(result)
                a = SAGE.Wiki.Attachment(obj, result);
            else
                % TODO: error?
            end
        end
        
    end
    
    
    methods (Access = private)
        
        function preGetFunc(obj, ~, event)
            % Read the markup content of the page if we don't already have it.
            if isempty(obj.content) && strcmp(event.Source.Name, 'content')
                pageData = sendWikiMessage('getPage', {obj.id}, {'pageId'}, obj.space.login);
                obj.gettingContent = true;
                obj.content = pageData.content; % triggers postSetFunc
                obj.version = pageData.version;
                obj.gettingContent = false;
            end
        end
        
        
        function postSetFunc(obj, ~, event)
            % Push the new markup content to the wiki.
            if ~obj.gettingContent && strcmp(event.Source.Name, 'content')
                page.id = obj.id;
                page.space = obj.space.key;
                page.parentId = obj.parentId;
                page.title = obj.title;
                page.content = obj.content;
                page.version = obj.version; % + 1;
                updateOptions.versionComment = '';
                updateOptions.minorEdit = false;
                result = sendWikiMessage('updatePage', {page, updateOptions}, {'page', 'pageUpdateOptions'}, obj.space.login);
                if isstruct(result)
                    obj.version = result.version;
                else
                    % TODO: error?
                end
            end
        end
        
    end
    
end