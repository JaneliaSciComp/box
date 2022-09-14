function  I = load_image(inputFile, index, sbfmf_info)

%% read an image either from an avi file or using the given format
% if (mod(index, 10) == 0)
%     disp(['loading image ' num2str(index)]);
% end

if ~isempty(sbfmf_info)
    [I,stamp] = sbfmfreadframe(index,sbfmf_info.fid,sbfmf_info.frame2file,sbfmf_info.bgcenter);    
elseif( isavi(inputFile) )
    if( ispc )
        try 
            frame = aviread(inputFile,index);
            I = frame2im(frame);            
        catch
            disp(['error trapped, frame opened with aviread']);
        end
    else
        %%%% this would be the place to put some avireader for the
        %%%% cluster...
    end
else 
    infile = sprintf(inputFile,index);
    I = imread(infile);
end

if( size(I,3)>1 )
    I = rgb2gray(I);
end

%disp(['loaded image ' num2str(index)]);
