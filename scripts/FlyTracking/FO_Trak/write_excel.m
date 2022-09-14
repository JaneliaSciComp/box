function write_excel(analysis_info,analysis_info_tube,outputDir)

outputFile = [outputDir filesep 'analysis.xls'];

%%% tranfer data from analysis_info into a matrix
mat(:,1) = analysis_info.avg_vel';
mat(:,2) = analysis_info.avg_vel_x';
mat(:,3) = analysis_info.avg_vel_y';
mat(:,4) = analysis_info.median_vel';
mat(:,5) = analysis_info.median_vel_x';
mat(:,6) = analysis_info.median_vel_y';
mat(:,7) = analysis_info.tracked_num';
mat(:,8) = analysis_info.moving_fraction';
mat(:,9) = analysis_info.avg_mov_vel';
mat(:,10) = analysis_info.ang_vel';


%header = 'FlyTracker TrackAnalysis';
colnames = {'avg_vel','avg_vel_x','avg_vel_y',...
        'median_vel','median_vel_x','median_vel_y',...
        'tracked_num','moving_fraction','avg_mov_vel',...
        'ang_vel'};



%%% If more than one tube we wish to output them one by one
num_tubes = numel(analysis_info_tube);
col_num = length(colnames);
header = {'All tubes','*','*','*','*','*','*','*','*','*'};
if( num_tubes > 1 )
    colnames = repmat(colnames,1,num_tubes+1);
    header = repmat(header,1,num_tubes+1);
    for i=1:num_tubes,
        header{col_num*i+1} = ['Tube' num2str(analysis_info_tube(i).index)];
        mat(:,col_num*i+1) = analysis_info_tube(i).avg_vel';
        mat(:,col_num*i+2) = analysis_info_tube(i).avg_vel_x';
        mat(:,col_num*i+3) = analysis_info_tube(i).avg_vel_y';
        mat(:,col_num*i+4) = analysis_info_tube(i).median_vel';
        mat(:,col_num*i+5) = analysis_info_tube(i).median_vel_x';
        mat(:,col_num*i+6) = analysis_info_tube(i).median_vel_y';
        mat(:,col_num*i+7) = analysis_info_tube(i).tracked_num';
        mat(:,col_num*i+8) = analysis_info_tube(i).moving_fraction';
        mat(:,col_num*i+9) = analysis_info_tube(i).avg_mov_vel';
        mat(:,col_num*i+10) = analysis_info_tube(i).ang_vel';        
    end
end

if (exist([outputDir filesep 'LED_status.mat']) == 2)
    load([outputDir filesep 'LED_status.mat'])
    header = [{'LED status'} header];
    colnames = [{'   '} colnames];
    % occasionally LED_status and mat data are not of the same length
    num_pts = min( [size(mat,1) size(LED_status, 1)]);
    mat = [LED_status(1:num_pts), mat(1:num_pts,:)];
%    mat = [LED_status(1:end-1), mat];
end


%if( ispc )
if( 0 )
   xlswrite(mat,header,colnames,outputFile);
else
   fid = fopen(outputFile,'w');
   if( fid < 0 ) 
       disp('cannot open excel file for writing');
       exit;
   end
   %%% write header
   for i=1:length(header),
       fprintf(fid,'%s  \t',header{i});
   end;   
   fprintf(fid,'\n');
   
   %%% write column names
   for i=1:length(colnames),
       fprintf(fid,'%s  \t',colnames{i});
   end;
   fprintf(fid,'\n');
   %%% write data
   for i=1:size(mat,1),
       fprintf(fid,'%g  \t',mat(i,1:end-1));
       fprintf(fid,'%g \n',mat(i,end));
   end
   fclose(fid);
end


