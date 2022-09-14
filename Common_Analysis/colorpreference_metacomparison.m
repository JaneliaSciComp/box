load('/Volumes/flyolympiad/Austin/BoxScreen2015/BoxData.mat')

uv_all_conditions = [0 3 6 10 15 20 30 50 75 100 200];
gr_all_conditions = [0 5 7 10 15 25 40 50 55 75 100 200];

x_uv = 1:length(uv_all_conditions);
x_gr = 1:length(gr_all_conditions);

uv527_conditions = [0 3 6 10 15 20 30 50 75 100 200]; 
gr527_conditions = [0 5 7 10 15 25 40 55 75 100 200];
uv528_conditions = [0 3 6 10 15 20 30 50 75 100 200];
gr528_conditions = [0 5 7 10 15 25 40 55 75 100 200];
uv531_conditions = [0 3 10 20 30 50 100 200];
gr531_conditions = [0 5 10 15 25 50 100 200];
uv534_conditions = [0 3 10 20 30 50 100 200];
gr534_conditions = [0 5 10 15 25 50 100 200];

[~,idxs] = intersect(uv_all_conditions,uv527_conditions);
uv527_x = x_uv(idxs);
[~,idxs] = intersect(gr_all_conditions,gr527_conditions);
gr527_x = x_gr(idxs);

[~,idxs] = intersect(uv_all_conditions,uv528_conditions);
uv528_x = x_uv(idxs);
[~,idxs] = intersect(gr_all_conditions,gr528_conditions);
gr528_x = x_gr(idxs);

[~,idxs] = intersect(uv_all_conditions,uv531_conditions);
uv531_x = x_uv(idxs);
[~,idxs] = intersect(gr_all_conditions,gr531_conditions);
gr531_x = x_gr(idxs);

[~,idxs] = intersect(uv_all_conditions,uv534_conditions);
uv534_x = x_uv(idxs);
[~,idxs] = intersect(gr_all_conditions,gr534_conditions);
gr534_x = x_gr(idxs);

cntrl_idx = strcmp({BoxData.type}, 'control');
controlData = BoxData(cntrl_idx);

for exp = 1:length(controlData)

    uv527_tubecount=1;
    gr527_tubecount=1;
    uv528_tubecount=1;
    gr528_tubecount=1;
    uv531_tubecount=1;
    gr531_tubecount=1;
    uv534_tubecount=1;
    gr534_tubecount=1;
    
    if strcmp(controlData(exp).protocol,'5.27')
        
        for tube = controlData(exp).tubes
            uv527_AR(uv527_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq7.cum_dir_index_peak;
            uv527_tubecount=uv527_tubecount+1;
            gr527_AR(gr527_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq8.cum_dir_index_peak;
            gr527_tubecount=gr527_tubecount+1;
        end
    end
    
    if strcmp(controlData(exp).protocol,'5.28')
        
        for tube = controlData(exp).tubes
            uv528_AR(uv528_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq7.cum_dir_index_peak;
            uv528_tubecount=uv528_tubecount+1;
            gr528_AR(gr528_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq8.cum_dir_index_peak;
            gr528_tubecount=gr528_tubecount+1;
        end
    end
    
    if strcmp(controlData(exp).protocol,'5.31')
        
        for tube = controlData(exp).tubes
            uv531_AR(uv531_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq3.cum_dir_index_peak;
            uv531_tubecount=uv531_tubecount+1;
            gr531_AR(gr531_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq4.cum_dir_index_peak;
            gr531_tubecount=gr531_tubecount+1;
        end
    end
    
    if strcmp(controlData(exp).protocol,'5.34')
        
        for tube = controlData(exp).tubes
            uv534_AR(uv534_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq3.cum_dir_index_peak;
            uv534_tubecount=uv534_tubecount+1;
            gr534_AR(gr534_tubecount,:) = ...
                controlData(exp).analysis_results(tube).seq4.cum_dir_index_peak;
            gr534_tubecount=gr534_tubecount+1;
        end
    end

end

figure(1)
set(1, 'Position', [30 55 1500 1500]);
errorbar(uv527_x-0.2,-mean(uv527_AR,1),std(uv527_AR,1), 'r')
hold on
plot(uv527_x-0.2,-mean(uv527_AR,1), 's-','LineWidth',2,'MarkerSize',5,'Color','r','MarkerEdgeColor','r','MarkerFaceColor','r')
errorbar(uv528_x-0.1,-mean(uv528_AR,1),std(uv528_AR,1), 'b')
plot(uv528_x-0.1,-mean(uv528_AR,1), 's-','LineWidth',2,'MarkerSize',5,'Color','b','MarkerEdgeColor','b','MarkerFaceColor','b')
errorbar(uv531_x,mean(uv531_AR,1),std(uv531_AR,1), 'Color',[0 0.3922 0])
plot(uv531_x,mean(uv531_AR,1),'s-','LineWidth',2,'MarkerSize',5,...
    'MarkerEdgeColor',[0 0.3922 0],'MarkerFaceColor',[0 0.3922 0],'Color',[0 0.3922 0])
errorbar(uv534_x+0.1,mean(uv534_AR,1),std(uv534_AR,1), 'Color',[104 34 139]/255)
plot(uv534_x+0.1,mean(uv534_AR,1),'s-','LineWidth',2,'MarkerSize',5,...
    'MarkerEdgeColor',[104 34 139]/255,'MarkerFaceColor',[104 34 139]/255,'Color',[104 34 139]/255)
box off
set(gca, 'Xtick', (1:length(uv_all_conditions)))
set(gca, 'Xticklabel', uv_all_conditions, ...
        'FontSize',14)
xlabel('Green Intensity')
title('UV Constant - protocol comparison')
plot(0:12,zeros(13),'k')
axis([0 13 -4 4])

h1 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor','r','MarkerFaceColor','r',...
    'Color','r');
h2 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor','b','MarkerFaceColor','b',...
    'Color','b');
h3 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor',[0 0.3922 0],'MarkerFaceColor',[0 0.3922 0],...
    'Color',[0 0.3922 0]);
h4 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor',[104 34 139]/255,'MarkerFaceColor',[104 34 139]/255,...
    'Color',[104 34 139]/255);
legend([h1,h2,h3,h4],'Protocol5.27','Protocol5.28','Protocol5.31','Protocol5.34')
save2pdf('~/Documents/Reiser_Lab/ColorPreference_TroubleShooting/UV_protocol_comparison.pdf')

figure(2)
set(2, 'Position', [30 55 1500 1500]);
errorbar(gr527_x-0.2,mean(gr527_AR,1),std(gr527_AR,1), 'r')
hold on
plot(gr527_x-0.2,mean(gr527_AR,1), 's-','LineWidth',2,'MarkerSize',5,'Color','r','MarkerEdgeColor','r','MarkerFaceColor','r')
errorbar(gr528_x-0.1,mean(gr528_AR,1),std(gr528_AR,1), 'b')
plot(gr528_x-0.1,mean(gr528_AR,1), 's-','LineWidth',2,'MarkerSize',5,'Color','b','MarkerEdgeColor','b','MarkerFaceColor','b')
errorbar(gr531_x,mean(gr531_AR,1),std(gr531_AR,1), 'Color',[0 0.3922 0])
plot(gr531_x,mean(gr531_AR,1),'s-','LineWidth',2,'MarkerSize',5,...
    'MarkerEdgeColor',[0 0.3922 0],'MarkerFaceColor',[0 0.3922 0],'Color',[0 0.3922 0])
errorbar(gr534_x+0.1,mean(gr534_AR,1),std(gr534_AR,1), 'Color',[104 34 139]/255)
plot(gr534_x+0.1,mean(gr534_AR,1),'s-','LineWidth',2,'MarkerSize',5,...
    'MarkerEdgeColor',[104 34 139]/255,'MarkerFaceColor',[104 34 139]/255,'Color',[104 34 139]/255)
box off
set(gca, 'Xtick', (1:length(gr_all_conditions)))
set(gca, 'Xticklabel', gr_all_conditions, ...
        'FontSize',14)
xlabel('UV Intensity')
title('Green Constant - protocol comparison')
plot(0:12,zeros(13),'k')
axis([0 13 -4 4])

h1 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor','r','MarkerFaceColor','r',...
    'Color','r');
h2 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor','b','MarkerFaceColor','b',...
    'Color','b');
h3 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor',[0 0.3922 0],'MarkerFaceColor',[0 0.3922 0],...
    'Color',[0 0.3922 0]);
h4 = plot(0,0,'s-','MarkerSize',5,'MarkerEdgeColor',[104 34 139]/255,'MarkerFaceColor',[104 34 139]/255,...
    'Color',[104 34 139]/255);
legend([h1,h2,h3,h4],'Protocol5.27','Protocol5.28','Protocol5.31','Protocol5.34')
save2pdf('~/Documents/Reiser_Lab/ColorPreference_TroubleShooting/GR_protocol_comparison.pdf')
