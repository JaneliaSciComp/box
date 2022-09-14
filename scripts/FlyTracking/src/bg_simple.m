
function [Ibg,Shist] = bg_simple(inputFile,frameIndices,histScale,outputFile, bgThresh, sbfmf_info)
% updated by MBR to include waitbars
% supports sbfmf files, and bg_sub is made simpler

numFrames = length(frameIndices);

if isempty(sbfmf_info) % then compute a new bg image

    image = load_image(inputFile, frameIndices(1), sbfmf_info); 
    [rows,cols] = size((image));

    %%% if there are lots of frames, use only first 10000 frames 
    %%% for bg estimation
    if( numFrames > 10000 )
        frameIndices = frameIndices(1:10000);
        numFrames = 10000;
    end

    %%%% go over 100 random images and generate histogram 
    %%%% for each pixel location
    num_images = min(numFrames,100);
    imIndices = ceil(rand(num_images,1) * numFrames-1)+1;
    imIndices = frameIndices(imIndices);
    binNumber = 256/histScale;
    Shist = uint8(zeros(rows,cols,binNumber));
    h1 = waitbar(0,'Computing background image');

    for f=1:length(imIndices),
        image = load_image(inputFile, imIndices(f), sbfmf_info); 
        image = floor(double((image))/histScale)+1;
        %%% output to a cxx (tried with sub2ind and it was slower)
        for r=1:rows,
            for c=1:cols,
                Shist(r,c,image(r,c)) = uint8(double(Shist(r,c,image(r,c))) + 1);
            end
        end 
        waitbar(f/length(imIndices), h1);
    end
    close(h1);

    %%% background gets the value with highest probability
    [max_val,max_ind] = max(Shist,[],3);
    Ibg = max_ind*histScale;
else
    sbfmf_info.fid = fopen(inputFile, 'r' ); %this is where we put in handle to sbfmf
    Ibg = sbfmf_info.bgcenter'; % need transpose on bg stored in sbfmf
end

imwrite(uint8(Ibg),outputFile);

Ibg_top = round(Ibg + bgThresh);
Ibg_top(Ibg_top > 255) = 255;

Ibg_bottom = round(Ibg - bgThresh);
%better to be safe...
Ibg_bottom(Ibg_bottom < 0) = 0;

% save these to disk
imwrite(uint8(Ibg_top) , [outputFile(1:end-4) '_top.bmp']);
imwrite(uint8(Ibg_bottom) , [outputFile(1:end-4) '_bottom.bmp']);         


if isempty(sbfmf_info)
    % just a placehodler, do nothing...
else % if necessary, close the movie file
   fclose(sbfmf_info.fid);
   sbfmf_info.fid = [];
end

