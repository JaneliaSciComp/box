function [slope,intercept] = linnormal(x,y)

% x = row vector
% y = matrix of observations, same number of rows as X

n = length(x);
xy = bsxfun(@times,x,y);

slope = (n*sum(xy,2) - sum(x)*sum(y,2))/(n*sum(x.^2) - sum(x)^2);
intercept = mean(y,2)-slope*mean(x);
