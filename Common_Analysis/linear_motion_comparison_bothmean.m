% experiments: list of experiments to analyze
% plot_mode: 1 - mean + standard deviation
%            2 - individual experiments
%            3 - individual experiments + mean of tubes for each experiment


% loop through experiments in group
for i = 1:nexp_group1
    % initialize array
    if i == 1
        analysis_feature_grp1 = nan(length(exp_group1_data(i).tubes), ...
            half_num_conditions);
    else
        analysis_feature_grp1 = [analysis_feature_grp1; nan(length(exp_group1_data(i).tubes), ...
            half_num_conditions)];
    end
    
    % pull out data from tubes with flies
    for tube = exp_group1_data(i).tubes
        if i == 1
            analysis_feature_grp1(tube,:) = exp_group1_data(i).analysis_results(tube).(seq).(analysis_feature)(:)';
        else
            analysis_feature_grp1((i-1)*length(exp_group1_data(i-1).tubes)+tube,:) ...
            =  exp_group1_data(i).analysis_results(tube).(seq).(analysis_feature)(:)';
        end
    end
    
end

subplot(2,4,subplot_count)
    
    % remove tubes without flies and then plot
    analysis_feature_grp1 = analysis_feature_grp1(isfinite(analysis_feature_grp1(:, 1)), :);
    errorbar([1:half_num_conditions],mean(analysis_feature_grp1,1),std(analysis_feature_grp1), colors{1})
    hold on

set(gca, 'Xtick', (1:half_num_conditions))
axis([0.75 half_num_conditions+0.25 n_y_lim y_lim]);
xlabel(x_variable,'FontSize',14)
if subplot_count == 1,
    ylabel(y_variable,'FontSize',14)
end

title(sequence_title, 'FontSize',14)
set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions), ...
        'FontSize',14)
plot([0:half_num_conditions+1],zeros(1,half_num_conditions+2),'k')
box off

    for j = 1:nexp_group2
    % initialize array
    if j == 1
        analysis_feature_grp2 = nan(length(exp_group2_data(j).tubes), ...
            half_num_conditions);
    else
        analysis_feature_grp2 = [analysis_feature_grp2; nan(length(exp_group2_data(j).tubes), ...
            half_num_conditions)];
    end
    
    % pull out data from tubes with flies
    for tube = exp_group2_data(j).tubes
        if j == 1
            analysis_feature_grp2(tube,:) = exp_group2_data(j).analysis_results(tube).(seq).(analysis_feature)(:)';
        else
            analysis_feature_grp2((j-1)*length(exp_group2_data(j-1).tubes)+tube,:) ...
            =  exp_group2_data(j).analysis_results(tube).(seq).(analysis_feature)(:)';
        end
    end
    
    end
    
    colorOrder = get(gca, 'ColorOrder');
    analysis_feature_grp2 = analysis_feature_grp2(isfinite(analysis_feature_grp2(:, 1)), :);
    errorbar([1:half_num_conditions],mean(analysis_feature_grp2,1),std(analysis_feature_grp2), 'Color',colorOrder(j,:))
    hold on
    
%    for j = 1:nexp_group2,                                     %  <- chg 2 to 1   (whole for loop)
%           analysis_feature_grp2 = nan(length(exp_group2_data(j).tubes), ...
%                 half_num_conditions);    
%         for tube = exp_group2_data(j).tubes,
%           
%             analysis_feature_grp2(tube,:) = exp_group2_data(j).analysis_results(tube).(seq).(analysis_feature)(:)';
%         end
%         
%         colorOrder = get(gca, 'ColorOrder');
%         errorbar([1:half_num_conditions],nanmean(analysis_feature_grp2,1),std(analysis_feature_grp2),'Color',colorOrder(j,:))
%         hold on
%     end 