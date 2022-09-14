function phototaxis_comparison(data_for_control_experiments, ...
                               data_for_test_experiments, ...
                               num_conditions, ...
                               seq, ...
                               analysis_feature, ...
                               subplot_count, ...
                               plot_mode, ...
                               colors)
    
    % plot_mode: 1 - mean + standard deviation
    %            2 - individual experiments
    %            3 - individual experiments + mean of tubes for each experiment
    
    test_experiment_count = length(data_for_test_experiments) ;    
    
    analysis_feature_control = gather_analysis_feature(data_for_control_experiments, num_conditions, seq, analysis_feature) ; 

    subplot(2,4,subplot_count)

    if plot_mode == 1 || plot_mode == 3 ,
        analysis_feature_control = analysis_feature_control(isfinite(analysis_feature_control(:, 1)), :);
        errorbar(1:2, mean(analysis_feature_control(:,1:2),1), std(analysis_feature_control(:,1:2)), colors{1}) ;
        hold on
        errorbar(3:4, mean(analysis_feature_control(:,3:4),1), std(analysis_feature_control(:,3:4)), colors{1}) ;
    end

    if plot_mode == 2,
        for i = 1:size(analysis_feature_control,1) ,
            colorOrder = get(gca, 'ColorOrder');
            plot(1:2, mean(analysis_feature_control(i,1:2),1), 'Color',colorOrder(i,:)) ;
            hold on
            plot(3:4, mean(analysis_feature_control(i,3:4),1), 'Color',colorOrder(i,:)) ;
        end
        analysis_feature_control = analysis_feature_control(isfinite(analysis_feature_control(:, 1)), :) ;
        plot(1:2, mean(analysis_feature_control(:,1:2),1), colors{1}, 'LineWidth',2) ;
        hold on
        plot(3:4, mean(analysis_feature_control(:,3:4),1), colors{1}, 'LineWidth',2) ;
    end

    axis([0.75 4+0.25 -0.1 8]);
    X_label_short = {'GL', 'GH', 'UL', 'UH'};
    set(gca, ...
        'Xtick', 1:num_conditions, ...
        'Ytick', 0:8, ...
        'Xticklabel', X_label_short, ...
        'FontSize', 14) ;

    title('Phototaxis') ;
    ylabel('Maximum Cumulative Direction Index') ;
    box off

    if plot_mode == 1 || plot_mode == 2,
        if test_experiment_count > 0,
            analysis_feature_test = gather_analysis_feature(data_for_test_experiments, num_conditions, seq, analysis_feature) ; 
%             for j = 1:test_experiment_count,
%                 if j == 1,
%                     analysis_feature_test = nan(length(data_for_test_experiments(j).tubes), num_conditions) ;
%                 else
%                     analysis_feature_test = [analysis_feature_test; nan(length(data_for_control_experiments(i).tubes), num_conditions)];  %#ok<AGROW>
%                 end
%                 for tube = data_for_test_experiments(j).tubes,
%                     if j == 1,
%                         analysis_feature_test(tube,:) = data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)';
%                     else
%                         analysis_feature_test((j-1)*length(data_for_test_experiments(j-1).tubes)+tube,:) ...
%                         = data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)';
%                     end
%                 end
%             end
            if plot_mode == 1,
                analysis_feature_test = analysis_feature_test(isfinite(analysis_feature_test(:, 1)), :);
            end
            errorbar(1:2, mean(analysis_feature_test(:,1:2),1), std(analysis_feature_test(:,1:2)), colors{2}) ;
            hold on
            errorbar(3:4, mean(analysis_feature_test(:,3:4),1), std(analysis_feature_test(:,3:4)), colors{2}) ;
            box off
        end
    end

    if plot_mode == 3,
       for j = 1:test_experiment_count ,
            analysis_feature_test = gather_analysis_feature(data_for_test_experiments(j), num_conditions, seq, analysis_feature) ; 
%             analysis_feature_test = nan(length(data_for_test_experiments(j).tubes), num_conditions) ;
%             for tube = data_for_test_experiments(j).tubes ,
%                 analysis_feature_test(tube,:) = data_for_test_experiments(j).analysis_results(tube).(seq).(analysis_feature)(:)' ;
%             end
            colorOrder = get(gca, 'ColorOrder');
            errorbar((1:2)+j*0.1,nanmean(analysis_feature_test(:,1:2),1),std(analysis_feature_test(:,1:2)), 'Color',colorOrder(j,:)) ;
            hold on
            errorbar((3:4)+j*0.1,nanmean(analysis_feature_test(:,3:4),1),std(analysis_feature_test(:,3:4)), 'Color',colorOrder(j,:)) ;
            box off
        end 
    end
end
