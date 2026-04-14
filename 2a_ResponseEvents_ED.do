/*******************************************************************************
* Title: Identify all new ED visits
* Created by: Alex Hoagland
* Created on: 7/23/2024
* Last modified on: 11/6/2024
* Last modified by: 
* Purpose: 

* NOTES: 
	
*******************************************************************************/


clear
gen year = .
save "${input_datapath}/EDdx.dta", replace

// loop through years: start with inpatient claims 
forvalues year = 2009/2016 {
	
	display "***** WORKING ON YEAR `year' *****"
	
	use bene_id rev_dt rev_cntr using /disk/aging/medicare/data/harm/20pct/ip/`year'/ipr`year' if inlist(rev_cntr, "0450", "0451", "0452", "0453", "0454", "0455", "0456") | ///
		inlist(rev_cntr, "0457", "0458", "0459", "0981"), clear
	tempfile tomerge_ed
	save `tomerge_ed', replace
	
	use bene_id rev_dt rev_cntr using /disk/aging/medicare/data/harm/20pct/op/`year'/opr`year' if inlist(rev_cntr, "0450", "0451", "0452", "0453", "0454", "0455", "0456") | ///
		inlist(rev_cntr, "0457", "0458", "0459", "0981"), clear
	append using `tomerge_ed'
	gen test = 1 
	gcollapse (max) test, by(bene_id rev_dt) fast
	drop test
	
	append using "${input_datapath}/EDdx.dta"
	save "${input_datapath}/EDdx.dta", replace	
} 

display "***** WORKING ON YEAR 2017 *****"
	
use bene_id thru_dt rev_cntr using /disk/aging/medicare/data/harm/20pct/ip/2017/ipr2017 if inlist(rev_cntr, "0450", "0451", "0452", "0453", "0454", "0455", "0456") | ///
	inlist(rev_cntr, "0457", "0458", "0459", "0981"), clear
rename thru_dt rev_dt
tempfile tomerge_ed
save `tomerge_ed', replace

use bene_id rev_dt rev_cntr using /disk/aging/medicare/data/harm/20pct/op/2017/opr2017 if inlist(rev_cntr, "0450", "0451", "0452", "0453", "0454", "0455", "0456") | ///
	inlist(rev_cntr, "0457", "0458", "0459", "0981"), clear
append using `tomerge_ed'
gen test = 1 
gcollapse (max) test, by(bene_id rev_dt) fast
drop test

append using "${input_datapath}/EDdx.dta"
compress
save "${input_datapath}/EDdx.dta", replace
********************************************************************************
