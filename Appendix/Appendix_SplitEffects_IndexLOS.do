/*******************************************************************************
* Title: Split main health effect DD by the LOS of the index event
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 3/3/2025
* Last modified by: 
* Purpose: 

* NOTES: 

*******************************************************************************/

***** Main Regression 
use "${input_datapath}/weekpanel.dta" if nonfatal_tosnf == 1 | nonfatal_torehab == 1 | nonfatal_tohome == 1 , clear 
	// keep only nonfatal discharges
	
// also drop response_ids if they were hospitalized in the 12 weeks prior to event 
gen todrop = (hospitalization == 1 & inrange(reltime_weeks, -12, -1))
bys response_id eventid: ereplace todrop = max(todrop)
drop if todrop == 1 
drop todrop 
	
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

// keep only households where outcome spouse lives for at least a year post-event
if ("`2'" == "balanced" ) { 
	drop if nosurvive == 1
}

// gen test = runiform() 
// bys index_id eventid: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// split based on index LOS
gen los_14 = (index_los >= 14)  // 4.5% of sample
gen los_7 = (inrange(index_los, 7, 13)) // 17% of sample
gen los_3 = (inrange(index_los, 3, 6)) // 59% of sample
gen los_1 = (inrange(index_los, -1, 2)) // 20% of sample

gcollapse (max) `1' treated* los_*, by(index_id hhid eventid ym tt reltime_months ) fast
sum `1' if (treated == 1 & reltime_ < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

// split regression for each group 
foreach v of varlist los_* { 
	reghdfe `1' ib3.tt##i.treated if `v'== 1, ///
		absorb(eventid ym) cluster(hhid)
	regsave using "$input_datapath/figdata_`v'.dta", replace ci p
}


// make figure	
use "$input_datapath/figdata_los_1.dta", clear 
gen model = 1 
append using "$input_datapath/figdata_los_3.dta"
replace model = 2 if missing(model)
append using "$input_datapath/figdata_los_7.dta"
replace model = 3 if missing(model)
append using "$input_datapath/figdata_los_14.dta"
replace model = 4 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 4
set obs `newobs'
replace reltime = -1 if missing(reltime) 
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v') 
}
gsort model reltime
replace model = mod(_n, 4) + 1 if missing(model)

replace reltime = reltime - 0.2 if model == 1
replace reltime = reltime - 0.1 if model == 2
replace reltime = reltime + 0.1 if model == 3
replace reltime = reltime + 0.2 if model == 4

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue) msymbol(square)) ///
	(scatter coef reltime if model == 2, color(midgreen) msymbol(triangle)) ///
	(scatter coef reltime if model == 3, color(dknavy) msymbol(diamond)) ///
	(scatter coef reltime if model == 4, color(purple) msymbol(circle)), ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(2 "<3 days" 3 "3--6 days" 4 "7--13 days" 5 "14+ days") ///
		position(11) ring(0) cols(2)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12) ///
	subtitle("Spillover Effect, by Shock Spouse LOS", ///
		position(11) justification(left) size(medsmall)) 
		
graph save "${hoaglandoutput}/SplitEffects_IndexLOS_`1'_$today.gph", replace
graph export "${hoaglandoutput}/SplitEffects_IndexLOS_`1'_$today.png", as(png) replace
graph export "${hoaglandoutput}/SplitEffects_IndexLOS_`1'_$today.pdf", as(pdf) replace
********************************************************************************

// clean up data
rm "$input_datapath/figdata_los_1.dta"
rm "$input_datapath/figdata_los_3.dta"
rm "$input_datapath/figdata_los_7.dta"
rm "$input_datapath/figdata_los_14.dta"
