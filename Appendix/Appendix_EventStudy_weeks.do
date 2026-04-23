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
use "${input_datapath}/weekpanel.dta", clear

// aggregate to weekly level
gen workingdate = eventdate_index + 7*reltime_weeks
gen wknum = week(workingdate)
cap drop year
gen year = year(workingdate)
replace year = year - 1 if treated == 0
gen ym = yw(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)

// keep only households where outcome spouse lives for at least a year post-event
if ("`2'" == "balanced" ) { 
	drop if nosurvive == 1
}

// want to keep 5 months pre and 12 months post
gen tt = reltime_weeks + 4*4 // note that now the base value is -1 + 16 = 15
keep if inrange(reltime_weeks, -5*4, 12*4)
replace tt = 15 if reltime_weeks < -16 // additional reference points for regression

gcollapse (max) `1' treated* index_fem, by(index_id hhid eventid ym tt reltime_weeks ) fast
sum `1' if (treated == 1 & reltime_ < 0)
local premean: di %7.6fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

// robustness option
// gen test = runiform()
// bys index_id: ereplace test = mean(test)
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression
reghdfe `1' ib15.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure
regsave , ci
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4*4
local newobs = _N + 1
di `newobs'
set obs `newobs'
replace reltime = -1 in `newobs'
foreach v of varlist coef ci_* {
	replace `v' = 0 in `newobs'
}
gsort reltime

twoway (rcap ci_lower ci_upper reltime, color(gs10)) (connect coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-16(4)48)) xlab(-16(4)48) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall))
graph save "${hoaglandoutput}/EventStudy_`1'_weeks_requiresurvival_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_`1'_weeks_requiresurvival_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_`1'_weeks_requiresurvival_$today.pdf", as(pdf) replace
********************************************************************************
