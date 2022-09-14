function result = analyze_experiment(experiment_dir_path,output_base_dir,varargin)
    result = 0;
    
    %% Check the arguments
    assert(exist(experiment_dir_path,'dir')==7,'Experiment directory does not exist.');
    assert(ischar(output_base_dir),'Invalid output_base_dir.');
    
    flagIndex = find(strcmp(varargin, '--no-plots'));
    if isempty(flagIndex)
        save_plots = true;
    else
        save_plots = false;
        varargin(flagIndex) = [];
    end
    flagIndex = find(strcmp(varargin, '--reanalyze'));
    if isempty(flagIndex)
        skip_analyzed = true;
    else
        skip_analyzed = false;
        varargin(flagIndex) = [];
    end
    if ~isempty(varargin)
        error('analyze_experiment:argumentCheck','Invalid usage.\n\nUsage: analyze_experiment experiment_dir_path output_base_dir [--no-plots] [--reanalyze] ');
    end
    
    %% Do the analysis
    box_analysis(experiment_dir_path, output_base_dir, save_plots, skip_analyzed);
end
