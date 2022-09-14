% Store the data for an experiment.

function [result] = store_experiment(sage_params_path, experiment_dir_path)
    % TODO: doc
        
    if nargin == 0
        if isdeployed
            fprintf(2, 'Usage: store_experiment <path to SAGE params file> <path to box data folder>\n\nSAGE params file should contain:\n\nhost: <host name>\ndatabase: <database name>\nusername: <user name>\npassword: <password>')
        else
            error('No parameters supplied.');
        end
        result = 2;
        return;
    else
        % Assume success
        result = 0;
    end
    
    % fields of run_data.data structure to ignore
    run_data_ignore_fields = {'totalDurationStr','validation'};

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
            message = [db.Message char(10) char(10) 'Make sure you the path to the MySQL Connector JAR file is in the CLASSPATH.'];
        else
            message = db.Message;
        end
        error(['Could not create database connection: ' message]);
    end

    %% Wrap everything else in an exception handler so that the DB connection is guaranteed to be closed.
    try
        [parent_dir, experiment_name, dir_ext, dir_version] = fileparts(experiment_dir_path); %#ok
        if isempty(experiment_name)
            % The path was specified with a trailing slash.
            experiment_dir_path = parent_dir;
            [parent_dir, experiment_name, dir_ext, dir_version] = fileparts(experiment_dir_path); %#ok
        end
        
        % The directory will never have an extension or version so put the pieces back together. (BOXPIPE-68)
        experiment_name = [experiment_name dir_ext dir_version];
        
        parts = regexp(experiment_name, '(.+)_([^_]+)', 'tokens');
        experiment_name_without_date_time = char(parts{1}(1));

        %% Make sure the experiment hasn't already been loaded.
        curs = exec(db, ['select id from experiment where name = ''' experiment_name '''']);
        curs = fetch(curs);
        if ~strcmp(curs.Data{1}, 'No Data')
            error('olympiadDB:experimentExists', 'The experiment has already been loaded.');
        end

        %% SQL fragment to lookup the Olympiad lab id.
        olympiadLabID = 'getCvTermId(''lab'', ''olympiad'', NULL)';

        %% Add the experiment to the DB.
        % Do this first so that any errors that occur have a place to hook onto.
        experimenter = '';
        curs = exec(db, ['insert into experiment (name, type_id, lab_id, experimenter) values (''' experiment_name ''', ' cv_term('box') ', ' olympiadLabID ', ''' experimenter ''')']);
        if ~isempty(curs.Message)
            error(['Could not add experiment ''' experiment_name ''': ' curs.Message]);
        end
        statement = get(curs, 'Statement');
        experiment_id = get(statement, 'lastInsertID');
        close(curs);

        %% Load the rest of the metadata.
        try
            %% Load the experiment parameters.
            data = load(fullfile(experiment_dir_path, [experiment_name '.exp']), '-mat');
            source = data.experiment.actionsource(1);
            protocol = data.experiment.actionlist(1, source).name;
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

            %% Load one of the sequence detail files which actually has experiment and session (tube) properties in its exp_detail structure.
            sub_dir_name = sprintf('%02d_%s_%d', source, protocol, data.experiment.actionlist(1, source).T);
            sequence_details = textread(fullfile(experiment_dir_path, sub_dir_name, ['sequence_details_' experiment_name_without_date_time '.m']), '%s', 'delimiter', '\n', 'whitespace', '');

            %% Add any experiment properties.
            add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'file_system_path', experiment_dir_path);
            add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'protocol', protocol);
            fields = regexp(sequence_details, '(?<name>exp_detail.date_time|BoxName|TopPlateID) = ''(?<value>[^'']+)'';', 'names');
            for field_ind = 1:length(fields)
                field = fields{field_ind};
                if length(field) == 1
                    if strcmp(field.name, 'exp_detail.date_time')
                        field.name = 'date_time';
                    end
                    cv_field_name = lower(regexprep(field.name, '([^_])([A-Z])', '$1_$2'));
                    add_experiment_property(db, experiment_id, 'fly_olympiad_box', cv_field_name, field.value)
                end
            end
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
                
                %% Special case code for handling temporary 'validation' structure added to data field.
                % These fields are being moved to the root data structure in future runs and the validation structure will not be created.
                if isfield(run_data.data, 'validation')
                    if ~isstruct(run_data.data.validation)
                        error('The ''data.validation'' field in the RunData file must be a structure.');
                    end
                    if isfield(run_data.data.validation, 'techIssue')
                        add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'issue_technical', run_data.data.validation.techIssue);
                    end
                    if isfield(run_data.data.validation, 'techNotes') && ~isempty(run_data.data.validation.techNotes)
                        add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'notes_technical', run_data.data.validation.techNotes);
                    end
                    if isfield(run_data.data.validation, 'behaveIssue')
                        add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'issue_behavioral', run_data.data.validation.behaveIssue);
                    end
                    if isfield(run_data.data.validation, 'behaveNotes') && ~isempty(run_data.data.validation.behaveNotes)
                        add_experiment_property(db, experiment_id, 'fly_olympiad_box', 'notes_behavioral', run_data.data.validation.behaveNotes);
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
                cv_field_name = field_name;
                % no need to do this for run_data root fields:
                % Convert the field name to CV style: all lower case with _'s between words.
                %cv_field_name = lower(regexprep(field_name, '([^_])([A-Z])', '$1_$2'));
                add_score_array(db, experiment_id, cv_field_name, field_data);
              end
            end

            %% Add the sessions (tubes).
            tube_count = 6; %length(exp_detail.tube_info);
            for tube_num = 1:tube_count
                line_name = regexp(strcat(sequence_details{:}), ['\[exp_detail.tube_info\(' num2str(tube_num) '\).Line\] = ['']?(?<value>[^'']*)['']?;'], 'tokens');
                if isempty(line_name)
                    line_name = '';
                else
                    line_name = char(line_name{1});
                end
                
                effector = regexp(strcat(sequence_details{:}), ['\[exp_detail.tube_info\(' num2str(tube_num) '\).Effector\] = ['']?(?<value>[^'']*)['']?;'], 'tokens');
                if isempty(effector)
                    effector = '';
                else
                    effector = char(effector{1});
                end
                
                tube_genotype = regexp(strcat(sequence_details{:}), ['\[exp_detail.tube_info\(' num2str(tube_num) '\).Genotype\] = ['']?(?<value>[^'']*)['']?;'], 'tokens');
                tube_genotype = char(tube_genotype{1});
                
                if isempty(line_name) && isempty(effector)
                    %% Try to extract the line name and effector from the genotype.
                    
                    if any(strfind(tube_genotype, ';'))
                        % Assume the line name is everything up to the first semi-colon and the effector is everything after the last.
                        parts = regexp(tube_genotype, '([^;]+);.*;([^;]+)', 'tokens', 'once');
                        if isempty(parts)
                            parts = regexp(tube_genotype, '([^;]+);([^;]+)', 'tokens', 'once');
                            if isempty(parts)
                                error(['Could not extract line name and effector from genotype ''' tube_genotype '''']);
                            end
                        end
                        line_name = char(parts{1});
                        effector = char(parts{2});
                    else
                        % Check if the genotype is in 'line & effector' format.
                        parts = regexp(tube_genotype, '([^& ]+) *& *([^& ]+)', 'tokens', 'once');
                        if numel(parts) == 2
                            % It is so use the parts.
                            line_name = parts{1};
                            effector = parts{2};
                        else
                            % Assume the entire genotype string is the line name.
                            line_name = tube_genotype;
                            effector = '';
                        end
                    end
                    
                    if regexp(line_name, '^.* & w\+$')
                        % Strip ' & w+' off the end of the name.
                        line_name = line_name(1:end-5);
                    end
                    if regexp(line_name, '^.* & w$')
                        % Strip ' & w' off the end of the name.
                        line_name = line_name(1:end-4);
                    end
                end

                %% Special case handling for GMR line names.
                if regexp(line_name, '0[0-9][A-Z][0-9][0-9]_[A-Z][A-Z]_[0-9][0-9]') == 1
                    % Convert names like '09A01_AE_01' to 'GMR_9A01_AE_01' (note dropping the leading zero)
                    line_name = ['GMR_' line_name(2:end)]; %#ok
                elseif regexp(line_name, '[0-9]{1,3}[A-Z][0-9][0-9]_[A-Z][A-Z]_[0-9][0-9]') == 1
                    % Convert names like '27A01_AE_01' to 'GMR_27A01_AE_01'
                    line_name = ['GMR_' line_name]; %#ok
                end

                %% Handle line name synonyms
                for index = 1:size(line_synonyms, 1)
                    if strcmp(line_name, line_synonyms{index, 1})
                        line_name = line_synonyms{index, 2};
                        break
                    end
                end

                %% Look up the line
                curs = exec(db, ['select id, lab from line_vw where name = ''' line_name '''']);
                if ~isempty(curs.Message)
                    error(['Could not look up the line in SAGE: ' curs.Message]);
                else
                    curs = fetch(curs);
                    if strcmp(curs.Data{1}, 'No Data')
                        error(['There is no line named ''' line_name ''' in SAGE.'])
                    elseif size(curs.Data, 1) > 1
                        % If the line name exists in more than one lab then pick one based on priority.
                        line_id = [];
                        for lab_name = {'olympiad', 'rubin', 'simpson', 'baker'}
                            line_id = curs.Data{find(strcmp(curs.Data(:,2), char(lab_name))), 1};
                            if ~isempty(line_id)
                                break
                            end
                        end
                        if isempty(line_id)
                            error(['Could not determine which of the lines in SAGE named ''' line_name ''' to use.'])
                        end
                    else
                        % A single line was found.
                        line_id = curs.Data{1, 1};
                    end
                end

                %% Make sure the effector name is valid.
                curs = exec(db, ['select ' cv_term(effector, 'effector')]);
                curs = fetch(curs);
                if strcmp(curs.Data{1}, 'No Data') || isnan(curs.Data{1})
                    error('There is no effector named ''%s'' in SAGE.', effector);
                else
                    % Lookup the name in case we had a synonym.
                    effectorID = curs.Data{1, 1};
                    curs = exec(db, ['select getCvTermName(' num2str(effectorID) ')']);
                    curs = fetch(curs);
                    effector = curs.Data{1, 1};
                end
                
                %% Add the session to the dB.
                curs = exec(db, ['insert into session (name, type_id, line_id, experiment_id, lab_id) values (''' num2str(tube_num) ''', ' ...
                                                                                                              cv_term('region') ', ' ...
                                                                                                              num2str(line_id) ', ' ...
                                                                                                              num2str(experiment_id) ', ' ...
                                                                                                              olympiadLabID ')']);
                if ~isempty(curs.Message)
                    error(['Could not add tube ''' num2str(tube_num) ''' to experiment ''' experiment_name ''': ' curs.Message]);
                end
                statement = get(curs, 'Statement');
                session_id = get(statement, 'lastInsertID');
                close(curs);

                %% Add the session properties to the DB.
                if ~isempty(effector)
                    add_session_property(db, session_id, 'effector', effector)
                end
                fields = regexp(sequence_details, ['\[exp_detail.tube_info\(' num2str(tube_num) '\).(?<name>\w+)\] = ['']?(?<value>[^'']*)['']?;'], 'names');
                for field_ind = 1:length(fields)
                    field = fields{field_ind};
                    if length(field) == 1 && ~strcmpi(field.name, 'line') && ~strcmpi(field.name, 'effector') 
                        add_session_property(db, session_id, lower(field.name), field.value)
                    end
                end
            end

            %% Add the phases (sequences)
            % Loop through each temperature.
            for source = data.experiment.actionsource
                temp = data.experiment.actionlist(1, source).T;

                %% Loop through the possible sequence numbers and see if they exist on disk.
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

                    %% Add the temperature property.
                    curs = exec(db, ['insert into phase_property (phase_id, type_id, value) values (' num2str(phase_id) ', ' cv_term('temperature') ', ' num2str(temp) ')']);
                    if ~isempty(curs.Message)
                        error(['Could not add phase #' num2str(phase_id) ' properties: ' curs.Message]);
                    end
                    close(curs);
                end
            end
        catch ME
            [pathstr, name, ext, versn] = fileparts(ME.stack(1).file); %#ok<NASGU>
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


%%
function add_session_property(db, session_id, property_name, property_value)
    curs = exec(db, ['insert into session_property (session_id, type_id, value) values (' num2str(session_id) ', ' cv_term(property_name) ', ''' property_value ''')']);
    if ~isempty(curs.Message)
        error(['Could not add session #' num2str(session_id) ' ''' property_name ''' property: ' curs.Message]);
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
      error(['Could not add experiment #' num2str(experiment_id) ' ''' property_name ''' score_array: ' curs.Message]);
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
