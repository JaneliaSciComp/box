function [Y,I] = largest_val(X)
% [Y,I] = largest_val(X)
% returns the point in the data set with the largest absolute value, i.e.
% farthest from zero

[Y,I] = max(abs(X));
Y = X(I);






