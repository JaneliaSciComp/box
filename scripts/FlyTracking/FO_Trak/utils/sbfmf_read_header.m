function sbfmf_info = sbfmf_read_header(filename)
% slightly modified by MBR to simplify arguments
% function [nr,nc,nframes,bgcenter,bgstd,frame2file,version,differencemode] = ...
%   sbfmf_read_header(filename)

if ~issbfmf(filename)
    warning('movie does not appear to be an sbfmf')
    sbfmf_info = [];
else
    fp = fopen( filename, 'r' );
    nbytesver = double( fread( fp, 1, 'uint32' ) );
    sbfmf_info.version = fread(fp,nbytesver);
    nc = double(fread(fp,1,'uint32'));
    nr = double(fread(fp,1,'uint32'));
    nframes = double(fread(fp,1,'uint32'));
    sbfmf_info.differencemode = double(fread(fp,1,'uint32'));
    indexloc = double(fread(fp,1,'uint64'));
    bgcenter = fread(fp,nr*nc,'double');
    sbfmf_info.bgcenter = reshape(bgcenter,[nr,nc]);
    bgstd = fread(fp,nr*nc,'double');
    sbfmf_info.bgstd = reshape(bgstd,[nr,nc]);
    fseek(fp,indexloc,'bof');
    sbfmf_info.frame2file = fread(fp,nframes,'uint64');
    sbfmf_info.nc = nc;
    sbfmf_info.nr = nr;
    sbfmf_info.nframes = nframes;
    fclose(fp);    
end