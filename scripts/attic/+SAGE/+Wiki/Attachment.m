classdef Attachment < handle
    
    properties (SetAccess = private)
        page
        id
        title
        fileName
        fileSize
        contentType
        created
        creator
        url
        comment
    end
    
    methods
        
        function obj = Attachment(page, attachmentData)
            obj.page = page;
            
            fn = fieldnames(attachmentData);
            for i = 1:length(fn)
                if ~strcmp(fn{i}, 'page') && ~isempty(findprop(obj, fn{i}))
                    obj.(fn{i}) = attachmentData.(fn{i});
                end
            end
            
            % TODO
            %addlistener(obj, 'content', 'PreGet', @(src, evnt)preGetFunc(obj, src, evnt));
            %addlistener(obj, 'content', 'PostSet', @(src, evnt)postSetFunc(obj, src, evnt));
        end
        
        
        function saveToPath(obj, savePath, version)
            if nargin == 2
                version = 0;    % current version
            end
            attachmentData = sendWikiMessage('getAttachmentData', {obj.page.id, obj.fileName, version}, {'pageId', 'fileName', 'versionNumber'}, obj.page.space.login);
            attachmentData = mod(double(attachmentData), 256);
            fid = fopen(savePath, 'w');
            fwrite(fid, attachmentData, 'uint8');
            fclose(fid);
        end
        
    end
    
end