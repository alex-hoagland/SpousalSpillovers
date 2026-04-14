/*******************************************************************************
* Title: Make figures
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/4
* Last modified by: 
* Purpose: This file makes figures -- can be edited to impose restrictions

* NOTES: 
	- now needs to be run through the mastre file to accommodate multiple outcomes
	- pooled across spouses
*******************************************************************************/

	
***** Main Regression 
cap graph drop * 
	use "${input_datapath}/weekpanel.dta" , clear 
	
// keep only households where outcome spouse lives for at least a year post-event
cap drop bene_id
gen bene_id = response_id 
merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
	
// aggregate to monthly level 
gen reltime_months = floor(reltime_weeks/4)
gen workingdate = eventdate_index + 30*reltime_months
gen wknum = month(workingdate)
cap drop year 
gen year = year(workingdate)
replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

// for circularity Appendix figure, just keep one direction of events 
keep if index_fem == 0 // | ext_ == 1

gcollapse (max) heart_stroke2 treated*, by(index_id response_id hhid eventid ym tt reltime_months ) fast
sum heart_stroke2 if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace heart_stroke2 = heart_stroke2 / `premean' // rescale coefficients to be % of outcome

// robustness option 
gen test = runiform() 
bys index_id: ereplace test = mean(test) 
keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression
qui reghdfe heart_stroke2 ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure			
regsave , ci p 
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

// keep if abs(reltime) <= 4
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/EventStudy_heart_stroke2_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_heart_stroke2_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_heart_stroke2_$today.pdf", as(pdf) replace
********************************************************************************
