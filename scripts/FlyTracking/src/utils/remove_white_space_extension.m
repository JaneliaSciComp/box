function string_out = remove_white_space_extension(string_in)
% use this function to remove the whitespaces from movie file names, and
% then also remove the extension so that the name can be used for a folder
% to be created

temp_str = string_in(~isspace(string_in));
dots = find(temp_str ==  '.');

if( numel(dots) == 0 )
    string_out = temp_str;   % presumably no extension in the string
else
    last_dot = dots(end);
    string_out = temp_str(1:last_dot-1);   %strip off the extension
end
