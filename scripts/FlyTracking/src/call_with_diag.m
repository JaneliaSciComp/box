function varargout = call_with_diag(fid,fcn,varargin)

%persistent callmap;

DO_DIAG = false;
if ~DO_DIAG
    % early return
    switch fcn
        case '_init'
        case '_dump'
        otherwise
            [varargout{1:nargout}] = feval(fcn,varargin{:});
    end
    return;
end

if isempty(fid)
    fid = 1;
end

switch fcn
    case '_init'
        callmap = containers.Map();
        return;
    case '_dump'        
        fprintf(fid,' ## Call dump ##\n');
        kys = callmap.keys;
        for k = kys(:)', k = k{1}; %#ok<FXSET>
            v = callmap(k);
            fprintf(fid,'%s: ncall %d maxargbytes %d\n',k,v.n,v.maxargbytes);
        end
        return;
end        

% call stack
NSTKDISP = 2;
stk = dbstack;
stk = stk(2:end); % don't include call_with_diag
ndisp = min(NSTKDISP,numel(stk));
for i = 1:ndisp
    fprintf(fid,'%s: %s at %d\n',stk(i).file,stk(i).name,stk(i).line);
end

% call
fprintf(fid,'# %s\n',fcn);
if ~callmap.isKey(fcn)
    callmap(fcn) = struct('n',0,'maxargbytes',0);
end
scm = callmap(fcn);
scm.n = scm.n+1;

% args
for i = 1:numel(varargin)
    vargidx = 2+i;
    varname = inputname(vargidx);
    if isempty(varname) % literal/expression for input arg
        arg = varargin{i};
        fprintf(fid,'nm/sz: <unk>. %s.\n',mat2str(size(arg)));
    else
        cmd = sprintf('whos(''%s'')',varname);
        s = evalin('caller',cmd);
        fprintf(fid,'nm/sz/by/gl: %s. %s. %d. %d.\n',s.name,mat2str(s.size),s.bytes,s.global);
        scm.maxargbytes = max(scm.maxargbytes,s.bytes);
    end
end

callmap(fcn) = scm;

[varargout{1:nargout}] = feval(fcn,varargin{:});
    


