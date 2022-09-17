classdef Experiment < SAGE.DBPropertyObject
    % The Experiment class represents an experiment run by a lab or group project.
    %
    % >> experiment = SAGE.Lab('olympiad').experiments('name', 'GMR_16H03_AE_01_shi_Athena_20120314T155329');
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
    % 
    % To get the list of sessions of a given type for the experiment:
    % 
    % >> sessions = exp.sessions('type', SAGE.CV('fly_olympiad').term('region'))
    % 
    % sessions = 
    % 
    %   1x7 SAGE.Session handle
    %   ...
    % 
    % To add a new session to the experiment:
    % 
    % >> tube = exp.createSession('2', SAGE.CV('fly_olympiad').term('region'), ...
    %                             SAGE.CV('lab').term('olympiad'), SAGE.Lab('rubin').line('GMR_16H03_AE_01'));
    % 
    % tube = 
    % 
    %   SAGE.Session handle
    %   Package: SAGE
    % 
    %   Properties:
    %     experiment: [1x1 SAGE.Experiment]
    %            lab: [1x1 SAGE.CVTerm]
    %           line: [1x1 SAGE.Line]
    %      annotator: ''
    %           type: [1x1 SAGE.CVTerm]
    %             db: [1x1 com.mysql.jdbc.JDBC4Connection]
    %             id: 8427521
    %           name: '2'
    % 
    % To get the list of phases for the experiment:
    % 
    % >> phases = exp.phases()
    % 
    % phases = 
    % 
    %   1x10 SAGE.Phase handle
    % 
    % To store matrix data associated with the experiment:
    % 
    % >> exp.storeData(rand(1, 1000), 'half', SAGE.CV('fly_olympiad_box').term('temperature'))
    
    
    properties
        lab
    end
    
    
    methods
        function obj = Experiment(db, id, name, type, lab)
            if nargin ~= 5
                error('SAGE:Experiment:Error', 'Wrong number of argument used to create an Experiment object.');
            end
            
            if ~isscalar(lab) || ~isa(lab, 'SAGE.Lab')
                error('SAGE:Experiment:Error', 'The lab used to create an experiment must be a SAGE.Lab instance.');
            end
            
            obj = obj@SAGE.DBPropertyObject(db, id, name, type);
            
            obj.tableName = 'experiment';
            % TODO: obj.updatableFields{end + 1} = 'lab';
            
            obj.lab = lab;
        end
        
        
        function sessions = sessions(obj, varargin)
            % TODO: Re-use any existing Session objects.  (need a cache that gets cleaned up on remove)
            %       Query for ID's only first then re-query for any sessions not in the cache.
            
            sessions = SAGE.Session.empty(0, 0);
            
            parser = inputParser;
            parser.addParamValue('type', [], @(x) isa(x, 'SAGE.CVTerm'));
            parser.addParamValue('line', [], @(x) isa(x, 'SAGE.Line'));
            parser.addParamValue('name', '', @ischar);
            parser.parse(varargin{:});
            inputs = parser.Results;
            
            query = ['select session.id as ''id'', ' ...
                            'session.name as ''name'', ' ...
                            'type_term.name as ''type_name'', ' ...
                            'type_cv.name as ''type_cv'', ' ...
                            'lab.name as ''lab_name'', ' ...
                            'line.name as ''line_name'', ' ...
                            'line_lab.name as ''line_lab'', ' ...
                            'session.annotator as ''annotator'' ' ...
                      'from session join line on (session.line_id = line.id) ' ...
                                   'join cv_term type_term on (type_term.id = session.type_id) ' ...
                                   'join cv type_cv on (type_cv.id = type_term.cv_id) ' ...
                                   'join cv_term lab on (lab.id = session.lab_id) ' ...
                                   'join cv_term line_lab on (line_lab.id = line.lab_id) ' ...
                     'where experiment_id = ' num2str(obj.id)];
            
            if ~isempty(inputs.type)
                query = [query ' and session.type_id = ' inputs.type.idQuery()];
            end
            if ~isempty(inputs.line)
                query = [query ' and session.line_id = ' inputs.line.idQuery()];
            end
            if ~isempty(inputs.name)
                % TODO: allow substring matching?
                query = [query ' and session.name = ''' inputs.name ''''];
            end
            
            query = [query ' order by session.name'];
            
            statement = obj.db.createStatement();
            try
                cursor = statement.executeQuery(query);
                try
                    while cursor.next()
                        sessionID = int64(cursor.getLong(1));
                        sessionName = char(cursor.getString(2));
                        try
                            typeName = char(cursor.getString(3));
                            typeCV = char(cursor.getString(4));
                            typeTerm = SAGE.CV(typeCV).term(typeName);
                        catch ME
                            error('SAGE:Experiment:Error', 'Could not look up the ''%s'' term from the ''%s'' CV: (%s)', typeName, typeCV, ME.message);
                        end
                        try
                            labName = char(cursor.getString(5));
                            sessionLab = SAGE.Lab(labName);
                        catch ME
                            error('SAGE:Experiment:Error', 'Could not look up the ''%s'' lab: (%s)', labName, ME.message);
                        end
                        try
                            lineName = char(cursor.getString(6));
                            lineLab = char(cursor.getString(7));
                            line = SAGE.Lab(lineLab).lines(lineName);
                        catch ME
                            error('SAGE:Experiment:Error', 'Could not look up the ''%s'' line from the ''%s'' lab: (%s)', lineName, lineLab, ME.message);
                        end
                        annotator = char(cursor.getString(8));
                        s = SAGE.Session(obj, sessionID, sessionName, typeTerm, sessionLab, line, annotator);
                        sessions(end + 1) = s; %#ok<AGROW>
                    end
                catch ME
                    cursor.close();
                    rethrow(ME);
                end
                cursor.close();
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
        
        function s = createSession(obj, name, type, lab, line, annotator)
            colNames = 'experiment_id, name, type_id';
            values = [num2str(obj.id) ', ''' name ''', ' type.idQuery()];
            if nargin > 3
                colNames = [colNames ', lab_id'];
                values = [values ', ' lab.idQuery()];
            else
                lab = [];
            end
            if nargin > 4
                colNames = [colNames ', line_id'];
                values = [values ', (' line.idQuery() ')'];
            else
                line = [];
            end
            if nargin > 5
                colNames = [colNames ', annotator'];
                values = [values ', ''' annotator ''''];
            else
                annotator = '';
            end
            try
                id = obj.executeSQL(sprintf('insert into session (%s) values (%s)', colNames, values));
            catch ME
                error('SAGE:Experiment:Error', 'Could not create the ''%s'' session: %s', type.name, ME.message);
            end
            
            s = SAGE.Session(obj, id, name, type, lab, line, annotator);
        end
        
        
        function phases = phases(obj, varargin)
            % TODO: Re-use any existing Phase objects.  (need a cache that gets cleaned up on remove)
            %       Query for ID's only first then re-query for any sessions not in the cache.
            
            phases = SAGE.Phase.empty(0, 0);
            
            parser = inputParser;
            parser.addParamValue('type', [], @(x) isa(x, 'SAGE.CVTerm'));
            parser.addParamValue('name', '', @ischar);
            parser.parse(varargin{:});
            inputs = parser.Results;
            
            query = ['select * from phase_vw where experiment_id = ' num2str(obj.id)];
            
            if ~isempty(inputs.type)
                query = [query ' and cv = ''' inputs.type.cv.name ''' and type = ''' inputs.type.name ''''];
            end
            if ~isempty(inputs.name)
                % TODO: allow substring matching?
                query = [query ' and name = ''' inputs.name ''''];
            end
            
            statement = obj.db.createStatement();
            try
                cursor = statement.executeQuery(query);
                try
                    while cursor.next()
                        phaseID = int64(cursor.getLong(1));
                        phaseName = char(cursor.getString(3));
                        cvName = char(cursor.getString(4));
                        termName = char(cursor.getString(5));
                        p = SAGE.Phase(obj, phaseID, phaseName, SAGE.CV(cvName).term(termName));
                        phases(end + 1) = p; %#ok<AGROW>
                    end
                catch ME
                    cursor.close();
                    rethrow(ME);
                end
                cursor.close();
            catch ME
                statement.close();
                rethrow(ME);
            end
            statement.close();
        end
        
        
        % TODO: function createPhase()
        
        
        function storeData(obj, data, dataFormat, dataType, session, phase)
            if ~isa(dataType, 'SAGE.CVTerm')
                error('SAGE:Experiment:Error', 'The type argument to storeData() must be a SAGE.CVTerm.');
            end
            
            [rows, cols] = size(data);
            
            if isempty(dataFormat)
                % Auto-detect the format.
                [encodedData, dataFormat] = SAGE.DataSet.encodeData(data); 
            else
                % Use the specified format.
                [encodedData, dataFormat] = SAGE.DataSet.encodeData(data, dataFormat); 
            end
            
            notApplicableTerm = SAGE.CV('fly_olympiad').term('not_applicable');
            
            % Build the SQL statement.
            if nargin < 5
                session = [];
            end
            if nargin < 6
                phase = [];
            end
            if isempty(session) && isempty(phase)
                colNames = 'experiment_id';
                values = num2str(obj.id);
            else
                if isempty(session)
                    colNames = 'phase_id';
                    values = num2str(phase.id);
                elseif isempty(phase)
                    colNames = 'session_id';
                    values = num2str(session.id);
                else
                    colNames = 'session_id, phase_id';
                    values = [num2str(session.id) ', ' num2str(phase.id)];
                end
            end
            query = ['insert into score_array (' colNames ', term_id, type_id, data_type, row_count, column_count, value) ' ...
                                      'values (' values ', ' ...
                                               notApplicableTerm.idQuery() ', ' ...
                                               dataType.idQuery() ', ' ...
                                               '''' dataFormat ''', ' ...
                                               num2str(rows) ', ' ...
                                               num2str(cols) ', ' ...
                                               'compress(''' encodedData ''')' ...
                                              ')'];
            try
                obj.executeSQL(query);
            catch ME
                error('SAGE:Experiment:Error', 'Could not store data.');
            end
        end
        
        
        % TODO:
%         function set.lab(obj, lab)
%             obj.update('lab', lab);
%         end
        
        
        % TODO: can anything be done to delete (not remove) sessions and phases if an experiment is removed?
        
    end
    
end