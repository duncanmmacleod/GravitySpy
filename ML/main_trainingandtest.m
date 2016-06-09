%% Initializations and Training Data

%one batch of data is read
%Confusion matrices are loaded

%enter t, the threshold vector
t = 0.4*ones(C,1);

%enter T_alpha, the alpha threshold

%enter R, the citizen limit
R_lim = 30;


%Calculate the Priors
priors = calc_priors(true_labels)'; %The prior probability of each image is calculated.

N = size(images, 1);       %N is the no of images in the batch


%% The main loop that goes through the batch of images one by one

for i = 1:N  %for each image
  
    if images(i).type == 'G'       %if it is a training image
        
        labels = images(i).labels;     %the citizen labels of that image are taken
        
        IDs = images(i).IDs;          %The IDs of the citizens that labeled that image are taken
        
        tlabel = images(i).truelabel;   %the true label is taken
        
        for ii = 1:length(IDs)  %for each citizen
        
            conf_matrix = conf_matrices{IDs(ii)}; %their conf matrix is taken
            
            conf_matrix(tlabel, labels(ii)) = conf_matrix(tlabel, labels(ii)) + 1;  %Conf matrix updated
            
            conf_matrices{IDs(ii)} = conf_matrix;  %Conf matrix put back into the stack
        end
        
        decision(i) = 0;  %Since it is a training image, there is no decision
        class(i) = tlabel;   %The class the image belongs to is its true label. This won't be used anywhere.
        
        disp('image is from the training set')
        
    else
        
        labels = images(i).labels;     %the labels of that image are taken
        
        no_annotators = length(labels);   %number of citizens that labeled that image is calculated
        
        IDs = images(i).IDs;               %The IDs of the citizens that labeled that image are taken
        
        ML_dec = images(i).ML_posterior;     %The ML posteriors for that image are taken.
        
        for j = 1:C       %for each class
            for k = 1:no_annotators   
            
                conf = conf_matrices{IDs(k)};      %the conference matrix of the citizen is taken
            
                conf_divided = diag(sum(conf,2))\conf;     %The p(l|j) value is calculated
            
                pp_matrix(j,k) = (conf_divided(j,labels(k))*priors(j))/sum(conf_divided(:,labels(k)).*priors);   %Posterior is calculated
            
            end
        end
    
        pp_matrices_rack(:,:,i) = pp_matrix;
    
        [decision(i), class(i)] = decider(pp_matrix, ML_dec, t, R_lim, no_annotators);     %A decision for the image is given. 1 is retire, 2 is upper class, 3 is next batch
        
    end
     
end    
       
%At this point, the decisions for each image in the batch are given. For
%training images in the set, the decision is 0. For the test images, the
%test images are 1,2,3.

%The posterior probability matrices are kept for all the test images. If
%the decision is 2 or 3, the probabilities in this matrix will be used.
%(needs more work)

%Also, the confusion matrices are updated for the training images. 

%Next step is updating the confusion matrices for the test images and
%citizen evaluation/promotion.


%% Updating the Confusion Matrices for Test Data and Promotion

for i = 1:N %for each image
    
    if decision(i) == 1 %if it is retired
        
        labels = images(i).labels;  %The citizen labels of the image are taken
        
        IDs = images(i).IDs;            %The IDs of the citizens that labeled that image are taken
        
        for ii = 1:length(IDs)  %for each citizen
        
            conf_matrix = conf_matrices{IDs(ii)}; %their conf matrix is taken
            
            conf_matrix(class(i), labels(ii)) = conf_matrix(class(i), labels(ii)) + 1;  %Conf matrix updated
            
            conf_matrices{IDs(ii)} = conf_matrix;  %Conf matrix put back into the stack
        end
    end
end


for jj = 1:length(conf_matrices)  %for all the citizens
    
    conf_update = conf_matrices{jj};   %their conf. matrices are taken one by one
    
    conf_update_divided = diag(sum(conf_update,2))\conf_update;  
    
    alpha(:,jj) = diag(conf_update_divided);    %alpha parameters are recalculated
    
end


%Thresholding alpha vectors and citizen evaluation (needs work)

    
    


