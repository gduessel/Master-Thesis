function [output,timing] = global_solve_upper(p,p_original,x,options,uppersolver,timing)

if ~isempty(p.binary_variables)
    local_gave_good = find(abs(x(p_original.binary_variables)-fix(x(p_original.binary_variables)))< options.bnb.inttol);
    p.lb(p.binary_variables(local_gave_good)) = fix(x(p.binary_variables(local_gave_good)));
    p.ub(p.binary_variables(local_gave_good)) = fix(x(p.binary_variables(local_gave_good)));  
    for i = 1:3
        p = update_eval_bounds(p);
        p = propagate_bounds_from_equalities(p);  
        p = update_monomial_bounds(p);
    end
end

if ~isempty(p_original.integer_variables)
    local_gave_good = find(abs(x(p.integer_variables)-fix(x(p.integer_variables)))< options.bnb.inttol);
    p.lb((p.integer_variables(local_gave_good))) = fix(x(p.integer_variables(local_gave_good)));
    p.ub((p.integer_variables(local_gave_good))) = fix(x(p.integer_variables(local_gave_good)));
    for i = 1:3
        p = update_eval_bounds(p);
        p = propagate_bounds_from_equalities(p);
        p = update_monomial_bounds(p);
    end
end

% The bounds and relaxed solutions have been computed w.r.t to the relaxed
% bilinear model. We only need the original bounds and variables.
p.lb = p.lb(1:length(p_original.c));
p.ub = p.ub(1:length(p_original.c));

x = x(1:length(p_original.c));
%         
p_upper = p_original;

p_upper.lb = p.lb;
p_upper.ub = p.ub;

% KNITRO does not like fixed binary/integer variables, so we remove them
fixed_binary = find(p_upper.lb(p_upper.binary_variables) == p_upper.ub(p_upper.binary_variables));
fixed_integer = find(p_upper.lb(p_upper.integer_variables) == p_upper.ub(p_upper.integer_variables));
p_upper.binary_variables(fixed_binary) = [];if length(p_upper.binary_variables)==0;p_upper.binary_variables = [];end
p_upper.integer_variables(fixed_integer) = [];if length(p_upper.integer_variables)==0;p_upper.integer_variables = [];end

% Pick an initial point (this can be a bit tricky...)
lbinfbounds = find(isinf(p.lb));
ubinfbounds = find(isinf(p.ub));
switch p.options.bmibnb.localstart
    case 'relaxed'
        p_upper.x0 = x;
    case 'boxcenter'
        p_upper.x0 = x;        
        p_upper.x0(lbinfbounds)=0;
        p_upper.x0(ubinfbounds)=0;
    case 'zero'       
        p_upper.x0 = zeros(length(p.lb),1);
    otherwise
        error('Unknown local starting point option');
end

% Find x(a)*x(b) where x(a) or x(b) is fixed, and remove from Q
[a,b,kk] = find(triu(2*p_upper.Q));
for i = 1:length(a)
    if p.lb(a(i)) == p.ub(a(i))
        p_upper.c(b(i)) = p_upper.c(b(i)) + p.lb(a(i))*kk(i);
        p_upper.Q(a(i),b(i))=0;
        p_upper.Q(b(i),a(i))=0;
    elseif p.lb(b(i)) == p.ub(b(i))
        p_upper.c(a(i)) = p_upper.c(a(i)) + p.lb(b(i))*kk(i);
        p_upper.Q(a(i),b(i))=0;
        p_upper.Q(b(i),a(i))=0;
    end
end

% Save time
p_upper.options.saveduals = 0;

% Solve upper bounding problem
p_upper.options.usex0 = 1;
tstart = tic;
try
    output = feval(uppersolver,p_upper);
catch
    output.Primal = zeros(length(p_upper.lb),1);
    output.Problem = -1;
end
if isempty(output.Primal)
     output.Primal = zeros(length(p_upper.lb),1);
end

timing.uppersolve = timing.uppersolve + toc(tstart);

% Project into the box (numerical issue)
output.Primal(output.Primal<p_upper.lb) = p_upper.lb(output.Primal<p_upper.lb);
output.Primal(output.Primal>p_upper.ub) = p_upper.ub(output.Primal>p_upper.ub);


