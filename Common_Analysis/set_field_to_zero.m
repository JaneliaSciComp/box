function mystr = set_field_to_zero(mystr, field_array)
% This function will take a structure and set the specified fields to zero.
% extremely simple, no error checking.
% MBR, 07/07/10

for k = 1:length(field_array)
    mystr.(field_array{k}) = 0;
end