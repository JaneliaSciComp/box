function [I] = mark_square_object(pos_y,pos_x,value,I,marker_size)

if( nargin < 5 )
    marker_size = 5;
end

[y_max, x_max] = size(I);

x_start = max(1,floor(pos_x)-marker_size);
x_end = min(x_max,floor(pos_x)+marker_size);

y_start = max(1,floor(pos_y)-marker_size);
y_end = min(y_max,floor(pos_y)+marker_size);

I(y_start:y_end,x_start:x_end) = value;
