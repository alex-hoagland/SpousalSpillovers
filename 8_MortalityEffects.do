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
// gen todrop = (time_pre <= 365*3)
// bys index_id: ereplace todrop = max(todrop) 
// drop if todrop == 1 
// drop todrop 

use "${input_datapath}/weekpanel.dta" , clear 
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

// generate outcome 
gen mortality = (!missing(death_dt) & workingdate >= death_dt)
gen athomenotdead = (snf == 0 & mortality == 0) 

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 5 is now the base period (-1 + 6 = 5)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points

gcollapse (max) mortality athomenotdead treated* index_fem fatal*, by(index_id hhid eventid ym tt reltime_months ) fast

// run regression
reghdfe mortality ib3.tt##i.treated if fatal_1year == 1, ///
		absorb(eventid ym) cluster(hhid)
regsave using "$hoaglandoutput/mortality_fatalshock", replace ci p 

reghdfe mortality ib3.tt##i.treated if fatal_1year == 0, ///
		absorb(eventid ym) cluster(hhid)
regsave using "$hoaglandoutput/mortality_nonfatalshock", replace ci p 


use "$hoaglandoutput/mortality_fatalshock", clear
gen model = 1 
append using "$hoaglandoutput/mortality_nonfatalshock"
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

graph save "${hoaglandoutput}/EventStudy_mortality_fatalnonfatalshock-1year_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_mortality_fatalnonfatalshock-1year_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_mortality_fatalnonfatalshock-1year_$today.pdf", as(pdf) replace
********************************************************************************
