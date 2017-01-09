*-----------Import data from file, define labels--------------;
data donations_original; 
infile 'Data_Train_Blood_Donations.csv' DELIMITER = ',' MISSOVER FIRSTOBS=2; 
input ID Last_Donation Donations Vol_Donated First_Donation March_Donation; 
LABEL ID='ID' Last_Donation='Months since Last Donation' Donations='Number of Donations' Vol_Donated='Total Volume Donated (c.c.)' 
First_Donation='Months since First Donation' March_Donation='Made Donation in March 2007';
run;

proc print data= donations_original; 
run;



*-----------Split data into training and testing set--------------;
*Creates a new dataset - adds a column splitting train and test sets;
title "Test and Train Sets for Donations";
proc surveyselect data=donations_original out=donations_xv seed=227
samprate=0.7 outall; *outall - show all the data selected (1) and not selected (0) for training;
run;
proc print data=donations_xv;
run;
* create new variable new_y = March_Donation for training set, and new_y = NA for testing set;
data donations_xv; *create blank dataset;
set donations_xv; *add the xv data do it;
if selected then new_y=March_Donation; *create a field "new_y" where the response variable will only appear if it was selected as part of the training set;
run;
proc print data=donations_xv;
run;



*----------------Data exploration--------------------;
TITLE2 "Histogram - Made Donation in March 2007";
proc univariate normal data=donations_xv; 
var March_Donation; 
histogram / normal(mu=est sigma=est);
run;
*NOTE: Outcome distribution is not even. Try 1)using different cut-off scores for classification or 2)narrowing down the train dataset to make it even;
TITLE2 "Descriptive Statistics";
proc means min max mean std stderr clm p25 p50 p75 data=donations_xv; 
var ID Last_Donation Donations Vol_Donated First_Donation March_Donation; 
run;

* creates scatterplot matrix to look for multicollinearity;
proc sgscatter data=donations_xv;
title2 "Scatterplot Matrix for Donation Data";
matrix Last_Donation Donations Vol_Donated First_Donation;
run;

*Check for multicollinearity between the *variables* (NOTE: In the final model, we will have to check for multicollinearity between the parameter estimates as well);
title2 "Correlatoion Matrix for Donation Data";
proc corr data = donations_xv;
var Last_Donation Donations Vol_Donated First_Donation;
run;



*----------------Data preprocessing--------------------;
*Donations and volume donated are perfectly correlated, since each donation is 250 c.c. We can throw out one of them;
data donations_xv; *create blank dataset;
set donations_xv; *add the xv data do it;
Donation_Period = (First_Donation - Last_Donation);
Avg_Donation = Vol_Donated / (Donation_Period + 1); *we can also derive a new variable, average donations per donation period.
Add 1 so that people who only donated once will have a 1 month donation period and we never have to divide by zero. CAN I DO THIS?????????????????????????????;
LABEL Donation_Period='Months between first and last donation' Avg_Donation='Avg. Vol. Donated (c.c.) per Donation Period';
run;

title2 "Donation Data";
proc print data=donations_xv;
run;



*----------------Data exploration--------------------;
TITLE2 "Descriptive Statistics";
proc means min max mean std stderr clm p25 p50 p75 data=donations_xv; 
var ID Last_Donation Donations Vol_Donated First_Donation Donation_Period Avg_Donation; 
run;

* creates scatterplot matrix to look for multicollinearity;
proc sgscatter data=donations_xv;
title2 "Scatterplot Matrix for Donation Data";
matrix Last_Donation Donations Vol_Donated First_Donation Donation_Period Avg_Donation;
run;

*computes correlation coefficient to look for multicollinearity;
title2 "Correlatoion Matrix for Donation Data";
proc corr data = donations_xv;
var Last_Donation Donations Vol_Donated First_Donation Donation_Period Avg_Donation;
*multicollinearity: Donations with Vol_Donated and First_Donation with Donation_Period;
run;



*----------------Models--------------------;
*Full Model 1;
title2 "Full Model 1";
PROC LOGISTIC data = donations_xv;
model new_y(event='1') = Last_Donation Donations First_Donation / stb;
run;

*Full Model 2;
title2 "Full Model 2";
PROC LOGISTIC data = donations_xv;
model new_y(event='1') = Last_Donation Donations Donation_Period Avg_Donation / stb;
run;

*Stepwise Model;
title2 "Stepwise Selection";
PROC LOGISTIC data = donations_xv;
model new_y(event='1') = Last_Donation Donations Donation_Period Avg_Donation/selection = stepwise sle=.05 sls=.05;
run;
title2 "Stepwise Model";
PROC LOGISTIC data = donations_xv;
model new_y(event='1') = Last_Donation Donations Donation_Period / stb;
run;



*----------------Check Model Assumptions--------------------;
*Check for multicollinearity between *parameter estimates* (NOTE: this changes each time predictors are added or removed from the model);
ods graphics on;
title2 "Stepwise Model";
PROC LOGISTIC data = donations_xv;
model new_y(event='1') = Last_Donation Donations Donation_Period / influence iplots corrb stb; 
*influence-> table of outliers points, ipots-> residual plots to look for outliers , corrb-> correlation between parameter estimates, stb-> standardized estimates;
run;
ods graphics off;



*------------------------Model Validation------------------------;
ODS RTF FILE="C:\Users\rchesak\Desktop\Model_Validation.RTF"; *sends output to a MS Word file;
* compute predicted probability based on model built using the training set and compute the predicted probability for test set;
proc logistic data=donations_xv;
model new_y(event='1') = Last_Donation Donations Donation_Period / ctable pprob= (0.2 to 0.8 by 0.05); *last bit there generates a classification table to find the best probability threshold;
* output results to dataset called pred, predicted value is written to variable --> phat ;
output out=pred(where=(new_y=.)) p=phat lower=lcl upper=ucl
predprob=(individual);
run;
** compute predicted Y in testing set for pred_prob > 0.5;
data probs;
set pred;
pred_y=0;
threshold=0.5; *modify threshold here;
if phat>threshold then pred_y=1;
run;
* compute classification matrix;
proc freq data=probs;
tables March_Donation*pred_y/norow nocol nopercent;
run;
** compute predicted Y in testing set for pred_prob > 0.4;
data probs2;
set pred;
pred_y2=0;
threshold2=0.4; *modify threshold here;
if phat>threshold2 then pred_y2=1;
run;
* compute classification matrix;
proc freq data=probs2;
tables March_Donation*pred_y2/norow nocol nopercent;
run;
ODS RTF CLOSE;

proc print data= pred; 
run;



*-----------Import test data from file, define labels--------------;
data donations_test; 
infile 'Data_Test_Blood_Donations.csv' DELIMITER = ',' MISSOVER FIRSTOBS=2; 
input ID Last_Donation Donations Vol_Donated First_Donation March_Donation; 
Donation_Period = (First_Donation - Last_Donation);
Avg_Donation = Vol_Donated / (Donation_Period + 1); *we can also derive a new variable, average donations per donation period.
Add 1 so that people who only donated once will have a 1 month donation period and we never have to divide by zero. CAN I DO THIS?????????????????????????????;
LABEL ID='ID' Last_Donation='Months since Last Donation' Donations='Number of Donations' Vol_Donated='Total Volume Donated (c.c.)' Donation_Period='Months between first and last donation' 
Avg_Donation='Avg. Vol. Donated (c.c.) per Donation Period' First_Donation='Months since First Donation' March_Donation='Made Donation in March 2007';
run;

proc print data= donations_test; 
run;



*--------------------Predictions Using the Training Set of the Training Set (n = 404) and the Stepwise Model------------;
*join the donations_xv data with the test dataset given by the Driven Data competition; 
data predict; 
set donations_test donations_xv;
proc print data= predict; 
run;

*compute predictions; 
PROC LOGISTIC data = predict;
model new_y(event='1') = Last_Donation Donations Donation_Period / ctable pprob=0.5 selection=stepwise rsquare link=logit expb;
output out=estimates p=est_response;*outputs predictions (est_response) to a dataset called 'estimates';
run;
proc print data= estimates; *NOTE: only the first 200 records here are part of the test dataset given by the Driven Data competition;
run;



*--------------------Predictions Using the ENTIRE Training Set provided by the Driven Data competition (n = 576) and the Stepwise Model------------;
*create the derived variables for the full training set;
data donations_original; *create blank dataset;
set donations_original; *add the original data to it;
Donation_Period = (First_Donation - Last_Donation);
Avg_Donation = Vol_Donated / (Donation_Period + 1); *we can also derive a new variable, average donations per donation period.
Add 1 so that people who only donated once will have a 1 month donation period and we never have to divide by zero. CAN I DO THIS?????????????????????????????;
LABEL Donation_Period='Months between first and last donation' Avg_Donation='Avg. Vol. Donated (c.c.) per Donation Period';
run;

*join the donations_original data with the test dataset given by the Driven Data competition; 
data predict2; 
set donations_test donations_original;
proc print data= predict2; 
run;

*compute predictions; 
PROC LOGISTIC data = predict2;
model March_Donation(event='1') = Last_Donation Donations Donation_Period / ctable pprob=0.5 selection=stepwise rsquare link=logit expb;
output out=estimates2 p=est_response; *outputs predictions (est_response) to a dataset called 'estimates2';
run;
proc print data= estimates2; *NOTE: only the first 200 records here are part of the test dataset given by the Driven Data competition;
run;

