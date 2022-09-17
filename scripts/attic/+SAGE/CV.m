classdef CV < handle
    % The CV class represents a set of controlled vocabulary terms.
    %
    % >> cv = SAGE.CV('effector');
    % >> effectors = cv.terms();
    % >> cv.displayName
    % 
    % ans = 
    % 
    % Effector
    
    % TODO: make this a sub-class of DBObject
    
    properties
        parent              % The parent CV of this CV.
        name = ''           % The unique identifier of the CV.
        displayName = ''    % The human-readable name of the CV.
        definition = ''     % A human-readable definition of the CV useful in, for example, tooltips.
    end
    
    properties (Access = private)
        cvTerms = SAGE.CVTerm.empty(0, 0);
        termsFetched = false;
    end
    
    methods
        
        function obj = CV(name, displayName, definition)
            % Create or lookup a CV object.
            % If only a name is given then an existing CV will be looked up.
            if nargin == 3
                % Create a new instance.
                obj.name = name;
                obj.displayName = displayName;
                obj.definition = definition;
            else
                % Lookup an existing instance.
                cvs = SAGE.cvs();
                foundCV = false;
                for cv = cvs
                    if strcmp(cv.name, name)
                        obj = cv;
                        foundCV = true;
                        break
                    end
                end
                
                if ~foundCV
                    error('SAGE:CV:Error', ['There is no CV named ''' name ''' in SAGE.'])
                end
            end
        end
        
        
        function fetchTerms(obj, includeParentTerms)
            % Fetch the current list of terms from SAGE.
            
            if nargin < 2
                includeParentTerms = true;
            end
            
            % Get the related CV's and the list of terms in this CV from the REST service.
            xmlDoc = xmlread([SAGE.urlbase 'cvs/' obj.name]);

            factory = javax.xml.xpath.XPathFactory.newInstance();
            xpath = factory.newXPath();
            
            % Get the parent of this CV.
            parentName = xpath.evaluate(['//cv/cvRelationship[subjectName="' obj.name '" and typeName="is_sub_cv_of"]/objectName'], xmlDoc, javax.xml.xpath.XPathConstants.STRING);
            if ~isempty(parentName)
                obj.parent = SAGE.CV(parentName);
            end
            
            % Get the list of terms in this CV.
            termNodes = xpath.evaluate('/cv/termSet/term', xmlDoc, javax.xml.xpath.XPathConstants.NODESET);
            obj.cvTerms = SAGE.CVTerm.empty(termNodes.getLength(), 0);
            
            for termIndex = 0:termNodes.getLength()-1
                termNode = termNodes.item(termIndex);
                
                % Get the name, display name and definition of the term.
                termName = char(xpath.evaluate('name', termNode));
                termDisplayName = char(xpath.evaluate('displayName', termNode));
                termDefinition = char(xpath.evaluate('definition', termNode));
                
                % Get any synonyms of the term.
                synonymNodes = xpath.evaluate('synonymSet/synonym', termNode, javax.xml.xpath.XPathConstants.NODESET);
                synonyms = cell(1, synonymNodes.getLength());
                for synonymIndex = 0:synonymNodes.getLength()-1
                    synonymName = char(synonymNodes.item(synonymIndex).getTextContent());
                    synonyms{synonymIndex + 1} = synonymName;
                end

                obj.cvTerms(termIndex + 1) = SAGE.CVTerm(obj, termName, termDisplayName, termDefinition, synonyms);
            end
            
            if includeParentTerms && ~isempty(obj.parent)
                % Tell our parent CV to also fetch its terms (which may call to its own parent...)
                obj.parent.fetchTerms();
            end
            
            obj.termsFetched = true;
        end
        
        
        function list = terms(obj, includeParentTerms)
            % Return the list of terms in the controlled vocabulary.
            %
            % >> cv = SAGE.CV('effector');
            % >> effectors = cv.terms();
            % >> effectors(1).displayName
            % 
            % ans = 
            % 
            % GFP
            %
            % The list of terms is locally cached, call the fetchTerms method to update the list.
            
            if nargin < 2
                includeParentTerms = true;
            end
            
            % Make sure we have our terms locally cached.
            if ~obj.termsFetched
                obj.fetchTerms()
            end
            
            % Return just our terms or our terms merged with our parent's terms.
            if ~includeParentTerms || isempty(obj.parent)
                list = obj.cvTerms;
            else
                list = [obj.cvTerms obj.parent.terms()];
            end
        end
        
        
        function t = term(obj, termName, includeParentTerms)
            % Find the term with the given name or synonym.
            
            if nargin < 3
                includeParentTerms = true;
            end
            
            t = [];
            for cvTerm = obj.terms(includeParentTerms)
                if strcmp(cvTerm.name, termName) || any(strcmp(termName, cvTerm.synonyms))
                    t = cvTerm;
                    break
                end
            end
        end
        
    end
    
end
