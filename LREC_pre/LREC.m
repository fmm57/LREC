function [y,Weight,rule,time,classification_rate_training,classification_rate_testing,ConMAT,ConMAT_train,ConMAT_test]=LREC(dataset,ninput,fix_the_model,parameters,ETA)
%%% mean dis
tic

[N, nm] = size(dataset);      % N is the number of samples (not known in real-time mode);
n=ninput;            % n is the number of inputs
m=nm-n;

%%%=====================================
%%%%    Initialization
%%%=====================================

eta=ETA;

b1=parameters(1);
b2=parameters(2);
c1=parameters(3);
c2=parameters(4);

R=1;
rule(1)=R;
lambda(1)=1;
k=1;

Weight = 0.4*ones(n+1,m,R);

%%% recursive parameters
standarized_mean=zeros(1,nm);
standarized_std=zeros(1,nm);
covariance=zeros(n,m);
error=zeros(1,m);
cov_w_x(R,:)=zeros(1,n);
cov_x_t=zeros(m,n);
cov_w_t(:,:,R)=zeros(m,n);
std_w(R,:)=zeros(1,n);
std_output=zeros(1,m);
std_err=zeros(1,m);
mean_output=zeros(1,m);
mean_err=zeros(1,m);
Omega =1000000;
population(R)=1;
% *************************************************************************
stream=dataset(1,:);

y(1,:) = dataset(1,n+1:nm);    % the prediction starts from the 3rd sample
y(2,:) = dataset(2,n+1:nm);    % therefore, samples 1 and 2 are directly taken from the training data

objective = 'G';


if objective == 'G'
    merging=0;
else
    merging=1;
end

xek = [1, stream(1:n)]';        % extended inputs vector

if objective=='G'
    Ck = Omega*eye(R*(n+1));       % Co-variance matrix, (n+1)x(n+1)
    Psik = lambda(k)*xek;
elseif objective=='L'               % Local parameter estimation
    pik = zeros(n+1,m,R);        % initialise globally optimal local sub-models parameters
    cik(:,:,:) = Omega*eye(n+1);    % initialise globally optimal covariance matrix
end

%%%=====================================
%%%%    Main_loop
%%%=====================================

for k=2:N
    stream=(dataset(k,:));
    stream_old=dataset(k-1,:);
    stream(1:n)=stream(1:n);
    rule(k)=R;
    
    if objective=='G'        % RLS
        Ck_old = Ck;
    elseif objective=='L'    % wRLS
        pik_old = pik;
        cik_old = cik;
    end
    
    Weight_old = Weight;
    xek = [1, stream(1:n)]';
    rule(k)=R;
    
    %%%============================
    standarized_mean_old=standarized_mean;
    standarized_std_old=standarized_std;
    covariance_old=covariance;
    
    cov_w_x_old=cov_w_x;
    cov_x_t_old=cov_x_t;
    cov_w_t_old=cov_w_t;
    
    std_w_old=std_w;
    standarized_std_old=standarized_std;
    
    std_output_old=std_output;
    std_err_old=std_err;
    mean_output_old=mean_output;
    mean_err_old=mean_err;
    %%%============================
    xek = [1, stream(1:n)]';
    
    if (k<=fix_the_model)
        %%% =========Starting Hyper_plane_loop_1 =========
        grat=10^-19;
        mu=zeros(R,1);
        sum_tau = 0;
        tau = 0;
        disperrule=zeros(R,1);
        
        standarized_mean=standarized_mean_old+(stream-standarized_mean_old)/k+grat;
        standarized_std=((k-2)/(k-1)*standarized_std_old)+((stream-standarized_mean_old).^(2)/k)+grat;
        
        for i=1:R
            for j=1:m
                wtt(n+m,:)=Weight((i-1)*(n+1)+1:i*(n+1),j)';
                wtttt(i,:)=wtt(n+m,:);
                wxb(i,j)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),j);
                hp(i,1)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),1);
                if wxb(i,j)>0
                    mu(i,j)=wxb(i,j);
                else
                    mu(i,j)=1*10^-19*wxb(i,j);
                end
            end
            tau(i) = prod(mu(i,:));    % firing strength of rule i
            sum_tau = sum_tau + tau(i); % sum of the firing strength of the rules
        end
        
        lambda=tau/sum_tau;
        
        
        %%% ======End of Hyper_Plane_loop_1======
        
        if R>1
            for i=1:R
                for j=1:m
                    ddd(i,j)=abs(wtttt(R,1)-wtttt(R-1,1));
                    costheta(i,j)=wtttt(R,:)*wtttt(R-1,:)'/(sqrt(sum(wtttt(R,:).^2))*sqrt(sum(wtttt(R-1,:).^2)));
                    angle_hp(i,j)=acos(costheta(i,j));
                end
            end
        end
        
        [x,winner]=max(tau');
        
        for i=1:R,      Psik((i-1)*(n+1)+1:i*(n+1),1) = lambda(i)*xek;    end
        
        
        
        ysem=Psik'*Weight;
        
        
        err=zeros(1,m);
        
        for jk=n+1:nm,    err(jk-n) = ysem(jk-n) - stream(jk);     end
        
        
        covariance=(covariance_old*(k-1)+(((k-1)/k)*(stream(1:n)-standarized_mean_old(1:n))'*(stream(n+1:end)-standarized_mean_old(n+1:end))))/k;
        
        for j=1:m
            mean_output(j)=mean_output_old(j)+(ysem(j)-mean_output_old(j))/k;
            std_output(j)=((k-2)/(k-1)* std_output_old(j))+((ysem(j)- mean_output(j)).^(2)/k);
            mean_err(j)=mean_err_old(j)+(err(j)-mean_err_old(j))/k;
            std_err(j)=((k-2)/(k-1)* std_err_old(j))+((err(j)- mean_err(j)).^(2)/k);
        end
        
        for i=1:R
            for j=1:n
                cov_w_x(i,j)=(cov_w_x_old(i,j)*(k-1)+(((k-1)/k)*(stream(j)-hp(i))*(stream(j)-standarized_mean_old(j))))/k;
            end
        end
        
        for i=1:R
            for j=1:n
                for o=1:m
                    cov_w_t(o,j,i)=(cov_w_t_old(o,j,i)*(k-1)+(((k-1)/k)*(stream(j)-hp(i))*(stream(n+o)-standarized_mean_old(n+o))))/k;
                end
            end
        end
        
        for j=1:n
            for o=1:m
                cov_x_t(o,j)=(cov_x_t_old(o,j)*(k-1)+(((k-1)/k)*(stream(j)-standarized_mean(j))*(stream(o+n)-standarized_mean(o+n))))/k;
            end
        end
        
        for i=1:R
            std_w(i,:)=(((k-1)/k)* std_w_old(i,:))+((stream(1:n)- hp(i,:)).^(2)/k);
        end
        
        for i=1:R
            for j=1:m
                for o=1:n
                    pearson_w_t=cov_w_t(j,o,i)/sqrt(std_w(i,o)*std_output(j));
                    information_gain_w_t(j,o,i)=0.5*(std_w(i,o)+standarized_std(j+n)-sqrt((std_w(i,o)+standarized_std(j+n))^(2)-(4*std_w(i,o)*standarized_std(j+n)*(1-pearson_w_t^(2)))));%-0.5*log10(1-pearson_upper);
                    
                    OC1(j,o,i)=sum(information_gain_w_t(j,o,i));
                    
                    pearson_x_t=cov_x_t(j,o)/sqrt(standarized_std(o)*standarized_std(j+n));
                    OC2(j,o)=0.5*(standarized_std(o)+standarized_std(j+n)-sqrt((standarized_std(o)+standarized_std(j+n))^(2)-(4*standarized_std(o)*standarized_std(j+n)*(1-pearson_x_t^(2)))));%-0.5*log10(1-pearson_upper);
                    
                end
            end
            
            for o=1:n
                pearson_w_x=cov_w_x(i,o)/sqrt(std_w(i,o)*standarized_std(o));
                
                information_gain_w_x(i,o)=0.5*(std_w(i,o)+standarized_std(o)-sqrt((std_w(i,o)+standarized_std(o))^(2)-(4*std_w(i,o)*standarized_std(o)*(1-pearson_w_x^(2)))));%-0.5*log10(1-pearson_upper);
            end
            
            for j=1:m
                IC(i,j)=sum(information_gain_w_x(i,:));
            end
            
            
            ICfinal(i)=sum(IC(i,:));
            OCfinal(i)=sum(sum(OC2))-sum(sum(OC1(:,:,i)));
        end
        %%%======================End of Ic and Oc calculation =============
        
        %%%================================================================
        %%%%    Srating of Rule Growing Mechanism
        %%%================================================================
        if ((abs(ICfinal(winner))>b1) && (abs(OCfinal(winner))<b2))
            
            R = R+1;
            rule(k)=R;
            population(R)=1;
            
            
            if objective=='G'
                Weight_add= zeros(n+1,m);
                for i=1:R-1
                    for j=1:m
                        Weight_add(:,j) = Weight_add(:,j) + lambda(i)*Weight_old((i-1)*(n+1)+1:i*(n+1),j);
                    end
                end
                
                % Calclulate parameters of the NEWLY ADDED rule using RLS
                Weight = [Weight_old; Weight_add];        % adds parameters of the new rule
                Weight_old= Weight;
                
                % RLS. Covariance matrix
                Ro = (R^2+1)/R^2;
                Ck = Ro*Ck_old;
                Ck((R-1)*(n+1)+1:R*(n+1),(R-1)*(n+1)+1:R*(n+1)) = eye(n+1)*Omega;
                Ck_old = Ck;
            elseif objective=='L'    % Locally optimal parameters. Weighted Recursive Least Squares
                pi_add = zeros(n+1,m);
                xek = [1, stream(1:n)]';
                
                for i=1:R-1,  pi_add = pi_add +lambda(i)*pik_old(i);         end
                
                % Parameters of the NEWLY ADDED RULE
                pik(:,:,R) = pik(:,:,winner);   % eq. (27a)
                pik_old = pik;
                
                % Covariance matrix of the newly added rule
                cik(:,:,R) = Omega*eye(n+1); % eq. (32)
                cik_old = cik;
                
                for i=1:R
                    for j=1:m
                        Weight((i-1)*(n+1)+1:i*(n+1),j) = pik(:,j,i);
                    end
                end
                Weight_old = Weight;
            end % to elseif objective=='L'
            
            %%%========================
            
            cov_w_x(R,:)=zeros(1,n);
            cov_x_t=zeros(m,n);
            cov_w_t(:,:,R)=zeros(m,n);
            
            std_w(R,:)=zeros(1,n);
            std_output=zeros(1,m);
            
        else
            population(winner)=population(winner)+1;
            for j=1:n
                cov_w_x(winner,j)=(cov_w_x_old(winner,j)*(population(winner)-1)+(((population(winner)-1)/population(winner))*(stream(j)-hp(winner))*(stream(j)-standarized_mean_old(j))))/population(winner);
                for o=1:m
                    cov_w_t(o,j,winner)=(cov_w_t_old(o,j,winner)*(population(winner)-1)+(((population(winner)-1)/population(winner))*(stream(j)-hp(winner))*(stream(n+o)-standarized_mean_old(n+o))))/population(winner);
                end
            end
        end
        %%%================================================================
        %%%%      Srating of Rule Merging
        %%%================================================================
        if merging==1 && R>1 && rule(end)==rule(end-1)
            
            merged_list=[];
            temp_del=[];
            
            for l=0:R-2
                for hh=1:R-l-1
                    if  ddd(R)<=c1 && angle_hp(R)<c2
                        if isempty(merged_list)==false
                            merged_list(1,1)=(size(wtttt,1)-l);
                            merged_list(1,2)=hh;
                        else
                            No=find(merged_list(:,1:end-1)==size(wtttt,1)-l);
                            No1=find(merged_list(:,1:end-1)==hh);
                            if isempty(No) && isempty(No1)
                                merged_list(end+1,1)=size(wtttt,1)-l;
                                merged_list(end+1,2)=hh;
                            end
                        end
                        break
                    end
                end
            end
            [u1,v1]=size(merged_list);
            del_list=[];
            for i=1:u1
                No2=find(merged_list(i,:)==0);
                if isempty(No2)
                    
                    if population(merged_list(i,1))>population(merged_list(i,2))
                        a=merged_list(i,1);
                        b=merged_list(i,2);
                    else
                        b=merged_list(i,1);
                        a=merged_list(i,2);
                    end
                    wtttt(a,:)=(wtttt(a,:)* population(a)+wtttt(b,:)*population(b))/(population(a)+population(b));
                    population(a)=population(a)+population(b);
                    
                    pik(:,:,a)=(population(a)*pik(:,:,a)+population(b)*pik(:,:,b))/(population(a)+population(b));
                    if objective=='L'
                        cik(:,:,a)=(population(a)*cik(:,:,a)+population(b)*cik(:,:,b))/(population(a)+population(b));
                    end
                    del_list=[del_list b];
                    
                end
            end
            
            if isempty(del_list)==false
                %                 disp(sprintf('Rule merging: RULE No %d is now merged due to redundant', del_list));
                population(del_list)=[];
                wtttt(del_list,:)=[];
                if objective=='G'
                    for i=1:length(del_list)
                        temp_del=[temp_del (((del_list(i)-1)*(n+1)+1)):del_list(i)*(n+1)];
                    end
                    Ck(temp_del,:)=[];
                    Ck(:,temp_del)=[];
                    pik(:,:,del_list)=[];
                    Ck_old=Ck;
                    clear Weight
                    for i=1:R
                        for j=1:m
                            Weight((i-1)*(n+1)+1:i*(n+1),j) = pik(:,j,i);
                        end
                    end
                    Weight_old=Weight;
                    [u2,v2]=size(wtttt);
                    rule(k)=u2;
                    R=u2;
                elseif objective=='L'
                    cik(:,:,del_list)=[];
                    pik(:,:,del_list)=[];
                    clear Weight
                    [u2,v2]=size(wtttt);
                    rule(k)=u2;
                    R=u2;
                    for i=1:R
                        for j=1:m
                            Weight((i-1)*(n+1)+1:i*(n+1),j) = pik(:,j,i);
                        end
                    end
                    Weight_old=Weight;
                    cik_old=cik;
                end
                pik_old=pik;
                clear Psik
            end
        end
        %%%================================================================
        %%%%   End of Rule Merging
        %%%================================================================
        %%%===Start===FWGRLS====================================
                sum_tau = 0;
                tau = 0;
                mu=zeros(R,1);
                disperrule=zeros(R,1);
                for i=1:R
                    for j=1:m
                        wtt(n+m,:)=Weight((i-1)*(n+1)+1:i*(n+1),j)';
                        wtttt(i,:)=wtt(n+m,:);
                        wxb(i,j)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),j);
                        hp(i,1)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),1);
                        if wxb(i,j)>0
                            mu(i,j)=eta*wxb(i,j);
                        else
                            mu(i,j)=1*10^-19*wxb(i,j);
                        end
                    end
                    tau(i) = prod(mu(i,:));    % firing strength of rule i
                    sum_tau = sum_tau + tau(i); % sum of the firing strength of the rules
                end
        
                lambda=tau/sum_tau;
                %%% ======End of Hyper_Plane_loop_2=======
        
                if objective=='G'        % Globally optimal estimation, RLS
                    for i=1:R,      Psik((i-1)*(n+1)+1:i*(n+1),1) = lambda(i)*xek;    end
        
                    K=Ck_old*Psik/(1.0+Psik'*Ck_old*Psik);
                    Ck = (Ck_old - (K*Psik'*Ck_old));
                    gradient=Weight_old;
        
                    Weight = Weight_old -(10^(-15)*Ck*gradient) + Ck*Psik*(stream(n+1:nm) - Psik'*Weight_old);
        
                elseif objective=='L'    % Locally optimal estimation, wRLS
                    for i=1:R
                        K=cik_old(:,:,i)*xek/(lambda(i)+xek'*cik_old(:,:,i)*xek);
                        cik(:,:,i) =(cik_old(:,:,i) - (K*xek'*cik_old(:,:,i)));
                    end
                    for i=1:R
                        for j=1:m
                            pik(:,j,i) = pik_old(:,j,i) -(10^(-7)*cik_old(:,:,i)*pik_old(:,j,i))+ cik(:,:,i)*xek*lambda(i)*(stream(n+j) - xek'*pik_old(:,j,i));
        
                        end
                    end
                    for i=1:R
                        for j=1:m
                            Weight((i-1)*(n+1)+1:i*(n+1),j) = pik(:,j,i);
                        end
                    end
                end
                Weight_old=Weight;
        %%%===End===FWGRLS====================================
        
        %%%===Start===GRLS====================================
%         sum_tau = 0;
%         tau = 0;
%         mu=zeros(R,1);
%         disperrule=zeros(R,1);
%         for i=1:R
%             for j=1:m
%                 wtt(n+m,:)=Weight((i-1)*(n+1)+1:i*(n+1),j)';
%                 wtttt(i,:)=wtt(n+m,:);
%                 wxb(i,j)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),j);
%                 hp(i,1)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),1);
%                 if wxb(i,j)>0
%                     mu(i,j)=wxb(i,j);
%                 else
%                     mu(i,j)=1*10^-5*wxb(i,j);
%                 end
%             end
%             tau(i) = prod(mu(i,:));    % firing strength of rule i
%             sum_tau = sum_tau + tau(i); % sum of the firing strength of the rules
%         end
%         
%         lambda=tau/sum_tau;
%         %%% ======End of Hyper_Plane_loop=======
%         
%         if objective=='G'        % Globally optimal estimation, RLS
%             for i=1:R,      Psik((i-1)*(n+1)+1:i*(n+1),1) = lambda(i)*xek;    end
%             
%             Ck = Ck_old - (Ck_old*Psik*Psik'*Ck_old)/(1+Psik'*Ck_old*Psik);
%             Weight = Weight_old + Ck*Psik*(stream(n+1:nm) - Psik'*Weight_old);
%             
%         elseif objective=='L'    % Locally optimal estimation, wRLS
%             for i=1:R
%                 K=cik_old(:,:,i)*xek/(lambda(i)+xek'*cik_old(:,:,i)*xek);
%                 cik(:,:,i) =(cik_old(:,:,i) - (K*xek'*cik_old(:,:,i)));
%             end
%             for i=1:R
%                 for j=1:m
%                     pik(:,j,i) = pik_old(:,j,i) -(10^(-7)*cik_old(:,:,i)*pik_old(:,j,i))+ cik(:,:,i)*xek*lambda(i)*(stream(n+j) - xek'*pik_old(:,j,i));
%                     
%                 end
%             end
%             for i=1:R
%                 for j=1:m
%                     Weight((i-1)*(n+1)+1:i*(n+1),j) = pik(:,j,i);
%                 end
%             end
%         end
%         Weight_old=Weight;
        %%%===End===GRLS====================================
    end
    time=toc;
    
    
    %%% =========Starting Hyper_plane_loop_final =========
    
    sum_tau = 0;
    tau = 0;
    mu=zeros(R,1);
    disperrule=zeros(R,1);
    for i=1:R
        for j=1:m
            wtt(n+m,:)=Weight((i-1)*(n+1)+1:i*(n+1),j)';
            wtttt(i,:)=wtt(n+m,:);
            wxb(i,j)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),j);
            hp(i,1)=xek'*Weight((i-1)*(n+1)+1:i*(n+1),1);
            if wxb(i,j)>0
                mu(i,j)=eta*wxb(i,j);
            else
                mu(i,j)=1*10^-19*wxb(i,j);
            end
        end
        tau(i) = prod(mu(i,:));    % firing strength of rule i
        sum_tau = sum_tau + tau(i); % sum of the firing strength of the rules
    end
    
    lambda=tau/sum_tau;
    %%% ======End of Hyper_Plane_loop_final=======
    
    
    
    
    
    for i=1:R
        Psik((i-1)*(n+1)+1:i*(n+1),1) = lambda(i)*xek;
    end
    
    Weight=Weight_old;
    
    
    
    y(k+1,:) = Psik'*Weight;
    
%         normalized_out(k+1,:)=y(k+1,:);
    
    normalized_out(k+1,:)=y(k+1,:)/sum(y(k+1,:));
    
    for i=n+1:nm
        error(k,i-n) = y(k,i-n) - stream(:,i);
    end
    
end
%=======================
%   END OF THE MAIN LOOP
%=======================
y= y';

% % Performance measures for the evolution phase (the model EVOLVES)
% MSE_train = (1/fix_the_model)*sum(error(1:fix_the_model,:).^2);
% RMSE_train = sqrt((1/fix_the_model)*sum(error(1:fix_the_model,:).^2));
% NRMSE_train=sqrt(MSE_train/std(dataset(1:fix_the_model,n+1)));
% NDEI_train = RMSE_train/std(dataset(1:fix_the_model,n+1));
% %
% % % Performance measures for the validation phase (the model is FIXED)
% MSE_validation = (1/(N-fix_the_model))*sum(error(fix_the_model+1:N,:).^2);
% RMSE_validation = sqrt((1/(N-fix_the_model))*sum(error(fix_the_model+1:N,:).^2));
% NRMSE_validation=sqrt(MSE_validation/std(dataset(fix_the_model+1:N,n+1)));
% NDEI_validation = RMSE_validation/std(dataset(fix_the_model+1:N,n+1));
%
% disp(sprintf('\nPERFORMANCE MEASURES'));
% disp(sprintf('\n     TRAINING     VALIDATION'));
% for i=1:m
%     disp(sprintf('\n  OUTPUT %d',i));
%     disp(sprintf('\nMSE  %0.5g     %0.5g \nRMSE %0.5g  %0.5g \nNRMSE %0.5g   %0.5g \nNDEI %0.5g      %0.5g', MSE_train(i),MSE_validation(i), RMSE_train(i),  RMSE_validation(i), NRMSE_train(i), NRMSE_validation(i), NDEI_train(i), NDEI_validation(i)));
% end
if m<=1
    temp=zeros(N,1);
    %% training
    count=0;
    for i=1:(fix_the_model)
        if temp(i,:)==dataset(i,end)
            count=count+1;
        end
    end
    classification_rate_training=count/fix_the_model;
    %% testing
    count1=0;
    temp1=zeros(N-fix_the_model,1);
    for i=fix_the_model+1:N
        if temp1(i-fix_the_model,:)==dataset(i,end)
            count1=count1+1;
        end
    end
    classification_rate_testing=count1/(N-fix_the_model);
    disp(sprintf('\nPERFORMANCE MEASURES'));
    disp(sprintf('\n     TRAINING     VALIDATION'));
    disp(sprintf('\nclassification rate(training)  %0.5g     %0.5g \nclassification rate(testing) %0.5g     %0.5g %0.5g      %0.5g', classification_rate_training,classification_rate_testing));
else
    
    
    %% Multi class classification
    output=dataset(:,n+1:end);
    predictclass=zeros(1,N);
    true=zeros(1,N);
    for i=1:N
        [predict_label,predict_label1]=max(normalized_out(i+1,:));
        predictclass(i)=predict_label1;
        [true_val,true_index]=max(output(i,:));
        true(i)=true_index;
    end
    
    %% Training
    count=0;
    for i=1:fix_the_model
        if predictclass(i)==true(i)
            count=count+1;
        end
    end
    classification_rate_training=count/fix_the_model;
    count1=0;
    for i=fix_the_model+1:N
        if predictclass(i)==true(i)
            count1=count1+1;
        end
    end
    classification_rate_testing=count1/(N-fix_the_model);
%     disp(sprintf('\nPERFORMANCE MEASURES'));
    %     disp(sprintf('\n     TRAINING     VALIDATION'));
%     disp(sprintf('\nclassification rate(training)  %0.5g     %0.5g classification rate(testing)    %0.5g %0.5g      ', classification_rate_training, classification_rate_testing));
    
    Label_all=true;
    ConMAT_train = confusionmat(Label_all(1,1:fix_the_model),predictclass(1,1:fix_the_model));
    ConMAT_test = confusionmat(Label_all(1,fix_the_model+1:N),predictclass(1,fix_the_model+1:N));
    ConMAT=confusionmat(Label_all,predictclass);
    %     figure(1)
    %     cm_train = confusionchart(Label_all(1,1:fix_the_model),predictclass(1,1:fix_the_model));
    %     figure(2)
    %     cm_test = confusionchart(Label_all(1,fix_the_model+1:N),predictclass(1,fix_the_model+1:N));
end
