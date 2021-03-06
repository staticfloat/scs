clear all; close all;

disp('------------------------------------------------------------')
disp('WARNING: this can take a very long time to run.')
disp('It may also crash/run out of memory.')
disp('------------------------------------------------------------')

save_results = false;

run '../../matlab/make_scs.m'
addpath('../../matlab/')

sizes = [600 3000;2000 10000;6000 30000];
sze_str{1} = 'small';
sze_str{2} = 'med';
sze_str{3} = 'large';

%%
for i=1:size(sizes,1)
    disp(sprintf('Solving %s l1 regularized logistic regresssion.',sze_str{i}))
    clearvars -except i sizes sze_str direct_data indirect_data save_results
    
    str = ['data/l1logreg_' sze_str{i}];
    randn('seed',sum(str));rand('seed',sum(str))
    
    p = sizes(i,1); % features
    q = sizes(i,2); % total samples
    density = 0.1;
    
    w_true = sprandn(p,1,0.2);
    
    X_tmp = 3*sprandn(p, q, density);
    ips = -w_true'*X_tmp;
    ps = (exp(ips)./(1 + exp(ips)))';
    labels = 2*(rand(q,1) < ps) - 1;
    
    X_pos = X_tmp(:,labels==1);
    X_neg = X_tmp(:,labels==-1);
    
    X = [X_pos -X_neg]; % include labels with data
    
    lam = 0.1*norm(X*ones(q,1),'inf')/2;
    
    clear X_tmp ips ps labels;
    %%
    c = [zeros(p,1);lam*ones(p,1);ones(q,1);zeros(q,1);zeros(q,1)];
    b = [zeros(p,1);zeros(p,1);ones(q,1)];
    
    Anz = nnz(X) + 6*q + 4*p;
    
    %At = zeros(2*p + 3*q,2*p + q + 6*q);
    At = sparse([],[],[],2*p + 3*q,2*p + q + 6*q,Anz);
    At(:,1:2*p+q) = [speye(p) -speye(p) sparse(p,q) sparse(p,q) sparse(p,q);
        -speye(p) -speye(p) sparse(p,q) sparse(p,q) sparse(p,q);
        sparse(q,p) sparse(q,p) sparse(q,q) speye(q) speye(q)]';
    idx = 2*p+q;
    for j=1:q
        b = [b;[0;1;0]];
        M1 = sparse(q,3);
        M1(j,1) = 1;
        M2 = sparse(q,3);
        M2(j,3) = -1;
        At(:,idx+1:idx+3) = [sparse(p,3); sparse(p,3); M1; M2; sparse(q,3)];
        idx = idx + 3;
    end
    for j=1:q
        b = [b;[0;1;0]];
        M1 = sparse(q,3);
        M1(j,1) = 1;
        M2 = sparse(q,3);
        M2(j,3) = -1;
        At(:,idx+1:idx+3) = [[-X(:,j) sparse(p,2)]; sparse(p,3); M1 ; sparse(q,3); M2];
        idx = idx + 3;
    end
    A = sparse(At');
    data.A = A;
    data.b = b;
    data.c = c;
    
    K.f = 0;
    K.l = p+p+q;
    K.q = [];
    K.s = [];
    K.ep = 2*q;
    K.ed = 0;
    
    params.VERBOSE = 1;
    params.SCALE = 1;
    %write_scs_data_sparse(data,K,params,str)
    direct_data.output{i} = evalc('[xd,yd,sd,infod]=scs_direct(data,K,params);');
    direct_data.output{i}
    direct_data.x{i} = xd;
    direct_data.y{i} = yd;
    direct_data.s{i} = sd;
    direct_data.info{i} = infod;
    
    indirect_data.output{i} = evalc('[xi,yi,si,infoi]=scs_indirect(data,K,params);');
    indirect_data.output{i}
    indirect_data.x{i} = xi;
    indirect_data.y{i} = yi;
    indirect_data.s{i} = si;
    indirect_data.info{i} = infoi;
    
    if (save_results);
        save('data/l1logreg_direct', 'direct_data');
        save('data/l1logreg_indirect', 'indirect_data');
    end
    
    
end

%{
%% cvx can solve:
cvx_begin
variable w(p)
minimize(sum(log_sum_exp([zeros(1,q);w'*full(X)])) + lam * norm(w,1))
cvx_end
%}
%{
%% cvx cone formulation:
tic
cvx_begin
variables x(2*p + 3*q) s(2*p + q + 6*q)
minimize(c'*x)
A*x + s == b
s(1:K.l) >= 0
idx = K.l;
for i=1:K.ep
    -s(idx+1) >= rel_entr(s(idx+2),s(idx+3));
    idx = idx + 3;
end
output = evalc('cvx_end')
cvx.output{i} = output;
cvx.x{i} = x;
cvx.s{i} = s;
if (save_results); save('data/l1logreg_cvx', 'cvx'); end
toc
%}
