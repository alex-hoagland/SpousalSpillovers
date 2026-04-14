/*******************************************************************************
* Title: Identify all mortality (esp for outcome spouses)
* Created by: Alex Hoagland
* Created on: 7/23/2024
* Last modified on: 4/29/2025
* Last modified by: 
* Purpose: 

* NOTES: 
	
*******************************************************************************/


clear
gen year = .
save "${input_datapath}/mortality.dta", replace

// loop through years: start with inpatient claims 
forvalues year = 2010/2017 {
	
	display "***** WORKING ON YEAR `year' *****"
	
	use bene_id *death* using /disk/aging/medicare/data/harm/100pct/bsf/`year'/bsfab`year', clear
	
	append using "${input_datapath}/mortality.dta"
	save "${input_datapath}/mortality.dta", replace	
} 
drop if missing(death_dt) 
duplicates drop 
gcollapse (first) *death*, by(bene_id ) fast

compress
save "${input_datapath}/mortality.dta", replace
********************************************************************************
