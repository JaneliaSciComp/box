function Y = ma(X, n)
% function Y = ma(X, n)
% This function computes the n-point moving average of X.
Z = [zeros(1,n), X];
N = 1:length(X);
Av = Z(N);
for j = 1:(n-1)
    Av = Av + Z(N+j);
end

Y = Av/(n);
