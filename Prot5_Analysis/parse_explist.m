function exp_struct =  parse_explist(explist, plot_mode,protocol)

nexp = length(explist);

colors = {'k','r','b','g','c'};

for i = 1:nexp
    
    % save experiment date and time
    
    % check for file separator at end of path for
    % regex matching consistency
    
    if explist{i}(end) ~= '/'
        explist{i} = [explist{i}, '/'];
    end
    
    parts = regexp(explist(i),'/','split');
    exp_struct(i).file = parts{1,1}{1,end-1};
    exp_struct(i).exp_datetime = exp_struct(i).file(end-14:end);
    exp_struct(i).protocol = protocol;
    
    % split and save experiment path
    path_pattern = '^.*/';
    match = regexp(explist(i),path_pattern, 'match');
    exp_struct(i).path = match{1,1}{1,1};
    
    cd(fullfile(exp_struct(i).path))
    cd(['01_',protocol,'_34'])
    
    cur_dir = dir('*.m');
    
    % load 'sequence details' for grabbing metadata
    for j = 1:length(cur_dir)
        if (strcmp(cur_dir(j).name(1:16), 'sequence_details'))
            try 
                fid = fopen([cur_dir(j).name(1:end-2) '.m']);
                script = fread(fid, '*char')';
                fclose(fid);
                eval(script);
            catch exception
                fprintf(['Error: sequence_details file ' cur_dir(j).name ' does not load or is missing crucial info.'])            
                throw(exception)
            end
        end
    end
    
   
    
    % load analysis results file
    cd('../Output_1.1_1.7')
    load(['01_',protocol,'_34_analysis_results.mat'])
    
    exp_struct(i).box = BoxName;
    exp_struct(i).tubes = zeros(1,6);
    exp_struct(i).genotype = cell(1,6);
    for tube = 1:6
        % check to see if tubes are empty
        if analysis_results(tube).seq6.max_tracked_num > 10
            exp_struct(i).tubes(tube) = tube;
             % save genotype
            exp_struct(i).genotype{tube} = exp_detail.tube_info(tube).Genotype;
        end
        
    end
    
    %remove empty tubes
    exp_struct(i).tubes(exp_struct(i).tubes==0) = [];
    %exp_struct(i).tubes = [2];
    
    if plot_mode == 3 
        exp_struct(i).color = colors{i};
    end
end