%%This file is Copyright (C) 2018 Megha Gaur.

%%This file is Copyright (C) 2018 Megha Gaur.

clc; clear all;
addpath /Users/meghagupta/sfuvault/Documents/MATLAB/MetricEvaluation/Dataset/BCHydroData/HouseData_15_18/
addpath /Users/meghagupta/sfuvault/Documents/MATLAB/MetricEvaluation/Dataset

%Read data from the file
filename = 'HouseData_3.csv';
data0 = readtable(filename,'Format','%{dd/MM/yy}D %{HH}D %f%f');

%Choose user threshold {1.65,2,2.5}
user_thresh = 1.65;

% Add missing values in the energy consumption column.
[added_data0] = addMissingData(data0);

added_data0.timestamp.Format = 'dd/MM/yy HH';
added_data0.hour.Format = 'dd/MM/yy HH';
myDatetime = added_data0.timestamp + timeofday(added_data0.hour);

data1 = added_data0(1:8760,:);       %Year 1
%data1 = added_data0(8761:17520,:);  %Year 2
%data1 = added_data0(17521:end,:);   %Year 3
%data1 = added_data0(26281:end,:); 

% %%Hourly energy data with temp
temp1 = table2array(data1(:,4));
energy1 = table2array(data1(:,3));
timestamp1 = table2array(data1(:,1));
hour1 = table2array(data1(:,2));


%Compute z-score of yearly data
mean_values = mean(energy1,1);
std_values = std(energy1);
zscore = round(((energy1 - mean_values)./std_values),2); %Subtracting the mean of predicted energy from the anom energy.

%%
%Split yearly data into train & validation sets
[train1,validation1] = split_data(temp1,energy1);


%SORT THE DATA and plot the sorted data
[~,idx_train] = sort(train1(:,1));
sort_train1 = train1(idx_train,:);
[~,idx_valid] = sort(validation1(:,1));
sort_valid1 = validation1(idx_valid,:);

% figure;
% plot(sort_train1(:,1),sort_train1(:,2))
% xlabel('temperature')
% ylabel('energy consumption')
% title('Energy vs Temp Plot (Training Data)')
% figure;
% plot(sort_valid1(:,1),sort_valid1(:,2))
% title('Energy vs Temp Plot (Validation Data)')
 
% figure;
% plot(temp_bin_valid1',energy_bin_valid1,'r*')
% hold on;
% plot(temp_bin_train1',energy_bin_train1,'b*')
% hold on;
% xlabel('Temperature bin')
% ylabel('Energy bins')
% legend('validation','training')

%%Find breakpoint values in the graph by grid search on training data, using validation error we pick the break points
[params0, params1,params2] = gridsearch_params(sort_train1);   %Trainig data to find all the combinations of breakpoints & regression coefficients


%[best_params_train] = test_validation(params0,params1,params2,sort_train1);    %Use the params on the validation set to find the best fit.
[best_params_valid] = test_validation(params0,params1,params2,sort_valid1);    %Use the params on the validation set to find the best breakpoints.


[energy_bin_train1,temp_bin_train1,bin_idx_train1] = plot_hist(sort_train1(:,2),sort_train1(:,1));
%[energy_bin_valid1,temp_bin_valid1,bin_idx_valid1] = plot_hist(sort_valid1(:,2),sort_valid1(:,1));

%%Partition data based on the breakpoint temperature to find training and validation accuracy.
%[partition1_train1,partition2_train1,partition3_train1,coeff_deter_train1] = partition_data(sort_train1(:,1),sort_train1(:,2),best_params_valid);
%[partition1_valid1,partition2_valid1,partition3_valid1,coeff_deter_valid1] = partition_data(sort_valid1(:,1),sort_valid1(:,2),best_params_valid);
[partition1_train1,partition2_train1,partition3_train1,coeff_deter_train1] = partition_data(temp_bin_train1',energy_bin_train1,best_params_valid);
%[partition1_valid1,partition2_valid1,partition3_valid1,coeff_deter_valid1] = partition_data(temp_bin_valid1',energy_bin_valid1,best_params_valid);

%Predict energy using the best found regression coefficients
if length(best_params_valid) < 8
    [pred_energy1] = predict_regression(partition1_train1,best_params_valid(1,2:3)');
    [pred_energy2] = predict_regression(partition2_train1,best_params_valid(1,4:5)');
    
    %%%Find the coefficient of determination
    Rsq_1 = 1-(sum((partition1_train1(:,2)-pred_energy1).^2)/sum((partition1_train1(:,2)-mean(partition1_train1(:,2))).^2));
    Rsq_2 = 1-(sum((partition2_train1(:,2)-pred_energy2).^2)/sum((partition2_train1(:,2)-mean(partition2_train1(:,2))).^2));
   
    [label1] = getScore(partition1_train1(:,2),pred_energy1,user_thresh);
    [label2] = getScore(partition2_train1(:,2),pred_energy2,user_thresh);
    
    temp_part = [partition1_train1(:,1) ; partition2_train1(:,1)];
    y_pred = [pred_energy1 ; pred_energy2];
    label = [label1 ; label2];
    idx_part1 = size(partition1_train1,1);
    idx_part2 = idx_part1 + size(partition2_train1,1);
    energy_temp_mat = [temp_part y_pred label];
    
    tmp_idx = [idx_train bin_idx_train1 sort_train1(:,2) sort_train1(:,1)];
    index_label = find(label == 1);
    count = 0;
    
    if any(label) == 1
        disp('Anomalous timestamp are :')
        for i = 1:length(index_label)
            if index_label(i,1) < idx_part1
                [anom_data] = find_label_bin(index_label(i,1),tmp_idx,user_thresh,pred_energy1);
                
            else index_label(i,1) < idx_part2
                [anom_data] = find_label_bin(index_label(i,1),tmp_idx,user_thresh,pred_energy2);
                
            end
        end
        for j = 1:size(anom_data)
            count = count+1;
            anom_timestamp(count,1:2) = data1(anom_data(j,1),1:2);
        end      
        disp(anom_timestamp)
        timestamp_anom = table2array(anom_timestamp(:,1));
        anom_hour = table2array(anom_timestamp(:,2));
        ground_truth = zeros(length(timestamp1),1);
    
        for k = 1:length(timestamp_anom)
            date_idx = find(ismember(timestamp1,timestamp_anom(k)));
            hour_idx = find(hour1(date_idx) == anom_hour(k));
            anom_rows(k) = date_idx(hour_idx);
            ground_truth(anom_rows(k)) = 1;
            
        end
    else
        disp('NO ANOMALY')  
    end
    
    %%Plotting the annotated ground truth
    anom_temp = temp1(ground_truth == 1);
    anom_energy = energy1(ground_truth == 1);
    plot_data_part2([partition1_train1(:,1:2) pred_energy1],[partition2_train1(:,1:2) pred_energy2],anom_temp,anom_energy);

else
    [pred_energy1] = predict_regression(partition1_train1,best_params_valid(1,3:4)');
    [pred_energy2] = predict_regression(partition2_train1,best_params_valid(1,5:6)');
    [pred_energy3] = predict_regression(partition3_train1,best_params_valid(1,7:8)');
    
    %%%Find the coefficient of determination
    Rsq_1 = 1-(sum((partition1_train1(:,2)-pred_energy1).^2)/sum((partition1_train1(:,2)-mean(partition1_train1(:,2))).^2));
    Rsq_2 = 1-(sum((partition2_train1(:,2)-pred_energy2).^2)/sum((partition2_train1(:,2)-mean(partition2_train1(:,2))).^2));
    Rsq_3 = 1-(sum((partition3_train1(:,2)-pred_energy3).^2)/sum((partition3_train1(:,2)-mean(partition3_train1(:,2))).^2));
   
    [label1] = getScore(partition1_train1(:,2),pred_energy1,user_thresh);
    [label2] = getScore(partition2_train1(:,2),pred_energy2,user_thresh);
    [label3] = getScore(partition3_train1(:,2),pred_energy3,user_thresh);
    
    temp_part = [partition1_train1(:,1) ; partition2_train1(:,1) ; partition3_train1(:,1)];
    y_pred = [pred_energy1 ; pred_energy2; pred_energy3];
    label = [label1 ; label2 ; label3];
    idx_part1 = size(partition1_train1,1);
    idx_part2 = idx_part1 + size(partition2_train1,1);
    idx_part3 = idx_part1 + idx_part2;
    energy_temp_mat = [temp_part y_pred label];
    
    tmp_idx = [idx_train bin_idx_train1 sort_train1(:,2) sort_train1(:,1)];
    index_label = find(label == 1);
    count = 0;
    
    if any(label) == 1
        disp('Anomalous timestamp are :')
        for i = 1:length(index_label)
            if index_label(i,1) < idx_part1
                [anom_data] = find_label_bin(index_label(i,1),tmp_idx,user_thresh,pred_energy1);
                
            elseif index_label(i,1) < idx_part2
                [anom_data] = find_label_bin(index_label(i,1),tmp_idx,user_thresh,pred_energy2);
                
            else
                [anom_data] = find_label_bin(index_label(i,1),tmp_idx,user_thresh,pred_energy3);
                
            end
        end
        for j = 1:size(anom_data)
            count = count+1;
            anom_timestamp(count,1:2) = data1(anom_data(j,1),1:2);
        end        
    
        disp(anom_timestamp)
        timestamp_anom = table2array(anom_timestamp(:,1));
        anom_hour = table2array(anom_timestamp(:,2));
        ground_truth = zeros(length(timestamp1),1);
    
        for k = 1:length(timestamp_anom)
            date_idx = find(ismember(timestamp1,timestamp_anom(k)));
            hour_idx = find(hour1(date_idx) == anom_hour(k));
            anom_rows(k) = date_idx(hour_idx);
            ground_truth(anom_rows(k)) = 1;
            
        end
    else
        disp('NO ANOMALY')  
    end
    
    %%Plotting the annotated ground truth
    anom_temp = temp1(ground_truth == 1);
    anom_energy = energy1(ground_truth == 1);
    plot_data([partition1_train1(:,1:2) pred_energy1],[partition2_train1(:,1:2) pred_energy2],[partition3_train1(:,1:2) pred_energy3],anom_temp,anom_energy);
end





%%PLOT ORIGINAL DATA
% figure;
% n = size(energy1,1);
% time = linspace(1,12,n);
% plot(time,energy1);
% set(gca, 'xtick', 1:12);
% set(gca,'xticklabel', {'Feb', 'Mar' , 'Apr', 'May','Jun', 'Jul','Aug', 'Sep', 'Oct','Nov','Dec','Jan' });
