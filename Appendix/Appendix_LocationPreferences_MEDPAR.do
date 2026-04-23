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

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference point(s)


// keep only households where outcome spouse lives for at least a year post-event
drop if nosurvive == 1

// define outcomes 
replace samesnf = (snf == 1 & samesnf == 1) // doesn't change anything
gen notsamesnf = (snf == 1 & samesnf == 0 & !missing(index_orgnpinm))
gen notinsnf = (snf == 1 & missing(index_orgnpinm)) 

gcollapse (max) snf samesnf notsamesnf notinsnf ///
	treated* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast
replace samesnf = 0 if samesnf == 1 & (notsamesnf == 1 | notinsnf == 1 ) // this deals with double counting since the others are mutually exclusive 

// sum snf if (treated == 1 & reltime_ < 0) // | treated == 0 
// local premean: di %5.4fc `r(mean)'
// local textmean: di %3.1fc `r(mean)' * 1000
// replace samesnf = samesnf / `premean' // rescale coefficients to be % of outcome
// replace notsamesnf = notsamesnf / `premean' // rescale coefficients to be % of outcome

gen test = runiform() 
bys index_id: ereplace test = mean(test) 
keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression
reghdfe samesnf ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure			
regsave using "$input_datapath/regdata_samesnf", ci p replace

// run regression
reghdfe notsamesnf ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure			
regsave using "$input_datapath/regdata_notsamesnf", ci p replace

// run regression
reghdfe notinsnf ib3.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure			
regsave using "$input_datapath/regdata_notinsnf", ci p replace


use "$input_datapath/regdata_notsamesnf", clear
gen model = 2
append using "$input_datapath/regdata_samesnf"
replace model = 1 if missing(model)
append using "$input_datapath/regdata_notinsnf"
replace model = 0 if missing(model)
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 3
di `newobs'
set obs `newobs'
replace reltime = -1 if missing(reltime) 
foreach v of varlist coef ci_* {
	replace `v' = 0 if reltime == -1 
}
replace model = mod(_n, 3) if missing(model)
gsort reltime

replace reltime = reltime - 0.15 if model == 0
replace reltime = reltime + 0.15 if model == 2

// keep if abs(reltime) <= 4
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 0, color(ebblue))  ///
	(scatter coef reltime if model == 1, color(orange))  ///
	(scatter coef reltime if model == 2, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	subtitle("Outcome Spouse's Use of SNF, Given Shock Spouse's Status", position(11) justification(left) size(medsmall)) ///
	legend(order(2 "Shock Spouse is Not in SNF" ///
		     3 "Both Spouses are in the Same SNF" ///
		     4 "Spouses are in Different SNFs") ///
		rows(3) position(11) ring(0)) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ysc(r(-0.004(0.001)0.004)) ylab(-0.004(0.001)0.004)
graph save "${hoaglandoutput}/EventStudy_samesnf_balanced_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_samesnf_balanced_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_samesnf_balanced_$today.pdf", as(pdf) replace
********************************************************************************
