% Store the non-metadata for an experiment from the .exp and RunData files.

function [result] = store_experiment_data(sage_params_path, experiment_dir_path)
    % TODO: doc
        
    if nargin == 0
        if isdeployed
            fprintf(2, 'Usage: store_experiment_data <path to SAGE params file> <path to box data folder>\n\nSAGE params file should contain:\n\nhost: <host name>\ndatabase: <database name>\nusername: <user name>\npassword: <password>') %#ok<PRTCAL>
        else
            error('No parameters supplied.');
        end
        result = 2;
        return;
    else
        % Assume success
        result = 0;
    end
    
    % fields of run_data.data structure to ignore (some aren't wanted, some are now handled by the universal loader)
    run_data_ignore_fields = {'Questionable_Data', 'Redo_Experiment', 'NotesBehavioral', 'NotesTechnical', 'behaveIssue', 'techIssue', 'Operator', 'totalDurationStr', 'haltEarly', 'validation'};

    % added by KB: fields of run_data root to ignore. 
    % TODO: maybe capture RH = room humidity in the future
    run_data_root_ignore_fields = {'bounds','OperatorName','temperature','RH'};

    %% Make sure the MySQL client JAR can be found.
    warning off MATLAB:javaclasspath:jarAlreadySpecified
    classpath = getenv('CLASSPATH');
    for path = regexp(classpath, ':', 'split')
        javaaddpath(path);
    end

    %% Read the parameter file.
    fid = fopen(sage_params_path);
    line_synonyms = {};
    try
        params = strtrim(textscan(fid, '%s %s'));
        host = params{2}{strmatch('host:', params{1})};
        db_name = params{2}{strmatch('database:', params{1})};
        user_name = params{2}{strmatch('username:', params{1})};
        password = params{2}{strmatch('password:', params{1})};
        for index = strmatch('line-synonym:', params{1})'
            syn_count = size(line_synonyms, 1);
            parts = regexp(params{2}{index}, '=', 'split');
            line_synonyms{syn_count + 1, 1} = parts{1}; %#ok
            line_synonyms{syn_count + 1, 2} = parts{2}; %#ok
        end
        fclose(fid);
    catch ME
        fclose(fid);
        rethrow(ME);
    end

    %% Connect to SAGE
    db = database(db_name, user_name, password, 'com.mysql.jdbc.Driver', ['jdbc:mysql://' host '/' db_name]);

    if ~isempty(db.Message)
        if strcmp(db.Message, 'JDBC Driver Error: com.mysql.jdbc.Driver. Driver Not Found/Loaded.')
            message = [db.Message char(10) char(10) 'Make sure the path to the MySQL Connector JAR file is in the CLASSPATH.'];
        else
            message = db.Message;
        end
        error(['Could not create database connection: ' message]);
    end

    %% Wrap everything else in an exception handler so that the DB connection is guaranteed to be closed.
    try
        [parent_dir, experiment_name, dir_ext] = fileparts(experiment_dir_path);
        if isempty(experiment_name)
            % The path was specified with a trailing slash.
            experiment_dir_path = parent_dir;
            [~, experiment_name, dir_ext] = fileparts(experiment_dir_path);
        end
        
        % The directory will never have an extension so put the pieces back together. (BOXPIPE-68)
        experiment_name = [experiment_name dir_ext];
        
        parts = regexp(experiment_name, '(.+)_([^_]+)', 'tokens');
        experiment_name_without_date_time = char(parts{1}(1));
        
        %% Make sure the experiment has already been created by the universal loader.
        % TODO: escape experiment_name to avoid SQL injection?
        curs = exec(db, ['select id from experiment where name = ''' experiment_name ''' and type_id = getCvTermId(''fly_olympiad_box'', ''box'', NULL)']);
        curs = fetch(curs);
        if strcmp(curs.Data{1}, 'No Data')
            error('Experiment ''%s'' is not in SAGE.  Please use store_experiment to load it.', experiment_name);
        else
            experiment_id = curs.Data{1};
        end
        close(curs)

        try
            %% Load the RunData file.
            run_data = load(fullfile(experiment_dir_path, [experiment_name_without_date_time '_RunData.mat']));

            %% add in missing vibration data
            % added by KB
            vibration_numel = [numel(run_data.vibrationX),numel(run_data.vibrationY),numel(run_data.vibrationZ)];
            if ~all(vibration_numel == vibration_numel(1)),
              warning('Lengths of vibration X (len=%d), Y (len=%d), and Z (len=%d) do not match: cropping vibration_magnitude to match shortest',vibration_numel); %#ok<WNTAG>
            end
            min_vibration_numel = min(vibration_numel);
            run_data.vibration_magnitude = sqrt(run_data.vibrationX(1:min_vibration_numel).^2 + ...
              run_data.vibrationY(1:min_vibration_numel).^2 + ...
              run_data.vibrationZ(1:min_vibration_numel).^2);
            run_data.data.maxVibration = max(run_data.vibration_magnitude);
            
            %% Add any desired experiment properties not handled by the universal loader.
            % Currently this leaves: forceSeqStart, totalDurationSeconds, maxVibration, transitionDuration, hotMaxVar, coolMaxVar, errorcode, failure, calibratezz, zzcalOfset, NIST, Cal and resolution.
            % The list five are actually metadata (known before experiment start) and probably should be handled by the universal loader...
            if isfield(run_data, 'data')
                % Add all of the fields of the 'data' structure from the *_RunData.mat file.
                % (Except for the ones named in run_data_ignore_fields).
                field_names = fieldnames(run_data.data);
                for field_ind = 1:length(field_names)
                    field_name = field_names{field_ind};
                    if ~any(strmatch(field_name, run_data_ignore_fields))
                        % Convert the field name to CV style: all lower case with _'s between words.
                        if all(isstrprop(field_name, 'upper'))
                            cv_field_name = lower(field_name);
                        else
                            cv_field_name = lower(regexprep(field_name, '([^_])([A-Z])', '$1_$2'));
                        end
                        
                        field_data = run_data.data.(field_name);
                        if numel(field_data) < 2 || (ischar(field_data) && size(field_data, 1) == 1)
                            % Store the value of the field as a property string.
                            if isnumeric(field_data)
                                field_data = num2str(field_data);
                            end
                            if ~ischar(field_data)
                                error('The values in the ''data'' structure in the RunData file must be numeric or strings.');
                            end

                            add_experiment_property(db, experiment_id, 'fly_olympiad_box', cv_field_name, field_data);
                        else
                            % Store the value as a score array.
                            add_score_array(db, experiment_id, cv_field_name, field_data);
                        end
                    end
                end
            end
            
            %% Add fields at the root level of run_data
            % added by KB
            field_names = setdiff(fieldnames(run_data),'data');
            for field_ind = 1:length(field_names)
              field_name = field_names{field_ind};
              if ~any(strmatch(field_name, run_data_root_ignore_fields))
                % Get the value of the field as a string.
                field_data = run_data.(field_name);
                if strcmp(field_name, 'setpoint')
                  cv_field_name = 'temperature_setpoint';
                else
                  cv_field_name = field_name;
                end
                if numel(field_data) < 2 || (ischar(field_data) && size(field_data, 1) == 1)
                    % Store the value of the field as a property string.
                    if isnumeric(field_data)
                        field_data = num2str(field_data);
                    end
                    if ~ischar(field_data)
                        error('The values in the root structure in the RunData file must be numeric or strings.');
                    end
                    
                    add_experiment_property(db, experiment_id, 'fly_olympiad_box', cv_field_name, field_data);
                else
                    add_score_array(db, experiment_id, cv_field_name, field_data);
                end
              end
            end
            
            %% Add the phases (sequences)
            % TODO: This information is also kept in the experiment protocol file and could potentially be universally loaded from there some day...
            data = load(fullfile(experiment_dir_path, [experiment_name '.exp']), '-mat');
            % Loop through each temperature.
            for source = data.experiment.actionsource
                temp = data.experiment.actionlist(1, source).T;

                %% Loop through the possible sequence numbers.
                sequence_count = 5;  %length(analysis_detail.seq);           
                for i = 1:sequence_count
                    %% Add the phase (sequence) to the DB.
                    curs = exec(db, ['insert into phase (experiment_id, name, type_id) values (' num2str(experiment_id) ', ' num2str(i) ', ' cv_term(['sequence_' num2str(temp)]) ')']);
                    if ~isempty(curs.Message)
                        error(['Could not add phase ''' num2str(i) ''' to experiment ''' experiment_name ''': ' curs.Message]);
                    end
                    statement = get(curs, 'Statement');
                    phase_id = get(statement, 'lastInsertID');
                    close(curs);

                    %% Add the temperature_setpoint property.
                    curs = exec(db, ['insert into phase_property (phase_id, type_id, value) values (' num2str(phase_id) ', ' cv_term('temperature_setpoint') ', ' num2str(temp) ')']);
                    if ~isempty(curs.Message)
                        error(['Could not add phase #' num2str(phase_id) ' properties: ' curs.Message]);
                    end
                    close(curs);
                end
            end
        catch ME
            [~, name, ext] = fileparts(ME.stack(1).file);
            add_experiment_property(db, experiment_id, 'fly_olympiad_qc_box', 'loadmetadata_error_message', ['Load was incomplete: ' ME.message '  (' name ext ':' num2str(ME.stack(1).line) ')']);
            rethrow(ME)
        end
    catch ME
        close(db);
        rethrow(ME);
    end
    close(db);
end


%%
function escaped_string = escape_string(raw_string)
    cell_array = cellstr(raw_string);
    escaped_string = '';
    for i = 1:size(cell_array, 1)
        escaped_string = [escaped_string cell_array{i, 1} char(10)]; %#ok
    end
    escaped_string = escaped_string(1:end-1);
    escaped_string = strrep(escaped_string, '\', '\\');
    escaped_string = strrep(escaped_string, '''', '\''');
end


%%
function add_experiment_property(db, experiment_id, cv_name, property_name, property_value)
    curs = exec(db, ['insert into experiment_property (experiment_id, type_id, value) values (' num2str(experiment_id) ', ' cv_term(property_name, cv_name) ', ''' escape_string(property_value) ''')']);
    if ~isempty(curs.Message)
        error(['Could not add experiment #' num2str(experiment_id) ' ''' property_name ''' property: ' curs.Message]);
    end
    close(curs);
end


%% added by KB
% add score_array entry

function add_score_array(db, experiment_id, property_name, property_value)

    [encoded_data, data_type] = SAGE.DataSet.encodeData(property_value);
    [rows,cols] = size(property_value);
    query = ['insert into score_array (experiment_id, term_id, type_id, data_type, row_count, column_count, value) values (' num2str(experiment_id) ', ' ...
      cv_term('not_applicable') ', ' ...
      cv_term(property_name) ', ' ...
      '''' data_type ''', ' ...
      num2str(rows) ', ' ...
      num2str(cols) ', ' ...
      'compress(''' encoded_data '''))'];
    curs = exec(db, query);
    if ~isempty(curs.Message)
      error(['Could not add ''' property_name ''' score_array to experiment #' num2str(experiment_id) ': ' curs.Message]);
    end
    close(curs);
end


%%
function term_lookup = cv_term(term_name, cv_name)
    % Create the SQL lookup string for the CV term.
    if nargin == 1
        cv_name = 'fly_olympiad_box';
    end
    term_lookup = ['getCvTermId(''' cv_name ''', ''' escape_string(term_name) ''', NULL)'];
end
