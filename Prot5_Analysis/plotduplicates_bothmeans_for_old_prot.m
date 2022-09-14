function plotduplicates_bothmeans_for_old_prot

clear all

%{
load('/Volumes/flyolympiad/Austin/BoxScreen2015/BoxData.mat');
cd('/Volumes/flyolympiad/Austin/BoxScreen2015/combined_summaries')
nexp = length(BoxData);
controls = {'GMR_SS00205','GMR_SS00200','GMR_SS00194','GMR_SS00179'};
effectors = {'UAS_Shi_ts1_3_0001'};
for i = 1:nexp
    line_i = BoxData(i).line_name;
    if ~ismember(line_i,controls)
        summaryname = [line_i,'_combined_summary.pdf'];
        if ~(exist(summaryname,'file')==2)
           idx = strcmp(line_i,{BoxData.line_name}) & strcmp(effectors,{BoxData.effector});
           if sum(idx) > 1
               experiments = {BoxData(idx).experiment_name};
               prot_527_comparison_summary(BoxData,{experiments{1}},{experiments{2}},'mean_dir_index',1,1,[line_i,'_combined_summary'],{'r','b'});
           end
        end
    end
end
%}

load('/Volumes/flyvisionbox/oldBoxData_goodcontrols_only.mat');
all_lines = unique({BoxData.line_name});
controls = {'JHS_K_85321', 'GMR_SS00194', 'GMR_SS00205'};
good_effectors = {'UAS_Shi_ts1_3_0001','UAS_Shi_ts1_UAS_Kir21'};
savepath = '/Volumes/flyvisionbox/comparison_summaries/repeats/';

for line = 1:length(all_lines)
    
    if ~ismember(all_lines(line),controls)
        data_by_line = BoxData(strcmp({BoxData.line_name},all_lines(line)));
        effectors_for_this_line = unique({data_by_line.effector});
        protocols_for_this_line = unique({data_by_line.protocol});
    
        for effector = 1:length(effectors_for_this_line)
        if ismember(effectors_for_this_line(effector),good_effectors)
        
        
        
        for prot = 1:length(protocols_for_this_line)
            
            data = data_by_line(strcmp({data_by_line.effector},...
                effectors_for_this_line(effector)) & ...
                strcmp({data_by_line.protocol}, ...
                protocols_for_this_line(prot)));
            
            if length(data) > 1
            if ~exist([savepath,data(1).line_name,'_',data(1).effector,'_combined_summaries.pdf'],'file')
                if strcmp(protocols_for_this_line(prot),'5.27') && ~isempty(data)
                prot_527_comparison_summary_bothmeans(BoxData,'split_control', {data.experiment_name},...
                    'mean_dir_index',3,1,...
                    fullfile([data(1).line_name,'_',data(1).effector,'_combined_summaries']),...
                    savepath,{'k','r','g','m','c'});
            
                end
            if strcmp(protocols_for_this_line(prot),'5.28') && ~isempty(data)
                prot_528_comparison_summary(BoxData,{data.experiment_name},...
                   'split_control','mean_dir_index',3,1,...
                    [data(1).line_name,'_',data(1).effector,'_combined_summaries'],...
                    savepath,{'k','r','g','m','c'});
            
            end
            if strcmp(protocols_for_this_line(prot),'5.31') && ~isempty(data)
                prot_531_comparison_summary(BoxData,{data.experiment_name},...
                    'split_control','mean_dir_index',3,1,...
                    [data(1).line_name,'_',data(1).effector,'_combined_summaries'],...
                    savepath,{'k','r','g','m','c'});
            
            end
            if strcmp(protocols_for_this_line(prot),'5.34') && ~isempty(data)
                prot_534_comparison_summary_bothmeans(BoxData,'split_control', {data.experiment_name},...
                   'mean_dir_index',3,1,...
                    [data(1).line_name,'_',data(1).effector,'_combined_summaries'],...
                    savepath,{'k','r','g','m','c'});
            
            end

            end
        end 
        end
        end
        end
    end
end