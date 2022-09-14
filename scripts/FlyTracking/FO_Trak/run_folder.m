function Trak_success = run_folder(workDir, outDir)

paramFile = 'C:\MatlabRoot\testing_cmdline_flytrack\params_olympiad.txt';
retrack = 0; %keep data if there...

% track all of the sbfmf files in one folder 
% point to a folder with one temp, containing 30 movies

dir_struct = rdir([workDir '\**\*.sbfmf']);
[sorted_names,sorted_index] = sortrows({dir_struct.name}'); % should find 30, but don't check this now
tic    
for k = 1:length(sorted_names)
    inputFile = sorted_names{k} % use curly braces to index into cell array
    [path, base] = filenamesplit(sorted_names{k});
    [path2, base2] = filenamesplit(path); % gets to the sbfmf folder level
    [path3, base3] = filenamesplit(path2); % gets to the temp level, either 01_3.0_24 or 02_3.0_34
    if ~(strcmp(base3, '01_3.0_24') || strcmp(base3, '02_3.0_34'))
        error('File paths don''t look right! Look at directory structure');
    end
    outputDir =  [outDir filesep 'Output' filesep base3 filesep remove_white_space_extension(base)]
    
    %%%% prepare output dir
    An_exists = 0;
    if( ~exist(outputDir) )
        curr_dir = pwd;
        mkdir(outDir, ['Output' filesep base3 filesep remove_white_space_extension(base)]);
    else
        % if the directory is there, has the movie been tracked?  % does analysis_info exist?        
        an_path = [outputDir filesep 'analysis_info.mat'];
        An_exists = exist(an_path)
        if (An_exists == 2) && (retrack == 0)       
            Trak_success(k).success = 2; % 2 means tracked already 
            Trak_success(k).error = []; 
        end
    end
   if An_exists == 0
        [Trak_success(k)] = olympiadTrak(paramFile, inputFile, outputDir);
   end
end

cd(outDir)
now_str = datestr(now, 30);
Status_obj_name = ['success_' now_str '.mat'];
save(Status_obj_name, 'Trak_success');
Olympiad_folder_check; % badly named...this function concatenates the analysis_info's into an analysis_info_tube structure
toc
