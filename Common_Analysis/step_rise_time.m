function [yss, tr, yssidx] = step_rise_time(t,y)
% [yss, tr, yssidx] = step_rise_time(t,y)
% yss: largest absolute value in y
% tr: rise time (10%-90%) to yss 
% yssidx: sample idx at which yss maximum occurs
% 
% modified, simplified from:
%STEPSPECS System Step Response Specifications.
% [OS,Ts,Tr]=STEPSPECS(T,Y,Yss,Sp) returns the percent overshoot OS,
% settling time Ts, and rise time Tr from the step response data contained
% in T and Y.
% Y is a vector containing the system response at the associated time
% points in the vector T. Yss is the steady state or final value of the
% response.
% If Yss is not given, Yss=Y(end) is assumed. Sp is the settling time
% percentage.
% If Sp is not given, Sp = 2% is assumed. The settling time is the time it
% takes the response to converge within +-Sp percent of Yss.
% The rise time is assumed to be the time for the response to initially
% travel from 10% to 90% of the final value Yss.
% 
% D.C. Hanselman, University of Maine, Orono, ME 04469
% Mastering MATLAB 7
% 2005-03-20
% modified a few ways by MBR to handle pos, neg, etc.

%--------------------------------------------------------------------------
if nargin<2
   error('At Least Two Input Arguments are Required.')
end
if numel(t)~=length(t) || numel(y)~=length(y)
   error('T and Y Must be Vectors.')
end

[yss, yssidx] = largest_val(y);

if yss==0
   warning('Yss Must be Nonzero.')
   yss = nan; tr = nan; yssidx = nan;
   return
end

peak_neg = 0;
if yss<0 % handle case where step response may be negative
    % warning('the peak response is negative')
   peak_neg = 1; 
   y=-y;
   yss=-yss;
end

t=t(:);
y=y(:);
% find rise time using linear interpolation
idx1=find(y>=yss/10,1);
idx2=find(y>=9*yss/10,1);
if isempty(idx1) || idx1==1 || isempty(idx2)
   warning('Not Enough Data to Find Rise Time.')
   yss = nan; tr = nan; yssidx = nan;
else
    alpha=(yss/10-y(idx1-1))/(y(idx1)-y(idx1-1));
    t1=t(idx1-1)+alpha*(t(idx1)-t(idx1-1));
    alpha=(9*yss/10-y(idx2-1))/(y(idx2)-y(idx2-1));
    t2=t(idx2-1)+alpha*(t(idx2)-t(idx2-1));
    tr=t2-t1;
end

if (peak_neg) % reinvert y value for output
    yss=-yss;
end