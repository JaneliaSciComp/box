% findslopes

load('/Volumes/flyolympiad/Austin/BoxScreen2015/BoxData.mat');
controls = BoxData(strcmp({BoxData.type},'control'));

%uv constant

%prot527
x527_uv = [0 3 6 10 15 20 30 50 75 100 200];
%prot531
x531_uv = [0 3 10 20 30 50 100 200];
x534_uv = [0 3 10 20 30 50 100 200];

%green constant
%for prot5.27
x527_gr = [0 5 7 10 15 25 40 55 75 100 200];
%prot5.31
x531_gr = [0 5 10 15 25 50 100 200];
x534_gr = [0 5 10 15 25 50 100 200];

uvdata_527 = zeros(length(find(strcmp({controls.protocol},'5.27'))),11);
grdata_527 = zeros(length(find(strcmp({controls.protocol},'5.27'))),11);

uvdata_531 = zeros(length(find(strcmp({controls.protocol},'5.31'))),8);
grdata_531 = zeros(length(find(strcmp({controls.protocol},'5.31'))),8);

uvdata_534 = zeros(length(find(strcmp({controls.protocol},'5.34'))),8);
grdata_534 = zeros(length(find(strcmp({controls.protocol},'5.34'))),8);

exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;

for exp = 1:length(controls)

    datetime = str2num(controls(exp).date_time(end-5:end));
    colorcodetime;
    
    if strcmp(controls(exp).protocol,'5.27')
        uvdata_527(exp527_counter,:) = get_tubemean(controls(exp),'seq7');
        grdata_527(exp527_counter,:) = get_tubemean(controls(exp),'seq8');
        exp527_counter = exp527_counter+1;
    end
    
    if strcmp(controls(exp).protocol,'5.31')
         uvdata_531(exp531_counter,:) = get_tubemean(controls(exp),'seq3');
        grdata_531(exp531_counter,:) = get_tubemean(controls(exp),'seq4');
        exp531_counter = exp531_counter+1;
    end
    
    if strcmp(controls(exp).protocol,'5.34')
         uvdata_534(exp534_counter,:) = get_tubemean(controls(exp),'seq3');
        grdata_534(exp534_counter,:) = get_tubemean(controls(exp),'seq4');
        exp534_counter = exp534_counter+1;
    end
    
end

figure(1)
set(1, 'Position', [30 55 1500 1500]);

uv527slopes = linnormal(x527_uv,uvdata_527);
gr527slopes = -linnormal(x527_gr,grdata_527);
uv531slopes = -linnormal(x531_uv,uvdata_531);
gr531slopes = -linnormal(x531_gr,grdata_531);
uv534slopes = -linnormal(x534_uv,uvdata_534);
gr534slopes = -linnormal(x534_gr,grdata_534);


exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;

for exp = 1:length(controls)
    
    if strcmp(controls(exp).protocol,'5.27')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,uv527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,uv527slopes(exp527_counter),50,controls(exp).color)
       
        hold on
        end
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,uv527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,uv527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        
        exp527_counter = exp527_counter + 1;
    end
    
    if strcmp(controls(exp).protocol,'5.31')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,uv531slopes(exp531_counter),50,controls(exp).color,'filled')
       
        hold on
        end
        
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,uv531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,uv531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,uv531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        exp531_counter = exp531_counter + 1;
    end
    
    if strcmp(controls(exp).protocol,'5.34')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,uv534slopes(exp534_counter),50,controls(exp).color,'filled')
       
        hold on
        end
        
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,uv534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,uv534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,uv534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        exp534_counter = exp534_counter + 1;
    end
    
end

axis([0, 4.5 -0.01 0.03])
box off
title('UV Constant Slope - Binned by Hour')
xlabel('Hour')
ylabel('Slope')
save2pdf('/Users/edwardsa/Documents/Reiser_Lab/ColorPreference_TroubleShooting/uv_slope_binnedbyhour_w534.pdf')


figure(2)
set(2, 'Position', [30 55 1500 1500]);

exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;

for exp = 1:length(controls)
    
    if strcmp(controls(exp).protocol,'5.27')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,gr527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,gr527slopes(exp527_counter),50,controls(exp).color)
       
        hold on
        end
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,gr527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,gr527slopes(exp527_counter),50,controls(exp).color)
        hold on
        end
        
        exp527_counter = exp527_counter + 1;
    end
    
    if strcmp(controls(exp).protocol,'5.31')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,gr531slopes(exp531_counter),50,controls(exp).color,'filled')
       
        hold on
        end
        
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,gr531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,gr531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,gr531slopes(exp531_counter),50,controls(exp).color,'filled')
       hold on
        end
        exp531_counter = exp531_counter + 1;
    end
    if strcmp(controls(exp).protocol,'5.34')
        if strcmp(controls(exp).hour,'first')
        
        scatter(1,gr534slopes(exp534_counter),50,controls(exp).color,'filled')
       
        hold on
        end
        
        if strcmp(controls(exp).hour,'second')
        
        scatter(2,gr534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'third')
        
        scatter(3,gr534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        
        if strcmp(controls(exp).hour,'fourth')
        
        scatter(4,gr534slopes(exp534_counter),50,controls(exp).color,'filled')
       hold on
        end
        exp534_counter = exp534_counter + 1;
    end
end

axis([0, 4.5 -0.005 0.03])
box off
title('Green Constant Slope - Binned by Hour')
xlabel('Hour')
ylabel('Slope')

save2pdf('/Users/edwardsa/Documents/Reiser_Lab/ColorPreference_TroubleShooting/gr_slope_binnedbyhour_with534.pdf')

figure(3)
set(3, 'Position', [30 55 1500 1500]);
exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;

for exp = 1:length(controls)
    datetime = str2num(controls(exp).date_time(end-5:end));
    if strcmp(controls(exp).protocol,'5.27')
        scatter(datetime,uv527slopes(exp527_counter),50,controls(exp).color)
        hold on
        exp527_counter = exp527_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.31')
        scatter(datetime,uv531slopes(exp531_counter),50,controls(exp).color,'filled')
        hold on
        exp531_counter = exp531_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.34')
        scatter(datetime,uv534slopes(exp534_counter),50,controls(exp).color,'filled')
        hold on
        exp534_counter = exp534_counter+1;
    end
end

box off
xlabel('Time (hhmmss)')
ylabel('Slope')
save2pdf('/Users/edwardsa/Documents/Reiser_Lab/ColorPreference_TroubleShooting/uv_slope_over_time_recenthilite_w534.pdf')


figure(4)
set(4, 'Position', [30 55 1500 1500]);
exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;

for exp = 1:length(controls)
    datetime = str2num(controls(exp).date_time(end-5:end));
    if strcmp(controls(exp).protocol,'5.27')
        scatter(datetime,gr527slopes(exp527_counter),50,controls(exp).color)
        hold on
        exp527_counter = exp527_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.31')
        scatter(datetime,gr531slopes(exp531_counter),50,controls(exp).color,'filled')
        hold on
        exp531_counter = exp531_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.34')
        scatter(datetime,gr534slopes(exp534_counter),50,controls(exp).color,'filled')
        hold on
        exp534_counter = exp534_counter+1;
    end
end

box off
xlabel('Time (hhmmss)')
ylabel('slope')

save2pdf('/Users/edwardsa/Documents/Reiser_Lab/ColorPreference_TroubleShooting/gr_slope_over_time_recenthilite_w534.pdf')

figure(5)
set(5, 'Position', [30 55 1500 1500]);
exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;


for exp = 1:length(controls)
    datetime = str2num(controls(exp).date_time(end-5:end));
    
    if strcmp(controls(exp).line_name,'GMR_SS00179')
    c = 'r';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00194')
    c = 'b';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00200')
    c = 'g';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00205')
    c = [0.7 .55 0.9];
    end
    
    
    
    if strcmp(controls(exp).protocol,'5.27')
        scatter(datetime,uv527slopes(exp527_counter),50,c,'filled')
        hold on
        exp527_counter = exp527_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.31')
        scatter(datetime,uv531slopes(exp531_counter),50,c,'filled')
        hold on
        exp531_counter = exp531_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.34')
        scatter(datetime,uv534slopes(exp534_counter),50,c,'filled')
        hold on
        exp534_counter = exp534_counter+1;
    end
end

figure(6)
set(6, 'Position', [30 55 1500 1500]);
exp527_counter = 1;
exp531_counter = 1;
exp534_counter = 1;


for exp = 1:length(controls)
    datetime = str2num(controls(exp).date_time(end-5:end));
    
    if strcmp(controls(exp).line_name,'GMR_SS00179')
    c = 'r';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00194')
    c = 'b';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00200')
    c = 'g';
    end
    if strcmp(controls(exp).line_name,'GMR_SS00205')
    c = [0.7 .55 0.9];
    end
    
    if strcmp(controls(exp).protocol,'5.27')
        scatter(datetime,gr527slopes(exp527_counter),50,c)
        hold on
        exp527_counter = exp527_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.31')
        scatter(datetime,gr531slopes(exp531_counter),50,c)
        hold on
        exp531_counter = exp531_counter+1;
    end
    if strcmp(controls(exp).protocol,'5.34')
        scatter(datetime,gr534slopes(exp534_counter),50,c)
        hold on
        exp534_counter = exp534_counter+1;
    end
end
