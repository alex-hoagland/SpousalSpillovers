use response_id eventdate_index treated using "${input_datapath}/weekpanel.dta" if treated == 1, clear
gcollapse (min) eventdate_index, by(response_id) fast
tempfile tomerge
save `tomerge', replace

use "${input_datapath}/lasso_prob_snf_3folds.dta", clear 
gen response_id = bene_id 
merge m:1 response_id using `tomerge', keep(3) nogenerate 

expand 2, gen(treated)
replace eventdate_index = eventdate_index - 365 if treated == 0
gen reltime_months = floor((admsndt - eventdate_index )/30)
gcollapse (mean) l_pred_prob, by(response_id treated reltime_months) fast
rename l_pred_prob prob_snf 

compress
save "${input_datapath}/tomerge_probsnf.dta", replace
