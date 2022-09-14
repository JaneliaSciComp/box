experiments_4p1 = '/Volumes/flyolympiad/Austin/Reiser_Lab/data/5_13/5_13_followedby_4_1/GMR_SS00179_shi_Zeus_20141008T160137';
experiments_5p13 = '/Volumes/flyolympiad/Austin/Reiser_Lab/data/5_13/5_13_followedby_4_1/GMR_SS00200_shi_Apollo_20141008T151916';
output_base_dir_4p1 = 'Output_1.1_1.7';
output_base_dir_5p13 = 'Output_1.1_1.7';

cd([experiments_5p13 filesep output_base_dir_5p13])
load('02_5.13_34_analysis_results.mat')

peakdata513 = nan(3,11);
tubes = [2,4,5];
for i = 1:3,
    peakdata513(i,:) = analysis_results(tubes(i)).seq8.cum_dir_index_peak(:);
end

x=[5,7,10,15,20,30,40,50,75,100,200];
plot(x,mean(peakdata513,1),'r-')
hold on

%%

cd([experiments_4p1 filesep output_base_dir_4p1])
load('01_4.1_34_analysis_results.mat')

peakdata41 = nan(3,8);

for i = 1:3,
    peakdata41(i,:) = analysis_results(tubes(i)).seq5.cum_dir_index_peak(:);
end

x = [0 12 24 36 48 60 72 84];
plot(x,mean(peakdata41,1),'k-')
hold on
plot([0,200],[0,0],':')
ylim([-8 8])

xlabel('UV intensity')
ylabel('Peak Cumulative Direction Index')
title('GMR\_SS000200 & Shi - Color Preference')

save2pdf(['/Users/edwardsa/Documents/Reiser_Lab/ColorPreference_TroubleShooting/5_13_followedby_4_1/','200_comparison_summary.pdf']);
