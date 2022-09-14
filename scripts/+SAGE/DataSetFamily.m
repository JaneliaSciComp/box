classdef DataSetFamily < handle
    % The Lab class represents a family of data sets for a Lab.
    %
    % >> lab = SAGE.Lab('rubin');
    % >> lab.displayName
    % 
    % ans = 
    % 
    % Rubin Lab
    % 
    % >> lines = lab.lines();
    % >> length(lines)
    % 
    % ans = 
    % 
    %         7864
    
    properties
        lab                 % The lab that the family belongs to.
        name                % The unique identifier of the family.
        displayName = ''    % The human-readable name of the family.
        description = ''    % A human-readable description of the family useful in, for example, tooltips.
    end
    
    properties (Access = private)
        labDataSets= SAGE.DataSet.empty(0, 0);
        dataSetsFetched = false;
    end
    
    methods
        function obj = DataSetFamily(lab, name, displayName, description)
            % Create a DataSetFamily object.
            obj.lab = lab;
            obj.name = name;
            if nargin > 2
                obj.displayName = displayName;
            end
            if nargin > 3
                obj.description = description;
            end
        end
        
        
        function list = dataSets(obj)
            % Return a list of data sets for the family.
            %
            % dataSets() returns all lines for the lab.
            %
            % >> lab = SAGE.Lab('rubin');
            % >> lines = lab.lines('*61A*');    % Find lines containing '61A'
            % >> lines(11).name
            % 
            % ans = 
            % 
            % GMR_61A11_AD_01
            %
            % The list of data sets is cached, call the refreshDataSets method to update the list if needed.
            
            if ~obj.dataSetsFetched
                xmlDoc = xmlread([SAGE.urlbase 'datasets/' obj.lab.name '/' obj.name '.janelia-sage']);
                
                factory = javax.xml.xpath.XPathFactory.newInstance();
                xpath = factory.newXPath();
                
                dataSetNodes = xpath.evaluate('/dataSetSet/dataSet', xmlDoc, javax.xml.xpath.XPathConstants.NODESET);
                
                for dataSetIndex = 0:dataSetNodes.getLength()-1
                    dataSetNode = dataSetNodes.item(dataSetIndex);
                    
                    % Create the data set
                    dataSetName = char(xpath.evaluate('name', dataSetNode));
                    dataSetDisplayName = char(xpath.evaluate('displayName', dataSetNode));
                    dataSetDescription = char(xpath.evaluate('description', dataSetNode));
                    obj.labDataSets(dataSetIndex + 1) = SAGE.DataSet(obj, dataSetName, dataSetDisplayName, dataSetDescription);
                    
                    % Add the fields
                    fieldNodes = xpath.evaluate('field', dataSetNode, javax.xml.xpath.XPathConstants.NODESET);
                    dataSetFields = SAGE.DataSetField.empty(fieldNodes.getLength(), 0);
                    for fieldIndex = 0:fieldNodes.getLength()-1
                        fieldNode = fieldNodes.item(fieldIndex);

                        % Create the field
                        fieldName = char(xpath.evaluate('name', fieldNode));
                        fieldDisplayName = char(xpath.evaluate('displayName', fieldNode));
                        fieldDescription = char(xpath.evaluate('description', fieldNode));
                        fieldDataType = char(xpath.evaluate('dataType', fieldNode));
                        fieldDeprecated = char(xpath.evaluate('deprecated', fieldNode));
                        fieldDeprecated = strcmp(fieldDeprecated, 'true');
                        dataSetFields(fieldIndex + 1) = SAGE.DataSetField(obj.labDataSets(dataSetIndex + 1), fieldName, fieldDisplayName, fieldDescription, fieldDataType, fieldDeprecated);
                        
                        % Add any field values
                        valueNodes = xpath.evaluate('value', fieldNode, javax.xml.xpath.XPathConstants.NODESET);
                        for valueIndex = 0:valueNodes.getLength()-1
                            valueNode = valueNodes.item(valueIndex);
                            value = char(valueNode.getTextContent());
                            dataSetFields(fieldIndex + 1).addValidValue(value);
                        end
                    end
                    
                    obj.labDataSets(dataSetIndex + 1).setFields(dataSetFields);
                end
                
                obj.dataSetsFetched = true;
            end
            list = obj.labDataSets;
        end
        
        
        function set = dataSet(obj, name)
            % Return the data set with the given name or [] if no data set has that name.
            
            % Make sure the list has been retrieved from SAGE.
            obj.dataSets();
            
            for set = obj.labDataSets
                if isequal(set.name, name)
                    return
                end
            end
            set = [];
        end
        
        
        %% Metadata methods
        
        
        function [filePath, version] = getMetadataDefaultsFile(obj, varargin)
            [filePath, version] = SAGE.Metadata.getDefaultsFile(obj.name, varargin{:});
        end
        
        
        function [names, attachments] = getProtocolNames(obj, varargin)
            if strcmp(obj.name, 'bowl')
                [names, attachments] = SAGE.Metadata.getProtocolNames('flybowl', varargin{:});
            else
                [names, attachments] = SAGE.Metadata.getProtocolNames(obj.name, varargin{:});
            end
        end

    end
end
