/*******************************************************************************
We run LASSO prediction model to get the probability of discharge to SNF.
We also create a distribution of the predicted NSF discharge dividing by actual
SNF discharge.
*******************************************************************************/

set seed 12345 // not sure why we have a new seed here, but leaving it for replication

***** 1. Run regression using all years 
use bene_id admsndt sex age* race* sslssnf ds* drg_cd ///
	using /disk/aging/medicare/data/harm/100pct/med/2010/med2010 ///
	, clear

gen file_year = 2010
merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfab/2010/bsfab2010.dta, keep(3) keepusing(covstart hmoin* buyin*)

 cap gen entry_month = month(admsndt)

 tostring entry_month, replace

 foreach month in 1 2 3 4 5 6 7 8 9 {
        replace entry_month = "0" + "`month'" if entry_month == "`month'"
 }

local months 01 02 03 04 05 06 07 08 09 10 11 12 
gen is_ffs = 0
gen is_dual = 0
gen is_hmo = 0
foreach month of local months {
	replace is_ffs = !inlist(buyin`month', "0", "1", "2", "A", "B") & inlist(hmoind`month', "0", "4") if entry_month == "`month'"
	replace is_hmo = inlist(hmoind`month', "1", "2", "A", "B", "C") if entry_month == "`month'"
	replace is_dual = inlist(buyin`month', "A", "B", "C") if entry_month == "`month'"
}


tempfile inprogress_fullsample
save `inprogress_fullsample', replace

forvalues year = 2011/2016 {
	display "***** WORKING ON YEAR `year' *****"
	use bene_id sex age* race* sslssnf admsndt ds* drg_cd using ///
		/disk/aging/medicare/data/harm/100pct/med/`year'/med`year' ///
		, clear // medpar 
		
		gen file_year = `year'
	
	merge m:1 bene_id file_year using /disk/aging/medicare/data/harm/100pct/bsfab/`year'/bsfab`year'.dta, keep(3) keepusing(covstart hmoin* buyin*)

	cap gen entry_month = month(admsndt)

	tostring entry_month, replace

	foreach month in 1 2 3 4 5 6 7 8 9 {
		replace entry_month = "0" + "`month'" if entry_month == "`month'"
	}

	local months 01 02 03 04 05 06 07 08 09 10 11 12 
	gen is_ffs = 0
	gen is_dual = 0
	gen is_hmo = 0
	
	foreach month of local months {
		replace is_ffs = !inlist(buyin`month', "0", "1", "2", "A", "B") & inlist(hmoind`month', "0", "4") if entry_month == "`month'"
		replace is_hmo = inlist(hmoind`month', "1", "2", "A", "B", "C") if entry_month == "`month'"
		replace is_dual = inlist(buyin`month', "A", "B", "C") if entry_month == "`month'"
	
	}
		append using `inprogress_fullsample'
		save `inprogress_fullsample', replace
} 

// for 2017 

display "***** WORKING ON YEAR 2017 *****"
	use bene_id sex age* race* sslssnf admsndt ds* drg_cd using ///
		/disk/aging/medicare/data/harm/100pct/med/2017/med2017 ///
		, clear // medpar 
		
		gen g_fileyear = 2017
		
	

	merge m:1 bene_id g_fileyear using /disk/aging/medicare/data/harm/100pct/bsfab/2017/bsfab2017.dta, keep(3) keepusing(covstart hmoin* buyin*)
	
	rename g_fileyear file_year

	cap gen entry_month = month(admsndt)

	tostring entry_month, replace

	foreach month in 1 2 3 4 5 6 7 8 9 {
		replace entry_month = "0" + "`month'" if entry_month == "`month'"
	}

	local months 01 02 03 04 05 06 07 08 09 10 11 12 
	gen is_ffs = 0
	gen is_dual = 0
	gen is_hmo = 0
	
	foreach month of local months {
		replace is_ffs = !inlist(buyin`month', "0", "1", "2", "A", "B") & inlist(hmoind`month', "0", "4") if entry_month == "`month'"
		replace is_hmo = inlist(hmoind`month', "1", "2", "A", "B", "C") if entry_month == "`month'"
		replace is_dual = inlist(buyin`month', "A", "B", "C") if entry_month == "`month'"
	
	}
		append using `inprogress_fullsample'
		save `inprogress_fullsample', replace


drop sslssnf 

// generate needed variables 
gen fem = (sex == "1")
drop if age < 65 // only want elderly population
levelsof race, local(allrace) 
foreach r of local allrace { 
	gen dummy_`r' = (race == "`r'")
}
drop dummy_1 // reference group
egen drg_id = group(drg_cd)

gen outcome = (dstntncd == "03") // discharge to SNF (21% incidence)

// regression 
destring drg_cd, replace

compress
save "${input_datapath}/pre_lasso_predict_data_full_sample.dta", replace

*/
*/

clear
set maxvar 50000
use "${input_datapath}/pre_lasso_predict_data_full_sample.dta", clear

cap drop fem buyin* hmoin* 
cap gen fem = (sex == "2")
destring sex race file_year entry_month drg_cd, replace

sample 1


lasso linear outcome age_cnt i.sex i.race i.file_year i.entry_month i.drg_cd is_* , selection(bic) // selection(cv, folds(5) serule) grid(25)
lasso logit outcome age_cnt i.sex i.race i.file_year i.entry_month i.drg_cd is_* , selection(cv, folds(5) serule) grid(25)

estimates save "${input_datapath}/lasso_pred_SNFDischarge_3folds_full", replace
predict l_pred_prob, pr

save "${input_datapath}/lasso_prob_snf_3folds.dta", replace

twoway (hist l_pred_prob if outcome == 0, lcolor(red) fcolor(red%10)) ///
	(hist l_pred_prob if outcome == 1, lcolor(ebblue) fcolor(ebblue%10)), ///
	xtitle("Predicted Probability of SNF Discharge") ytitle("") ///
	legend(order(1 "Not discharged to SNF" 2 "Discharged to SNF") ring(0) position(11))
graph export "$hoaglandoutput/Predicted_ProbSNF_Histogram_$today.png", as(png) replace
graph export "$hoaglandoutput/Predicted_ProbSNF_Histogram_$today.pdf", as(pdf) replace

*log close

********************************************************************************
