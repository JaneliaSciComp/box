function merge_analysis_output(outDir, verbose)
    % Contatenate the individual analysis_info and success files.
    
    %% Check the arguments
    if isdeployed
        if nargin == 0
            disp('Usage: merge_analysis_output output_dir_path [--verbose]');
            return
        end
        
        if nargin == 1
            verbose = false;
        else
            verbose = strcmp(verbose, '--verbose');
        end
    else
        if nargin < 2
            verbose = false;
        end
    end
    
    %% Merge the analysis_info files.
    if verbose
        display('Merging analysis_info files')
    end
    cd(outDir)
    Olympiad_folder_check;
    
    %% merge the trak_results files
    if verbose
        display(['Merging trak_results files'])
    end
    Temp_str{1} = '01';
    Temp_str{2} = '02';
    Temp_prot_str{1} = '01_3.0_24';
    Temp_prot_str{2} = '02_3.0_34';
    tr_ind = 1;
    for temp_ind = 1:2 %for two temps
        for seq_ind = 1:5 %num_seqs 
            for tube_ind = 1:6 %num_tubes
                % create empty Trak_success entry
                All_Trak_success(tr_ind).success = 0; %#ok
                All_Trak_success(tr_ind).error = [];  %#ok

                tr_name = [Temp_str{temp_ind} '_3.0_seq' num2str(seq_ind) '_tube' num2str(tube_ind)];
                %if verbose
                %    display(['Merging ' tr_name])
                %end
                tr_path = [outDir filesep 'Output' filesep Temp_prot_str{temp_ind} filesep tr_name filesep 'trak_success.mat'];
                if exist(tr_path, 'file') == 2       
                    load(tr_path);
                    if isfield(Trak_success, 'success') %#ok
                        All_Trak_success(tr_ind) = Trak_success; %#ok
                    end
                    clear Trak_success
                end
                tr_ind = tr_ind + 1;
            end
        end
    end
    Trak_success = All_Trak_success; %#ok
    now_str = datestr(now, 30);
    tr_save_path = [outDir filesep 'Output' filesep 'success_' now_str '.mat'];
    try
        save(tr_save_path, 'Trak_success');
    catch ME
       warning('Can''t write Trak_success to %s (%s)', tr_save_path, ME.message);
    end        
