/*******************************************************************************
* Title: Recreate figure 1 with SNF entry and exit 
* Created by: Alex Hoagland
* Created on: 9/21/2023
* Last modified on: 1/23/2025
* Last modified by: 
* Purpose: This file pulls all response claims and runs event study 


* NOTES: 
	
*******************************************************************************/


***** 1. Prep new outcome variables 
use "${input_datapath}/weekpanel.dta", clear
cap drop snf_entry 
cap drop snf_exit
keep response_id eventdate_index eventid treated
duplicates drop 
tempfile tomerge
save `tomerge', replace 

use "${input_datapath}/responseevents-MEDPAR.dta" if snf == 1, clear
expand 2, gen(treated)
rename bene_id response_id 
merge m:1 response_id treated using `tomerge', keep(3) nogenerate
keep if abs(response_eventdt - eventdate_index) <= 400 // don't need others 

// now indicators for entry and exit
expand 2, gen(entry) 
gen snf_entry = 1 if entry == 1
gen snf_exit = 1 if entry == 0 
gen elapse = response_eventdt - eventdate_index
gen reltime_weeks = floor(elapse/7) if entry == 1
replace elapse = response_ds - eventdate_index
replace reltime_weeks = floor(elapse/7) if entry == 0
gcollapse (max) snf_entry snf_exit, by(response_id eventdate_index eventid treated reltime_weeks) fast
drop if missing(snf_entry) & missing(snf_exit) // sense check 
merge 1:1 response_id eventdate_index eventid treated reltime_weeks using ///
	"${input_datapath}/weekpanel.dta", keep(2 3) nogenerate
replace snf_entry = 0 if missing(snf_entry)
replace snf_exit = 0 if missing(snf_exit)
********************************************************************************


***** 2. Main Regression 
if ("`2'" == "balanced") {
	// keep only households where outcome spouse lives for at least a year post-event
	cap drop bene_id
	gen bene_id = response_id 
	merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
}

// aggregate to monthly level 
gen reltime_months = floor(reltime_weeks/4)
gen workingdate = eventdate_index + 30*reltime_months
gen wknum = month(workingdate)
cap drop year 
gen year = year(workingdate)
replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)
gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 5 is now the base period (-1 + 6 = 5)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points

if ("`2'" == "balanced") {
	// keep only households where outcome spouse lives for at least a year post-event
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop) 
	drop if todrop == 1
	drop test todrop
}

// // stratify by group: (1) fatal shock, and (2) nonfatal to snf/rehab, and (3) nonfatal to home
// // keep only some nonfatal discharges
// gen group = (fatal_30days == 1)
// replace group = 2 if nonfatal_tosnf == 1 | nonfatal_torehab == 1 
// replace group = 3 if nonfatal_tohome == 1 
// drop if group == 0 
//
// // also drop response_ids if they were hospitalized in the 12 weeks prior to event 
// gen todrop = (hospitalization == 1 & inrange(reltime_weeks, -12, -1))
// bys response_id eventid: ereplace todrop = max(todrop)
// drop if todrop == 1 & group != 1
// drop todrop 

gcollapse (max) snf_entry snf_exit treated* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast

sum snf_entry if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean_entry: di %5.4fc `r(mean)'
local textmean_entry: di %3.1fc `r(mean)' * 1000
replace snf_entry = snf_entry / `premean_entry' // rescale coefficients to be % of outcome

sum snf_exit if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean_exit: di %5.4fc `r(mean)'
local textmean_exit: di %3.1fc `r(mean)' * 1000
replace snf_exit = snf_exit / `premean_exit' // rescale coefficients to be % of outcome

// robustness option
// gen test = runiform() 
// bys index_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression (full sample) 
foreach v of varlist snf_exit snf_entry {  // 
	di "**** Working on variable `v' ******"
	qui reghdfe `v' ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)

	// make figure			
	regsave using "$hoaglandoutput/regdata_`v'", ci p replace
} 

// first, for entry 
use "$hoaglandoutput/regdata_snf_entry.dta", clear

keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 1
di `newobs'
set obs `newobs'
replace reltime = -1 in `newobs'
foreach v of varlist coef ci_* {
	replace `v' = 0 in `newobs'
}
gsort reltime

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/EventStudy_snf_entry_$today_`2'.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf_entry_$today_`2'.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf_entry_$today_`2'.pdf", as(pdf) replace
********************************************************************************

