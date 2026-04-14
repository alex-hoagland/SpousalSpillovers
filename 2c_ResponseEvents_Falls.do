/*******************************************************************************
* Title: Response events (falls) 
* Created by: Alex Hoagland
* Created on: 9/21/2023
* Last modified on: 2/7/2024
* Last modified by: 
* Purpose: This file pulls all response claims associated with falls (E code only)


* NOTES: 
	- we are ignoring nuance in classifying falls: see Hoffman et al. Med Care 2016 
*******************************************************************************/


***** 1. Organize response events***********************************************
clear

gen year = .
save "${input_datapath}/responseevents-falls.dta", replace

forvalues year = 2008/2017 {

	display "***** WORKING ON YEAR `year' *****"
	// quietly {
	use bene_id from_dt icd_dgns* using /disk/aging/medicare/data/harm/100pct/ip/`year'/ipc`year', clear
	
	gen tokeep = 0 
	foreach v of varlist icd_dgns_cd* {
		replace tokeep = 1 if inlist(substr(`v', 1, 4), "E880", "E881", "E882", "E884", "E885", "E888")
	}
	keep if tokeep == 1
			
	rename from_dt response_eventdt
	gen fall = 1 
	
	gcollapse (max) fall, by(bene_id response_eventdt) fast 
		// just need a dummy for each response event 
	
	append using "${input_datapath}/responseevents-falls.dta"
	save "${input_datapath}/responseevents-falls.dta", replace
	// }
} 

gen wknum = month(response_eventdt)
cap drop year 
gen year = year(response_eventdt)
expand 2, gen(treated)
replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gcollapse (max) fall, by(bene_id treated ym) fast
compress
save "${input_datapath}/responseevents-falls.dta", replace
*******************************************************
