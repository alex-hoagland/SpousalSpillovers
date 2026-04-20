/*******************************************************************************
* Title: Split main health effect DD by if the response spouse had a chronic condition 
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/6/2024
* Last modified by: 
* Purpose: 

* NOTES: 

*******************************************************************************/


***** Main Regression , split by if husband has chronic condition or not 
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
replace tt = 3 if reltime_months <= -5 // additional reference points

if ("`2'" == "balanced" ) {
	cap drop bene_id
	gen bene_id = response_id
	merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop)
	drop if todrop == 1
	drop test todrop
}

gen test = runiform() 
bys index_id eventid: ereplace test = mean(test) 
keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// split based on index discharge status 

// keep only some nonfatal discharges
keep if nonfatal_tosnf == 1 | nonfatal_torehab == 1 | nonfatal_tohome == 1 

// also drop response_ids if they were hospitalized in the 12 weeks prior to event 
gen todrop = (hospitalization == 1 & inrange(reltime_weeks, -12, -1))
bys response_id eventid: ereplace todrop = max(todrop)
drop if todrop == 1 
drop todrop 

gcollapse (max) `1' treated* nonfatal_tohome index_fem, by(index_id hhid eventid ym tt reltime_months ) fast
sum `1' if (treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

// run regression for p-value
egen ym_sex = group(ym index_fem)

reghdfe `1' ib3.tt##i.treated##nonfatal_tohome, ///
	absorb(eventid ym) cluster(hhid)
test 4bn.tt#1bn.treated#1bn.nonfatal_tohome 5bn.tt#1bn.treated#1bn.nonfatal_tohome 6bn.tt#1bn.treated#1bn.nonfatal_tohome 7bn.tt#1bn.treated#1bn.nonfatal_tohome 8bn.tt#1bn.treated#1bn.nonfatal_tohome

// run split regression: any_chronic
reghdfe `1' ib3.tt##i.treated if nonfatal_tohome== 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_tohome.dta", replace ci p

// run split regression: no any_chronic
reghdfe `1' ib3.tt##i.treated if nonfatal_tohome == 0, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_notohome.dta", replace ci p

// make figure	
use "$input_datapath/figdata_notohome.dta", clear 
gen model = 1 
append using "$input_datapath/figdata_tohome.dta"
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
	(scatter coef reltime if model == 1, color(maroon) msymbol(square)) ///
	(scatter coef reltime if model == 2, color(ebblue) msymbol(circle)) , ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(3 "Home Discharge" 2 "Medical Facility Discharge (SNF or Rehab)") ///
		position(10) ring(0) cols(1) size(vsmall)) ///
	xtitle("Months Around Index Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, by Index Event Discharge", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_$today.gph", replace
graph export "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_$today.png", as(png) replace
graph export "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_$today.pdf", as(pdf) replace


twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(maroon) msymbol(square)) ///
	(scatter coef reltime if model == 2, color(ebblue) msymbol(circle)) , ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(3 "Home Discharge" 2 "Medical Facility Discharge (SNF or Rehab)") ///
		position(12) ring(1) rows(1) size(vsmall)) ///
	xtitle("Months Around Index Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, by Index Event Discharge", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_v2_$today.gph", replace
graph export "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_v2_$today.png", as(png) replace
graph export "${hoaglandoutput}/SplitEffects_IndexDischarge_`1'_v2_$today.pdf", as(pdf) replace
********************************************************************************

// clean up data
rm "$input_datapath/figdata_notohome.dta"
rm "$input_datapath/figdata_tohome.dta"
