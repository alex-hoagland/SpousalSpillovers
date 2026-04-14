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
use "${input_datapath}/weekpanel.dta" , clear 
	
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

if ("`1'" == "balanced" ) { 
	// keep only households where outcome spouse lives for at least a year post-event
	cap drop bene_id
	gen bene_id = response_id 
	merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop) 
	drop if todrop == 1
	drop test todrop
}

gcollapse (max) snf treated* fatal_*, by(response_id index_id hhid eventid ym tt reltime_months ) fast

// gen test = runiform() 
// bys Shock_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1) 

sum snf if treated == 1 & reltime < 0
replace snf = snf / `r(mean)'

// run regression for 1 year fatal 
reghdfe snf ib3.tt##i.treated if fatal_1year  == 1, ///
	absorb(eventid ym) cluster(hhid)	
regsave using "$hoaglandoutput/fatalshock", replace ci p 
reghdfe snf ib3.tt##i.treated if fatal_1year == 0, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$hoaglandoutput/nonfatalshock",  replace ci p 

preserve
use "$hoaglandoutput/fatalshock", clear
gen model = 1 
append using "$hoaglandoutput/nonfatalshock"
replace model = 0 if missing(model)

// make figure			
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
di `newobs'
set obs `newobs'
replace reltime = -1 if missing(reltime) 
replace model = 1 in `newobs'
replace model = 0 if missing(model) 
foreach v of varlist  coef ci_* {
	replace `v' = 0 if missing(`v')
}
gsort reltime

replace reltime = reltime - 0.15 if model == 0 
replace reltime = reltime + 0.15 if model == 1

// keep if abs(reltime) <= 4
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 0, color(ebblue))  ///
	(scatter coef reltime if model == 1, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	legend(order(2 "Nonfatal Shock" 3 "Fatal Shock") rows(1) ring(0) position(11))
if ("`1'" == "balanced") {
	graph save "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_balanced_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_balanced_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_balanced_$today.pdf", as(pdf) replace
}
else {
graph save "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-1year_$today.pdf", as(pdf) replace
}
restore

/*
// run regression
reghdfe snf ib3.tt##i.treated if fatal_d  == 1, ///
	absorb(eventid ym) cluster(hhid)	
regsave using "$hoaglandoutput/fatalshock", replace ci p 
reghdfe snf ib3.tt##i.treated if fatal_d == 0, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$hoaglandoutput/nonfatalshock",  replace ci p 

preserve
use "$hoaglandoutput/fatalshock", clear
gen model = 1 
append using "$hoaglandoutput/nonfatalshock"
replace model = 0 if missing(model)

// make figure			
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
di `newobs'
set obs `newobs'
replace reltime = -1 if missing(reltime) 
replace model = 1 in `newobs'
replace model = 0 if missing(model) 
foreach v of varlist  coef ci_* {
	replace `v' = 0 if missing(`v')
}
gsort reltime

replace reltime = reltime - 0.15 if model == 0 
replace reltime = reltime + 0.15 if model == 1

// keep if abs(reltime) <= 4
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 0, color(ebblue))  ///
	(scatter coef reltime if model == 1, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	legend(order(2 "Nonfatal Shock" 3 "Fatal Shock") rows(1) ring(0) position(11))
if ("`1'" == "balanced" ) { 
	graph save "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_balanced_$today.gph", replace
	graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_balanced_$today.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_balanced_$today.pdf", as(pdf) replace
}
else {
	graph save "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_$today.gph", replace
	graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_$today.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock_$today.pdf", as(pdf) replace
}
// restore


// // run regression based on 30 day mortality, not discharge mortality
// cap graph drop * 
// reghdfe snf ib3.tt##i.treated if fatal_30  == 1, ///
// 	absorb(eventid ym) cluster(hhid)	
// regsave using "$hoaglandoutput/fatalshock", replace ci p 
// reghdfe snf ib3.tt##i.treated if fatal_30 == 0, ///
// 	absorb(eventid ym) cluster(hhid)
// regsave using "$hoaglandoutput/nonfatalshock",  replace ci p 
//
// preserve
// use "$hoaglandoutput/fatalshock", clear
// gen model = 1 
// append using "$hoaglandoutput/nonfatalshock"
// replace model = 0 if missing(model)
//
// // make figure			
// keep if strpos(var, ".tt#1.treated")
// cap drop if strpos(var, "o.")
// gen reltime = substr(var, 1, 2)
// destring reltime, replace
// replace reltime = reltime - 4
// local newobs = _N + 2
// di `newobs'
// set obs `newobs'
// replace reltime = -1 if missing(reltime) 
// replace model = 1 in `newobs'
// replace model = 0 if missing(model) 
// foreach v of varlist  coef ci_* {
// 	replace `v' = 0 if missing(`v')
// }
// gsort reltime
//
// replace reltime = reltime - 0.15 if model == 0 
// replace reltime = reltime + 0.15 if model == 1
//
// // keep if abs(reltime) <= 4
// twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
// 	(scatter coef reltime if model == 0, color(ebblue))  ///
// 	(scatter coef reltime if model == 1, color(maroon)) , ///
// 	xline(-0.25, lpattern(dash)) ///
// 	yline(0) ///
// 	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
// 	xsc(r(-4(2)12)) xlab(-4(2)12) ///
// 	legend(order(2 "Nonfatal Shock" 3 "Fatal Shock") rows(1) ring(0) position(11))
// graph save "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-30day_$today.gph", replace
// graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-30day_$today.png", as(png) replace
// graph export "${hoaglandoutput}/EventStudy_snf_fatalnonfatalshock-30day_$today.pdf", as(pdf) replace
// restore
********************************************************************************/
