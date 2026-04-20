/*******************************************************************************
* Title: Run event study split by gender
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
replace tt = 3 if reltime_months <= -5 // additional reference points

gcollapse (max) `1' treated* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast
sum `1' if (treated == 1 & reltime_ < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

gen test = runiform() 
bys index_id: ereplace test = mean(test) 
keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression: males 
reghdfe `1' ib3.tt##i.treated if index_fem == 0, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_males.dta", replace ci p

// run regression: female
reghdfe `1' ib3.tt##i.treated if index_fem == 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_females.dta", replace ci p

// test p-value of difference across index_fem 
reghdfe `1' ib3.tt##i.treated##index_fem, ///
	absorb(eventid ym) cluster(hhid)
test 4bn.tt#1bn.treated#1bn.index_fem 5bn.tt#1bn.treated#1bn.index_fem 6bn.tt#1bn.treated#1bn.index_fem 7bn.tt#1bn.treated#1bn.index_fem 8bn.tt#1bn.treated#1bn.index_fem 9bn.tt#1bn.treated#1bn.index_fem 10bn.tt#1bn.treated#1bn.index_fem 11bn.tt#1bn.treated#1bn.index_fem 12bn.tt#1bn.treated#1bn.index_fem 13bn.tt#1bn.treated#1bn.index_fem 14bn.tt#1bn.treated#1bn.index_fem 15bn.tt#1bn.treated#1bn.index_fem 16bn.tt#1bn.treated#1bn.index_fem
	// gives the joing p-value for differences (p=0.2423 for SNF and p=0.0446 for hosp)
******************************************************************************************

// make figure	
use "$input_datapath/figdata_females.dta", clear 
gen model = 1 
append using "$input_datapath/figdata_males.dta"
replace model = 2 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
set obs `newobs'
replace reltime = -1 if missing(reltime) 
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v') 
}
gsort model reltime
replace model = 1 in `newobs'
replace model = 2 if missing(model)

replace reltime = reltime - 0.15 if model == 1
replace reltime = reltime + 0.15 if model == 2

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue)) ///
	(scatter coef reltime if model == 2, color(maroon)) , ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(2 "Impact of Wife Event on Husbands" 3 "Impact of Husband Event on Wives") ///
		position(11) ring(0) cols(1)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12) ///
	subtitle("Spillover Effect, by Gender of Focal Spouse", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/EventStudy-bygender_`1'_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy-bygender_`1'_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy-bygender_`1'_$today.pdf", as(pdf) replace
********************************************************************************

// clean up data
rm "$input_datapath/figdata_males.dta"
rm "$input_datapath/figdata_females.dta"

