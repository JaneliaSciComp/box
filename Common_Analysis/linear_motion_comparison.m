function linear_motion_comparison(...
    data_for_control_experiments, ...
    data_for_test_experiments, ...
    seq, ...
    analysis_feature, ...
    subplot_count, ...
    plot_mode, ...
    colors, ...
    half_num_conditions, ...
    x_variable, ...
    sequence_title, ...
    plot_conditions, ...
    n_y_lim, ...
    y_lim)

    % experiments: list of experiments to analyze
    % plot_mode: 1 - mean + standard deviation
    %            2 - individual experiments
    %            3 - individual experiments + mean of tubes for each experiment

%     control_experiment_count = length(data_for_control_experiments) ;
    test_experiment_count = length(data_for_test_experiments) ;    

%     % loop through experiments in control group
%     for i = 1:control_experiment_count
%         % initialize array
%         if i == 1 ,
%             analysis_feature_control = nan(length(data_for_control_experiments(i).tubes), half_num_conditions) ;
%         else
%             analysis_feature_control = [analysis_feature_control; nan(length(data_for_control_experiments(i).tubes), half_num_conditions)] ;  %#ok<AGROW>
%         end
%         % pull out data from tubes with flies
%         for tube = data_for_control_experiments(i).tubes
%             if i == 1 ,
%                 analysis_feature_control(tube,:) = data_for_control_experiments(i).analysis_results(tube).(seq).(analysis_feature)(:)';
%             else
%                 analysis_feature_control((i-1)*length(data_for_control_experiments(i-1).tubes)+tube,:) = ...
%                     data_for_control_experiments(i).analysis_results(tube).(seq).(analysis_feature)(:)';
%             end
%         end
%     end
    analysis_feature_control = gather_analysis_feature(data_for_control_experiments, half_num_conditions, seq, analysis_feature) ;
    
    subplot(2,4,subplot_count)

    if plot_mode == 1 || plot_mode==3
        % remove tubes without flies and then plot
        analysis_feature_control = analysis_feature_control(isfinite(analysis_feature_control(:, 1)), :) ;
        errorbar(1:half_num_conditions, mean(analysis_feature_control,1), std(analysis_feature_control), colors{1}) ;
        hold on
    end

    if plot_mode == 2
        analysis_feature_control = analysis_feature_control(isfinite(analysis_feature_control(:, 1)), :) ;
        for i = 1:size(analysis_feature_control,1),
            plot(1:half_num_conditions, analysis_feature_control(i,:)) ;
            hold all
        end
        if plot_mode == 2 ,
            hold on
            plot(1:half_num_conditions, mean(analysis_feature_control,1), colors{1}, 'LineWidth', 2) ;
        end
    end

    set(gca, ...
        'Xtick', (1:half_num_conditions), ...
        'FontSize', 14) ;
    axis([0.75 half_num_conditions+0.25 n_y_lim y_lim]);
    xlabel(x_variable) ;
    if subplot_count == 1,
        ylabel(y_variable) ;
    end

    title(sequence_title) ;
    set(gca, 'Xticklabel', plot_conditions(1:half_num_conditions)) ;
    plot(0:half_num_conditions+1, zeros(1,half_num_conditions+2), 'k') ;
    box off

    if plot_mode == 1 || plot_mode == 2 ,
        if test_experiment_count > 0 ,
%             for j = 1:test_experiment_count
%                 if j == 1
%                     analysis_feature_test = nan(length(data_for_control_experiments(i).tubes), half_num_conditions) ;
%                 else
%                     analysis_feature_test = [analysis_feature_test; nan(length(data_for_control_experiments(i).tubes), half_num_conditions)] ;  %#ok<AGROW>
%                 end
%                 for tube = data_for_test_experiments(j).tubes ,
%                     if j == 1
%                         analysis_feature_test(tube,:) = data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)';
%                     else
%                         analysis_feature_test((j-1)*length(data_for_test_experiments(j-1).tubes)+tube,:) = ...
%                             data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)';
%                     end
%                 end
%             end 
            analysis_feature_test = gather_analysis_feature(data_for_test_experiments, half_num_conditions, seq, analysis_feature) ; 
            if plot_mode == 1 ,
                analysis_feature_test = analysis_feature_test(isfinite(analysis_feature_test(:, 1)), :);
            end
            errorbar(1:half_num_conditions, mean(analysis_feature_test,1),std(analysis_feature_test), colors{2}) ;
            hold on
            box off
        end  % if test_experiment_count > 0 ,
    end

    if plot_mode == 3 ,
        for j = 1:test_experiment_count,                                     %  <- chg 2 to 1   (whole for loop)
%             analysis_feature_test = nan(length(data_for_test_experiments(j).tubes), half_num_conditions);
%             for tube = data_for_test_experiments(j).tubes ,
%                 analysis_feature_test(tube,:) = data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)' ;
%             end
            analysis_feature_test = gather_analysis_feature(data_for_test_experiments(j), half_num_conditions, seq, analysis_feature) ;
            colorOrder = get(gca, 'ColorOrder') ;
            errorbar(1:half_num_conditions, nanmean(analysis_feature_test,1), std(analysis_feature_test), 'Color',colorOrder(j,:)) ;
            hold on
        end
    end
end
