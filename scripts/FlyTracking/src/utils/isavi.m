
function  res = isavi(inputFile)

%% read an image either from an avi file or using the given format

dots = find(inputFile ==  '.');
if( numel(dots) == 0 )
    extension = '---';
else
    last_dot = dots(end);
    extension = inputFile(last_dot+1:end);
end

if( strcmp(extension,'avi') )
    res = 1;
else
    res = 0;
end
