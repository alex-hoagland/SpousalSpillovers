/*******************************************************************************
* Title: Main event study sensitivity analysis 
* Created by: Alex Hoagland
* Created on: 2/28/2026
* Last modified on: 
* Last modified by: 

* NOTES: 
	- looks at model sensitivity to dropping extra periods and including/not including individual FE
*******************************************************************************/

	
***** Main Regression 
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

// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
gen extra = (reltime_months == -5)
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

gcollapse (max) snf treated* index_fem extra, by(index_id response_id hhid eventid ym tt reltime_months ) fast

// rescale only for non-decomposed results
sum snf if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean: di %7.6fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
gen snf2 = snf / `premean' // rescale coefficients to be % of outcome

// rescale only for non-decomposed results
sum snf if (treated == 1 & reltime_ < 0 & extra == 0) // | treated == 0 
local premean: di %7.6fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
gen snf3 = snf / `premean' // rescale coefficients to be % of outcome

// run regressions
reghdfe snf2 ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)		
regsave using "$input_datapath/validatemodel_1.dta", ci p replace

reghdfe snf2 ib3.tt##i.treated, ///
	absorb(ym) cluster(hhid)		
regsave using "$input_datapath/validatemodel_2.dta", ci p replace

drop if extra == 1
reghdfe snf3 ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)		
regsave using "$input_datapath/validatemodel_3.dta", ci p replace

reghdfe snf3 ib3.tt##i.treated, ///
	absorb(ym) cluster(hhid)		
regsave using "$input_datapath/validatemodel_4.dta", ci p replace
********************************************************************************


use "$input_datapath/validatemodel_1", clear
gen model = 1 
forvalues i = 2/4 { 
	append using "$input_datapath/validatemodel_`i'"
	replace model = `i' if missing(model)
}
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 4
di `newobs'
set obs `newobs'
foreach v of varlist reltime coef ci_* {
	replace `v' = 0 if missing(`v') 
}

gsort model reltime
replace reltime = reltime - .25 if model == 1
replace reltime = reltime - 0.25/2 if model == 2
replace reltime = reltime + .25 if model == 3
replace reltime = reltime + 0.25/2 if model == 4

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue))  ///
	(scatter coef reltime if model == 2, color(ebblue%50))  ///
	(scatter coef reltime if model == 3, color(maroon)) ///
	(scatter coef reltime if model == 4, color(maroon%50)) , ///
	xline(-0.25, lpattern(dash)) legend(order(2 "Baseline" 3 "No Individual FE" 4 "No Extra Baseline Period" 5 "Neither") rows(2)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean", ///
		position(11) justification(left) size(medsmall)) 
