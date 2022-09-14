classdef Lab < handle
    % The Lab class represents a lab or group project.  Lab instances can be queried for lines, assays/data sets and experiments.
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
    % lines = 
    % 
    %   1x18758 SAGE.Line handle
    %   ...
    % 
    % Querying for and working with experiments requires logging into a SAGE database.  See SAGE.login for details on connecting.
    % 
    % >> login = SAGE.login('Database', 'configFile', configFilePath);
    % 
    % >> exps = exps = SAGE.Lab('olympiad').experiments('type', SAGE.CV('fly_olympiad_box').term('box'))
    % 
    % ans = 
    % 
    %   1x7210 SAGE.Experiment handle
    %   ...
    %
    % >> exp = SAGE.Lab('olympiad').experiment('GMR_16H03_AE_01_shi_Athena_20120314T155329')
    % 
    % exp = 
    % 
    %   SAGE.Experiment handle
    %   Package: SAGE
    % 
    %   Properties:
    %      lab: [1x1 SAGE.Lab]
    %     type: [1x1 SAGE.CVTerm]
    %       db: [1x1 com.mysql.jdbc.JDBC4Connection]
    %       id: 329495
    %     name: 'GMR_16H03_AE_01_shi_Athena_20120314T155329'

    
    % TODO: make this a sub-class of DBObject?  It's a subset of the CVTerm table.
    
    properties
        name = ''
        displayName = ''
    end
    
    properties (Access = private)
        labLines = SAGE.Line.empty(0, 0);
        linesFetched = false;
        labDataSetFamilies = SAGE.DataSetFamily.empty(0, 0);
        dataSetFamiliesFetched = false;
    end
    
    methods
        
        function obj = Lab(name, displayName)
            % Create or lookup a Lab object.
            % If only a name is given then an existing lab will be looked up.
            if nargin == 2
                % Create a new instance.
                obj.name = name;
                obj.displayName = displayName;
            else
                % Lookup an existing instance.
                labs = SAGE.labs();
                foundLab = false;
                for lab = labs
                    if strcmp(lab.name, name)
                        obj = lab;
                        foundLab = true;
                        break
                    end
                end
                
                if ~foundLab
                    error('SAGE:Lab:Error', ['The ''' name ''' lab does not exist in SAGE.'])
                end
            end
        end
        
        
        function q = idQuery(obj)
            q = sprintf('getCvTermId(''lab'', ''%s'', NULL)', obj.name);
        end
        
        
        function list = lines(obj, query)
            % Return a list of the lines for the lab.
            %
            % lines() returns all lines for the lab.
            % lines(S) returns all lines whose name contains that match the pattern S (case sensitive).  The pattern can contain asterisks to do wildcard searches.
            %
            % >> lab = SAGE.Lab('rubin');
            % >> lines = lab.lines('*61A*');    % Find lines containing '61A'
            % >> lines(11).name
            % 
            % ans = 
            % 
            % GMR_61A11_AD_01
            % 
            % >> lines = lab.lines('*_AD_01');  % Find lines ending with '_AD_01'
            % >> length(lines)
            % 
            % ans = 
            % 
            %     64
            %
            % The complete list of lines is cached, call the refreshLines method to update the list.  Querying by substring always returns the latest information.
            
            if nargin == 2
                % TBD: if we have already fetched the complete list of lines is it faster to query locally?
                xmlDoc = xmlread([SAGE.urlbase 'lines/' obj.name '.janelia-sage?q=name%3D' char(java.net.URLEncoder.encode(query, 'UTF-8'))]);
                list = obj.linesFromXML(obj, xmlDoc);
            else
                if ~obj.linesFetched
                    xmlDoc = xmlread([SAGE.urlbase 'lines/' obj.name '.janelia-sage']);
                    obj.labLines = obj.linesFromXML(obj, xmlDoc);
                    obj.linesFetched = true;
                end
                list = obj.labLines;
            end
        end
        
        
        function l = line(obj, lineName)
            lines = obj.lines(lineName);
            if length(lines) == 1
                l = lines(1);
            else
                l = [];
            end
        end
        
        
        function refreshLines(obj)
            % Fetch the current list of lines from SAGE.
            obj.linesFetched = false;
            obj.lines();
        end
        
        
        function list = dataSetFamilies(obj)
            % Return a list of data set families for the lab.
            %
            % dataSetFamilies() returns all families for the lab.
            %
            % >> family = SAGE.Lab('olympiad').dataSetFamilies();
            % >> family[1].name
            % 
            % ans = 
            % 
            % aggression
            
            if ~obj.dataSetFamiliesFetched
                xmlDoc = xmlread([SAGE.urlbase 'datasets/' obj.name '.janelia-sage']);
                familyElems = xmlDoc.getElementsByTagName('dataSetFamily');
                obj.labDataSetFamilies = SAGE.DataSetFamily.empty(familyElems.getLength(), 0);
                for i = 0:familyElems.getLength()-1
                    familyElem = familyElems.item(i);
                    familyName = ''; familyDisplayName = ''; familyDescription = '';
                    childElems = familyElem.getChildNodes();
                    for j = 0:childElems.getLength()-1
                        childElem = childElems.item(j);
                        if childElem.getNodeType() == 1
                            if strcmp(childElem.getTagName(), 'name')
                                familyName = char(childElem.getTextContent());
                            elseif strcmp(childElem.getTagName(), 'displayName')
                                familyDisplayName = char(childElem.getTextContent());
                            elseif strcmp(childElem.getTagName(), 'description')
                                familyDescription= char(childElem.getTextContent());
                            end
                        end
                    end
                    obj.labDataSetFamilies(i+1) = SAGE.DataSetFamily(obj, familyName, familyDisplayName, familyDescription);
                end
                obj.dataSetFamiliesFetched = true;
            end
            list = obj.labDataSetFamilies;
        end
        
        
        function family = dataSetFamily(obj, name)
            % Return the data set family with the given name or [] if there is no such family.
            family = [];
            obj.dataSetFamilies();
            for i = 1:length(obj.labDataSetFamilies)
                if strcmp(obj.labDataSetFamilies(i).name, name)
                    family = obj.labDataSetFamilies(i);
                end
            end
        end
        
        
        function list = assays(obj)
            % Return a list of assays for the lab.
            %
            % assays() returns all assays for the lab.
            %
            % >> assays = SAGE.Lab('olympiad').assays();
            % >> assays[1].name
            % 
            % ans = 
            % 
            % aggression
            
            list = obj.dataSetFamilies();
        end
        
        
        function a = assay(obj, name)
            % Return a specific assay for the lab.
            %
            % >> boxAssay = SAGE.Lab('olympiad').assay('box');
            % >> assays[1].displayName
            % 
            % ans = 
            % 
            % The Box
            a = obj.dataSetFamily(name);
        end
        
        
        function dataSets(obj)
            % Return a list of data sets for the lab.
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
            % The list of data sets is cached, call the refreshDataSets method to update the list.
            
            xmlDoc = xmlread([SAGE.urlbase 'datasets/' obj.name '.janelia-sage']);
            dataSetElems = xmlDoc.getElementsByTagName('dataset');
            dataSets = SAGE.DataSet.empty(dataSetElems.getLength(), 0);
            for i = 0:dataSetElems.getLength()-1
                dataSetElem = dataSetElems.item(i);
                dataSetName = ''; dataSetDisplayName = ''; dataSetDefinition = '';
                childElems = dataSetElem.getChildNodes();
                for j = 0:childElems.getLength()-1
                    childElem = childElems.item(j);
                    if childElem.getNodeType() == 1
                        if strcmp(childElem.getTagName(), 'name')
                            dataSetName = char(childElem.getTextContent());
                        elseif strcmp(childElem.getTagName(), 'displayName')
                            dataSetDisplayName = char(childElem.getTextContent());
                        elseif strcmp(childElem.getTagName(), 'definition')
                            dataSetDefinition = char(childElem.getTextContent());
                        end
                    end
                end
                dataSets(i+1) = SAGE.DataSet(dataSetName, dataSetDisplayName, dataSetDefinition);
            end
        end
        
        
        function es = experiments(obj, varargin)
            % Return experiments run by the lab.
            %
            % >> exps = SAGE.Lab('olympiad').experiments('type', SAGE.CV('fly_olympiad_box').term('box'))
            % 
            % exps = 
            % 
            %   1x7210 SAGE.Experiment handle
            %   Package: SAGE
            %   ...
            %
            % >> exps = SAGE.Lab('olympiad').experiments('type', SAGE.CV('fly_olympiad_box').term('box'), 'name', '_20120314T')
            % 
            % exps = 
            % 
            %   1x32 SAGE.Experiment handle
            %   Package: SAGE
            %   ...
            
            loginParams.serviceName = 'Database';
            login = findLoginWithParams(loginParams);
            if isempty(login)
                error('SAGE:Lab:Error', 'You must be logged into a SAGE database instance to query for experiments.');
            end
            
            parser = inputParser;
            parser.addParamValue('type', [], @(x) isa(x, 'SAGE.CVTerm'));
            parser.addParamValue('name', '', @ischar);
            parser.parse(varargin{:});
            inputs = parser.Results;
            
            es = SAGE.Experiment.empty(0, 0);
            
            statement = login.database.createStatement();
            try
                query = ['select * from experiment_vw where lab = ''' obj.name ''''];
                if ~isempty(inputs.type)
                    query = [query ' and type = ''' inputs.type.name ''''];
                end
                if ~isempty(inputs.name)
                    query = [query ' and name like ''%' inputs.name '%'''];
                end
                query = [query ' order by name'];
                cursor = statement.executeQuery(query);
                try
                    while cursor.next()
                        expID = int64(cursor.getLong(1));
                        expName = char(cursor.getString(2));
                        cv = char(cursor.getString(3));
                        term = char(cursor.getString(4));
                        es(end + 1) = SAGE.Experiment(login.database, expID, expName, SAGE.CV(cv).term(term), obj); %#ok<AGROW>
                    end
                catch ME
                    cursor.close();
                    rethrow(ME);
                end
                close(cursor)
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
        
        function e = experiment(obj, name)
            % Return a specific experiment run by the lab.
            %
            % >> boxAssay = SAGE.Lab('olympiad').experiment('GMR_16H03_AE_01_shi_Athena_20120314T155329');
            % 
            % ans = 
            % 
            % ???
            
            loginParams.serviceName = 'Database';
            login = findLoginWithParams(loginParams);
            if isempty(login)
                error('SAGE:Lab:Error', 'You must be logged into a SAGE database instance to query for experiments.');
            end

            % Make sure the experiment has already been loaded.
            statement = login.database.createStatement();
            try
                cursor = statement.executeQuery(['select * from experiment_vw where name = ''' name ''' and lab = ''' obj.name '''']);
                try
                    if ~cursor.next()
                        error('SAGE:Lab:Error', 'Experiment ''%s'' does not exist in SAGE for %s.', name, obj.name);
                    else
                        expID = int64(cursor.getLong(1));
                        cv = char(cursor.getString(3));
                        term = char(cursor.getString(4));
                        e = SAGE.Experiment(login.database, expID, name, SAGE.CV(cv).term(term), obj);
                    end
                catch ME
                    cursor.close();
                    rethrow(ME);
                end
                close(cursor)
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
    end
    
    
    methods (Static, Access = private)
    
        function list = linesFromXML(lab, xmlElement)
            lineElems = xmlElement.getElementsByTagName('name');
            list = SAGE.Line.empty(0, 0);
            for i = 0:lineElems.getLength()-1
                lineElem = lineElems.item(i);
                lineName = char(lineElem.getTextContent());
                if ~strcmp(lineName, lab.name)
                    list(end + 1) = SAGE.Line(lab, lineName); %#ok<AGROW>
                end
            end
        end
    
    end
end
