function [params] =  read_params_olympiad(paramFile, inputFile, outputDir)

%% read parameter file for fly_tracker application
% both inputFile and outputDir are an absolute path

params.inputFile = inputFile;
params.outputDir = outputDir;
%% if no values are in the paramFile, set to default values
params.startFrame = 1;
params.endFrame = -1;
params.bgFile = -1;
params.roiFile = -1;
params.genVideoOutput = 0;
params.updateBg = 0;
params.displayTracking = 0;
params.tubeToProcess = -1;
params.pixToMm = 0;
params.frameRate = -1;
params.moveThresh = 0;
params.maxObjNum = 50;

input_text = textread(paramFile,'%s','commentstyle','matlab');
tokens = {'outputDir','startFrame','endFrame','maxObjNum',...
        'bgFile','roiFile','bgThresh','updateRoi','roiPath',...
        'genVideoOutput','updateBg','displayTracking',...
        'tubeToProcess','pixToMm','frameRate','moveThresh'};

%% parse input
for p=1:length(input_text),
    i = find( strcmp(tokens,input_text(p)) );
    if( numel(i)>0 )
        index(p) = i;
    else
        index(p) = 0;
    end
end

p=1;
while( p<=length(input_text) )
    curr_token = cell2mat(tokens(index(p)));
    i = p+1; token_value = [];
    while( i <= length(index) & index(i) == 0 )
        if( isempty(token_value) )
            token_value = cell2mat(input_text(i));
        else
            token_value = [token_value, ' ', cell2mat(input_text(i))];
        end
        i = i+1;
    end
    p = i;
    switch curr_token,
        case 'outputDir',
            params.outputDir = token_value;
        case 'roiPath',
            params.roiPath = token_value;
        case 'updateRoi',
            params.updateRoi = str2num(token_value);
        case 'startFrame',
            params.startFrame = str2num(token_value);
        case 'endFrame',
            params.endFrame = str2num(token_value);
        case 'bgFile',
            params.bgFile = token_value;
        case 'roiFile',
            params.roiFile = token_value;
        case 'genVideoOutput',
            params.genVideoOutput = str2num(token_value);
        case 'updateBg',
            params.updateBg = str2num(token_value);
        case 'displayTracking',
            params.displayTracking = str2num(token_value);
        case 'pixToMm',
            params.pixToMm = str2num(token_value);
        case 'frameRate',
            params.frameRate = str2num(token_value);
        case 'moveThresh',
            params.moveThresh = str2num(token_value);
        case 'maxObjNum',
            params.maxObjNum = str2num(token_value);
        case 'bgThresh'
            params.bgThresh = str2num(token_value);
        case 'tubeToProcess',
            if( strcmp(token_value,'all') )
                params.tubeToProcess = 0;
            elseif( params.tubeToProcess < 0 )
                params.tubeToProcess = str2num(token_value);
            else
                params.tubeToProcess = [params.tubeToProcess, str2num(token_value)];
            end
        otherwise,
            disp(['***WARNING***: Uknown entry in param file: ' curr_token]);
    end
end

if( params.bgFile == -1 )
    params.bgFile = [params.outputDir filesep 'bg.bmp'];
end
                        
params.bgFile = [params.outputDir filesep params.bgFile];
 
if( params.roiFile ~= -1 )
    params.roiFile = [params.outputDir filesep params.roiFile];
end

%%% if the end frame is not given
%%% and the input is an avi file, read the number of frames from the avi
%%% file
if(params.endFrame<0)
    if( isavi(params.inputFile) ),
        info = aviinfo(params.inputFile);
        params.endFrame = info.NumFrames;
    elseif(issbfmf(params.inputFile))
        sbfmf_info = sbfmf_read_header(params.inputFile);
        params.endFrame = sbfmf_info.nframes;
    else
        params.endFrame = params.startFrame + 2;
    end
end

params.frameIndices = [params.startFrame:params.endFrame];
params.tubeToProcess = unique(params.tubeToProcess);

%%%% prepare output dir
if( ~exist(params.outputDir) )
    error('The output folder does not exist and should')
    %     curr_dir = pwd;
    %     %cd(params.workDir);
    %     str = sprintf('!mkdir %s',params.outputDir);
    %     eval(str);
    %     cd(curr_dir);
end
%params.outputDir = [params.workDir filesep params.outputDir];


