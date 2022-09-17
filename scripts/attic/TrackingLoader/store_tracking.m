% Store the tracking data for an experiment.

function [result] = store_tracking(sage_config_path, experiment_dir_path)
    % TODO: doc
    
    try
        if nargin == 0
            if isdeployed
                fprintf(2, 'Usage: store_experiment <path to SAGE config file> <path to box data folder>\n') %#ok<PRTCAL>
            else
                error('The SAGE config file path and the path to the experiment folder were not specified.');
            end
            result = 2;
            return;
        end
        
        % Look up the various terms we need.
        olympiadLab = SAGE.Lab('olympiad');
        boxCV = SAGE.CV('fly_olympiad_box');
        regionTerm = boxCV.term('region');
        trackingTerm = boxCV.term('tracking');
        versionTerm = boxCV.term('version');
        sequenceTerm = boxCV.term('sequence');
        temperatureTerm = boxCV.term('temperature_setpoint');
        performedInTerm = boxCV.term('was_performed_in');
        
        SAGE.login('Database', 'configFile', sage_config_path);
        
        [parent_dir, experiment_name, dir_ext] = fileparts(experiment_dir_path); %#ok
        
        % The directory will never have an extension so put the pieces back together. (BOXPIPE-70)
        experiment_name = [experiment_name dir_ext];
        
        % Make sure the experiment has already been loaded.
        experiment = olympiadLab.experiment(experiment_name);
        
        % Load the experiment parameters.
        expData = load(fullfile(experiment_dir_path, [experiment_name '.exp']), '-mat');
        source = expData.experiment.actionsource(1);
        protocol = expData.experiment.actionlist(1, source).name;
        
        % Wrap everything else in a try block so we can atomically commit or rollback all of the inserts.
        experiment.beginChanges();
        try
            % Load each of the Output directories.
            outputDirs = dir(fullfile(experiment_dir_path, 'Output*'));
            for i = 1:length(outputDirs)
                if outputDirs(i).isdir
                    outputDir = fullfile(experiment_dir_path, outputDirs(i).name);
                    
                    % Loop through each temperature.
                    for source = expData.experiment.actionsource
                        temperature = expData.experiment.actionlist(1, source).T;
                        sub_dir_name = sprintf('%02d_%s_%d', source, protocol, temperature);
                        
                        % Figure out which version of tracking was used in this output folder.
                        ai_name = sprintf('%02d_%s_seq1_analysis_info.mat', source, protocol);
                        ai_path = fullfile(outputDir, sub_dir_name, ai_name);    
                        try
                            load(ai_path, 'analysis_info_tube');
                        catch ME
                            fprintf('Could not determine the version of tracking being loaded. (%s)', ME.message);
                            rethrow(ME);
                        end
                        if isfield(analysis_info_tube, 'version')
                            trackingVersion = analysis_info_tube(1, 1).version;
                        else
                            % If the version field is missing then it's the original tracking data.
                            trackingVersion = '1.0';
                        end
                        clear analysis_info_tube;
                        
                        % Get the tube sessions.
                        tubes = experiment.sessions('type', regionTerm);
                        if isempty(tubes)
                            error('No ''region'' sessions exist for experiment %s.  Make sure the metadata has been loaded.', experiment_name);
                        end
                        
                        % Create an easily indexed set of the existing tracking sessions.
                        sessions = experiment.sessions('type', trackingTerm);
                        trackings = cell(6, 5, 34);
                        for tracking = sessions
                            if strcmp(trackingVersion, tracking.getProperty(versionTerm))
                                re = tracking.getProperty(regionTerm);
                                se = tracking.getProperty(sequenceTerm);
                                te = tracking.getProperty(temperatureTerm);
                                if isempty(te)
                                    te = tracking.getProperty(otherTempTerm);
                                end
                                if ~isempty(re) && ~isempty(se) && ~isempty(te)
                                    trackings{str2double(re), str2double(se), str2double(te)} = tracking;
                                end
                            end
                        end
                        
                        % Look up the sequences for this temperature.
                        sequences = experiment.phases('type', boxCV.term(['sequence_' num2str(temperature)]));
                        if isempty(sequences)
                            error('SAGE:Error' , 'No sequence_%d phases exist for experiment %s.', temperature, experiment_name);
                        end
                        
                        % Loop through the possible sequences and see if they exist on disk.
                        for sequence = sequences
                            for tube = tubes
                                % Check if the tracking has already been loaded for this output folder, temperature, sequence and tube.
                                tracking = trackings{str2double(tube.name), str2double(sequence.name), temperature};
                                if isempty(tracking)
                                    % Load the tracking.
                                    tube_name = sprintf('%02d_%s_seq%s_tube%s', source, protocol, sequence.name, tube.name);
                                    analysis_path = fullfile(outputDir, sub_dir_name, tube_name, 'analysis_info.mat');    
                                    try
                                        load(analysis_path, 'analysis_info');
                                        
                                        if ~exist('analysis_info', 'var')
                                            error('No analysis_info structure was found.')
                                        else
                                            sessionName = sprintf('Tracking %s for tube %s, sequence %s @ %d degrees', trackingVersion, tube.name, sequence.name, temperature);
                                            trackingSession = experiment.createSession(sessionName, trackingTerm, olympiadLab, tube.line);
                                            trackingSession.setProperty(versionTerm, trackingVersion);
                                            trackingSession.setProperty(regionTerm, tube.name);
                                            trackingSession.setProperty(sequenceTerm, sequence.name);
                                            trackingSession.setProperty(temperatureTerm, num2str(temperature));
                                            
                                            % Add a relationship between the tube and tracking sessions.
                                            trackingSession.createRelationship(tube, performedInTerm);
                                            
                                            fields = fieldnames(analysis_info);
                                            for field_num = 1:length(fields)
                                                field_name = fields{field_num};
                                                trackingData = analysis_info.(field_name);
                                                if ~ismember(field_name, {'version', 'pos_hist', 'move_pos_hist'})
                                                    if isfloat(trackingData) && any(strcmp(field_name, {'tracked_num', 'moving_num', 'moving_num_left', 'moving_num_right', 'start_move_num', 'pos_hist', 'move_pos_hist', 'max_tracked_num', 'index'}))
                                                        % These fields are actually int values even though they are in double matrices.  Convert to save a lot of space.
                                                        trackingData = int16(trackingData);
                                                        dataFormat = '';
                                                    else
                                                        % Half precision is enough for the tracking data.
                                                        dataFormat = 'half';
                                                    end
                                                    fieldTerm = boxCV.term(field_name);
                                                    if isempty(fieldTerm)
                                                        error('Unknown field name: %s', field_name);
                                                    end
                                                    trackingSession.storeData(trackingData, dataFormat, fieldTerm);
                                                end
                                            end
                                            
                                            clear analysis_info
                                        end
                                    catch ME
                                        fprintf('Could not store tracking for %s (%s)', tube_name, ME.message);
                                        rethrow(ME);
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            % Commit the entire experiment.
            experiment.endChanges();
            
            % Indicate a clean exit.
            result = 0;
        catch ME
            % Something went wrong.  Undo all changes to the experiment so it's in a consistent state.
            experiment.undoChanges();
            rethrow(ME);
        end
    catch ME
        rethrow(ME);
    end
end
