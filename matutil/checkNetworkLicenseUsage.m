function [licenses] = checkNetworkLicenseUsage(arg1, ~)
    % checkNetworkLicenseUsage()
    % Use this function to check which network licenses are currently in use.
    % 
    % To get immediate status:
    % 
    % >> checkNetworkLicenseUsage()
    %
    % To automatically check every hour:
    %
    % >> checkNetworkLicenseUsage('continuous')
    %
    % To turn off automatic checking:
    %
    % >> checkNetworkLicenseUsage('stop')
    %
    % To return the list of licenses:
    % 
    % >> l = checkNetworkLicenseUsage()
    
    
    if nargout > 0
        licenses = [];
    end
    
    if verLessThan('matlab', '7.14')
        disp('Cannot check for network license usage on MATLAB 2011B or earlier.');
        return
    end
    
    if nargin == 1
        % Check if the timer is already running.
        licenseCheckTimer = timerfind('Tag', 'networkLicenseCheckTimer');
        
        if strcmp(arg1, 'continuous')
            if isempty(licenseCheckTimer)
                % Run the timer once an hour.
                disp('Network license usage will be checked every hour.');
                licenseCheckTimer = timer('TimerFcn', @checkNetworkLicenseUsage, ...
                                          'ExecutionMode', 'fixedRate', ...
                                          'Period', 60 * 60, ...
                                          'StartDelay', 60 * 60, ...
                                          'Tag', 'networkLicenseCheckTimer');
                start(licenseCheckTimer);
            else
                disp('Network license usage is already being checked every hour.');
            end
        elseif strcmp(arg1, 'stop')
            if isempty(licenseCheckTimer)
                disp('Network license usage was not being checked.')
            else
                disp('Network license usage will no longer be checked.')
                stop(licenseCheckTimer);
                delete(licenseCheckTimer);
            end
        end
    else
        janeliaLicenses = {'520837', '342824'};
        
        toolboxes = license('inuse');
        
        % The toolbox name reported by license() is not the same as what you have to pass to ver().
        featureMap = containers.Map();
        featureMap('bioinformatics_toolbox') = 'bioinfo';
        featureMap('control_toolbox') = 'control';
        featureMap('curve_fitting_toolbox') = 'curvefit';
        featureMap('database_toolbox') = 'database';
        featureMap('distrib_computing_toolbox') = 'distcomp';
        featureMap('image_acquisition_toolbox') = 'imaq';
        featureMap('image_toolbox') = 'images';
        featureMap('instr_control_toolbox') = 'instrument';
        featureMap('matlab') = 'matlab';
        featureMap('matlab compiler') = 'compiler';
        featureMap('neural_network_toolbox') = 'nnet';
        featureMap('optimization_toolbox') = 'optim';
        featureMap('signal_processing_toolbox') = 'signal';
        featureMap('signal_toolbox') = 'signal';
        featureMap('simulink') = 'simulink';
        featureMap('statistics_toolbox') = 'stats';
        featureMap('symbolic_math_toolbox') = 'symbolic';
        featureMap('symbolic_toolbox') = 'symbolic';
        featureMap('wavelet_toolbox') = 'wavelet';
        % TODO: Find out mapping for Extended Symbolic Math Toolbox, Filter Design Toolbox, 
        %       Real-Time Windows Target, Real-Time Workshop, Spline Toolbox, xPC Target
        
        networkLicenses = [];
        unknownLicenses = {};
        try
            for i = 1:length(toolboxes)
                if featureMap.isKey(toolboxes(i).feature)
                    featureName = featureMap(toolboxes(i).feature);
                else
                    featureName = toolboxes(i).feature;
                end
                versionInfo = ver(featureName);
                if verLessThan('matlab', '8.0')
                    % In MATLAB 2012a the license numbers are returned from ver.
                    licenseNumbers = versionInfo.Licenses;
                elseif verLessThan('matlab', '8.2')
                    % MATLAB 2012b no longer returns the license numbers from ver.
                    % However, if you look at the source for ver the data is still available, just not returned.
                    % Make the direct call to get the license numbers as ver used to.
                    licenseNumbers = internal.matlab.licensing.getLicInfo(toolboxes(i).feature);
                    licenseNumbers = licenseNumbers.license_number;
                else
                    % MATLAB 2013b changed the API yet again.
                    licenseNumbers = matlab.internal.licensing.getLicInfo(toolboxes(i).feature);
                    licenseNumbers = licenseNumbers.license_number;
                end
                if isempty(versionInfo)
                    unknownLicenses{end + 1} = featureName; %#ok<AGROW>
                elseif length(licenseNumbers) == 1 && ismember(licenseNumbers{1}, janeliaLicenses)
                    networkLicenses(end + 1).fullName = versionInfo.Name; %#ok<AGROW>
                    networkLicenses(end).versionInfo = versionInfo;
                    networkLicenses(end).verName = featureName;
                    networkLicenses(end).licenses = licenseNumbers;
                    networkLicenses(end).licenseName = toolboxes(i).feature;
                end
            end
        catch ME
            disp(['An error occurred determining license usage: ' ME.message char(10) char(10) ...
                  'Check the wiki to make sure you are using the latest version of this checker:' char(10) ...
                  '    <http://wiki/wiki/display/ScientificComputing/MATLAB+Network+License+Usage+Checker>' char(10)]);
            rethrow(ME);
        end
        
        if nargout == 0
            if isempty(networkLicenses) && isempty(unknownLicenses)
                if nargin == 0
                    disp('You are not using any network licenses at this time.');
                end
            else
                disp('==============================================================================================');
                if ~isempty(networkLicenses)
                    disp('You have the following network licenses checked out:')
                    fprintf(' * %s\n', networkLicenses.fullName);
                    disp('If you are no longer using these licenses then please quit MATLAB so that others may use them.');
                end
                if ~isempty(unknownLicenses)
                    if ~isempty(networkLicenses)
                        fprintf('\n');
                    end
                    disp('The network license usage for the following toolboxes could not be determined:')
                    fprintf(' * %s\n', unknownLicenses{:});
                end
                disp('==============================================================================================');
            end
        else
            licenses = networkLicenses;
        end
    end
end
