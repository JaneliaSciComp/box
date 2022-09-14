function ConvertToTrackingSessions(startInd, varargin)
    % 1. Create a new 'tracking' session for every existing 'region' session.
    % 2. Re-assign all 'analysis_info' score arrays from the region sessions to the new tracking sessions.
    % 3. Create a 'was_performed_in' relationship between the region and tracking sessions.
    % 4. Add " of tracking 1.0" to the name of all 'analysis' sessions.
    % 5. Create a 'was_performed_in' relationship between the region and analysis sessions.
    % 6. Create a 'derived_from' relationship between the tracking and analysis sessions.
    
    if nargin < 1
        startInd = 1;
    elseif ischar(startInd)
        startInd = str2double(startInd);
    end
    if nargin < 2
        experimentNames = {};
    else
        experimentNames = varargin;
    end
    
    SAGE.login('Database', 'configFile', '/groups/flyprojects/home/olympiad/config/SAGE-prod.config');
    
    waitBarHandle = []; %waitbar(0, 'Getting the list of box experiments...', ...
                        %    'Name', 'Converting box experiments', ...
                        %    'CreateCancelBtn', 'setappdata(gcbf, ''canceling'', 1)');
    if isempty(waitBarHandle)
        display('Getting the list of box experiments...');
        display('(Enable the wait bar to allow clean cancelling.)');
    end

    olympiadLab = SAGE.Lab('olympiad');
    if isempty(experimentNames)
        experiments = olympiadLab.experiments('type', SAGE.CV('fly_olympiad_box').term('box'));
    else
        experiments = SAGE.Experiment.empty(0, length(experimentNames));
        for i = 1:length(experimentNames)
            experiments(i) = olympiadLab.experiment(experimentNames{i});
        end
    end
    
    % Session type terms
    regionTerm = SAGE.CV('fly_olympiad_box').term('region');
    trackingTerm = SAGE.CV('fly_olympiad_box').term('tracking');
    analysisTerm = SAGE.CV('fly_olympiad_box').term('analysis');
    
    % Relationship terms
    performedInTerm = SAGE.CV('fly_olympiad_box').term('was_performed_in');
    derivedFromTerm = SAGE.CV('schema').term('is_derived_from');
    
    % Session property terms
    versionTerm = SAGE.CV('fly_olympiad_box').term('version');
    sequenceTerm = SAGE.CV('fly_olympiad_box').term('sequence');
    temperatureTerm = SAGE.CV('fly_olympiad_box').term('temperature_setpoint');
    otherTempTerm = SAGE.CV('fly_olympiad_box').term('temperature');
    
    expCount = startInd;
    for experiment = experiments(expCount:end)
        % Let the user know how far we've gotten.
        fractionComplete = expCount / size(experiments, 2);
        if isempty(waitBarHandle)
            display(['[' sprintf('%05.2f%%, %d', fractionComplete * 100, expCount) '] Converting ' experiment.name '...']);
        else
            if getappdata(waitBarHandle,'canceling')
                break
            else
                waitbar(fractionComplete, waitBarHandle, strrep(experiment.name, '_', ' '));
            end
        end
        expCount = expCount + 1;
        
        try
            % Look up the list of sequences (phases) and regions (tubes) for the experiment.
            % If either are empty then something is wrong.  There should be six tubes and five or ten phases.
            sequences = experiment.phases();
            if isempty(sequences)
                warning('No phases exist for experiment %s.', experiment.name);
                continue
            end
            regions = experiment.sessions('type', regionTerm);
            if isempty(regions)
                warning('No regions exist for experiment %s.', experiment.name);
                continue
            end
            
            % Create an easily indexed set of the existing tracking sessions.
            sessions = experiment.sessions('type', trackingTerm);
            trackings = cell(6, 5, 34);
            for tracking = sessions
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
            
            % Create an easily indexed set of the existing analysis sessions.
            sessions = experiment.sessions('type', analysisTerm);
            analyses = cell(6, 5, 34);
            for analysis = sessions
                re = analysis.getProperty(regionTerm);
                se = analysis.getProperty(sequenceTerm);
                te = analysis.getProperty(temperatureTerm);
                if isempty(te)
                    te = analysis.getProperty(otherTempTerm);
                end
                if ~isempty(re) && ~isempty(se) && ~isempty(te)
                    analyses{str2double(re), str2double(se), str2double(te)} = analysis;
                end
            end
            
            experiment.beginChanges();
            try
                for sequence = sequences
                    temperature = sequence.getProperty(temperatureTerm);
                    if isempty(temperature)
                        disp(['Missing temperature for sequence ' sequence.name ' of ' experiment.name]);
                    else
                        for region = regions
                            trackingVersion = region.getProperty(versionTerm);
                            if isempty(trackingVersion)
                                trackingVersion = '1.0';    %error('Missing tracking version for region %s of %s.', region.name, experiment.name);
                            end
                            
                            tracking = trackings{str2double(region.name), str2double(sequence.name), str2double(temperature)};
                            if isempty(tracking)
                                % Create the new tracking session.
                                sessionName = sprintf('Tracking %s for tube %s, sequence %s @ %s degrees', trackingVersion, region.name, sequence.name, temperature);
                                tracking = experiment.createSession(sessionName, trackingTerm, olympiadLab, region.line);
                                tracking.setProperties(versionTerm, trackingVersion, ...
                                                       regionTerm, region.name, ...
                                                       sequenceTerm, sequence.name, ...
                                                       temperatureTerm, temperature);
                                trackings{str2double(region.name), str2double(sequence.name), str2double(temperature)} = tracking;
                                
                                try
                                    experiment.executeSQL(['update score_array set phase_id=NULL, session_id=' num2str(tracking.id) ' ' ...
                                                           'where phase_id=' num2str(sequence.id) ' and session_id=' num2str(region.id)]);
                                catch ME
                                    error('Could not re-assign score arrays to tracking session: %s', ME.message);
                                end
                            end
                            
                            % Add the relationship between the tracking and region sessions.
                            tracking.createRelationship(region, performedInTerm);
                            
                            analysis = analyses{str2double(region.name), str2double(sequence.name), str2double(temperature)};
                            if ~isempty(analysis)
                                if ~isempty(tracking) && isempty(strfind(analysis.name, ' of tracking '))
                                    % Add " of tracking x.y" to the name of the analysis session.
                                    analysis.update('name', strrep(analysis.name, ' for tube', [' of tracking ' trackingVersion ' for tube']));
                                    
                                    % Add the relationship between the tracking and analysis session.
                                    analysis.createRelationship(tracking, derivedFromTerm);
                                end
                                
                                % Add the relationship between the region and analysis session.
                                analysis.createRelationship(region, performedInTerm);
                            end
                        end
                    end
                end
            catch ME
                % Something went wrong.  Undo all changes to the experiment so it's in a consistent state.
                experiment.undoChanges();
                if ~isempty(waitBarHandle)
                    delete(waitBarHandle);
                end
                rethrow(ME);
            end
            
            % All changes were successful, commit them.
            experiment.endChanges();
        catch ME
            disp('Could not convert experiment.');
            disp(getReport(ME));
        end
    end
    
    % Close the progress dialog if we opened it.
    if ~isempty(waitBarHandle)
        delete(waitBarHandle);
    end
end
