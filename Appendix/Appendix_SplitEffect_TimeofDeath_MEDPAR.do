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
use "${input_datapath}/weekpanel.dta" if fatal_2year == 1, clear 
gen reldeath = index_deathdate - eventdate_index if treated == 1 
bys index_id : ereplace reldeath = min(reldeath)
keep if inrange(reldeath, 0, 364)
replace reldeath = floor(reldeath/30) // most is in time 0 
drop if reldeath == 12

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

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 5 is now the base period (-1 + 6 = 5)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points

// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

gcollapse (max) snf treated* reldeath, by(index_id hhid eventid ym tt reltime_months ) fast

// gen test = runiform() 
// bys index_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1) 

// sum snf if treated == 1 & reltime < 0
// replace snf = snf / `r(mean)'

// run regression
forvalues d = 0/11 { 
	di in red "***** WORKING ON DEATHS IN MONTH `d' ******"
	reghdfe snf ib3.tt##i.treated if reldeath == `d', ///
		absorb(eventid ym) cluster(hhid)	
	qui regsave using "$hoaglandoutput/regdata_d_`d'", replace ci p 
}

// quarterly regressions 
qui reghdfe snf ib3.tt##i.treated if inrange(reldeath, 0, 2), ///
		absorb(eventid ym) cluster(hhid)	
qui regsave using "$hoaglandoutput/regdata_q_1", replace ci p 
qui reghdfe snf ib3.tt##i.treated if inrange(reldeath, 3, 5), ///
		absorb(eventid ym) cluster(hhid)	
qui regsave using "$hoaglandoutput/regdata_q_2", replace ci p 
qui reghdfe snf ib3.tt##i.treated if inrange(reldeath, 6, 8), ///
		absorb(eventid ym) cluster(hhid)	
qui regsave using "$hoaglandoutput/regdata_q_3", replace ci p 
qui reghdfe snf ib3.tt##i.treated if inrange(reldeath, 9, 11), ///
		absorb(eventid ym) cluster(hhid)	
qui regsave using "$hoaglandoutput/regdata_q_4", replace ci p 


preserve
use "$hoaglandoutput/regdata_d_0", clear
gen model = 0
forvalues d = 1/11 { 
	append using "$hoaglandoutput/regdata_d_`d'"
	replace model = `d' if missing(model)
}

// make figure			
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 12
di `newobs'
set obs `newobs'
replace reltime = -1 if missing(reltime) 
replace model = mod(_n, 12) if missing(model)

foreach v of varlist  coef ci_* {
	replace `v' = 0 if missing(`v')
}
gsort reltime

replace reltime = reltime - 0.3 if model == 0 
replace reltime = reltime - 0.25 if model == 1
replace reltime = reltime - 0.2 if model == 2 
replace reltime = reltime - 0.15 if model == 3
replace reltime = reltime - 0.1 if model == 4 
replace reltime = reltime - 0.05 if model == 5
replace reltime = reltime + 0.05 if model == 6 
replace reltime = reltime + 0.1 if model == 7
replace reltime = reltime + 0.15 if model == 8
replace reltime = reltime + 0.2 if model == 9 
replace reltime = reltime + 0.25 if model == 10
replace reltime = reltime + 0.3 if model == 11 

// full graph here (ignore legend)
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 0)  ///
	(scatter coef reltime if model == 1)  ///
	(scatter coef reltime if model == 2)  ///
	(scatter coef reltime if model == 3)  ///
	(scatter coef reltime if model == 4)  ///
	(scatter coef reltime if model == 5)  ///
	(scatter coef reltime if model == 6)  ///
	(scatter coef reltime if model == 7)  ///
	(scatter coef reltime if model == 8)  ///
	(scatter coef reltime if model == 9)  ///
	(scatter coef reltime if model == 10)  ///
	(scatter coef reltime if model == 11) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) 
	
// trim what we're reporting for clarity
twoway (rcap ci_lower ci_upper reltime if inlist(model, 0, 3, 6, 9), color(gs10)) ///
	(scatter coef reltime if model == 0, color(ebblue))  ///
	(scatter coef reltime if model == 3, color(purple))  ///
	(scatter coef reltime if model == 6, color(maroon))  ///
	(scatter coef reltime if model == 9, color(midgreen)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	legend(order(2 "Shock Spouse Died in Month 0" 3 "Shock Spouse Died in Month 3" 4 "Shock Spouse Died in Month 6" 5 "Shock Spouse Died in Month 9" ) rows(2) ring(0) position(11))
graph save "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.pdf", as(pdf) replace
restore


preserve
use "$hoaglandoutput/regdata_q_1", clear
gen model = 1
forvalues d = 2/4 { 
	append using "$hoaglandoutput/regdata_q_`d'"
	replace model = `d' if missing(model)
}

// make figure			
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 12
di `newobs'
set obs `newobs'
replace reltime = -1 if missing(reltime) 
replace model = mod(_n, 4) + 1 if missing(model)

foreach v of varlist  coef ci_* {
	replace `v' = 0 if missing(`v')
}
gsort reltime

drop if reltime == 12 

replace reltime = reltime - 0.3 if model == 1
replace reltime = reltime - 0.15 if model == 2
replace reltime = reltime + 0.3 if model == 4
replace reltime = reltime + 0.15 if model == 3

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue) msymbol(circle))  ///
	(scatter coef reltime if model == 2, color(ebblue%50) msymbol(square))  ///
	(scatter coef reltime if model == 3, color(maroon%50) msymbol(triangle))  ///
	(scatter coef reltime if model == 4, color(maroon) msymbol(diamond)) , ///
	xline(-0.25, lpattern(dash)) /// 
	xline(2.5, lpattern(dot)) ///
	xline(5.5, lpattern(dot)) ///
	xline(8.5, lpattern(dot)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(1)11)) xlab(-4(1)11) ///
	legend(order(2 "Shock Spouse Died in Quarter 1" 3 "Shock Spouse Died in Quarter 2" 4 "Shock Spouse Died in Quarter 3" 5 "Shock Spouse Died in Quarter 4" ) rows(2) ring(0) position(11))
graph save "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf_SplitEffect_TimeOfDeath_$today.pdf", as(pdf) replace
restore
********************************************************************************
