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
use "${input_datapath}/weekpanel.dta", clear 

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
replace tt = 3 if reltime_months <= -5 // additional reference points

// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

// gen test = runiform() 
// bys index_id eventid: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// pull in race of response spouse using BSF files
preserve
keep response_id year
gcollapse (min) year, by(response_id) fast
gen bene_id = response_id 
gen race_white = 0 
gen race_black = 0 
levelsof year, local(myy)
foreach y of local myy { 
	di "***** YEAR `y' *****"
	merge m:1 bene_id using "/disk/aging/medicare/data/harm/100pct/bsf/`y'/bsfab`y'.dta", ///
	keep(1 3) nogenerate keepusing(race)
	replace race_white = 1 if race == "1"
	replace race_black = 1 if race == "2"
	drop race
}
gen race_other = (race_white == 0 & race_black == 0)
gcollapse (max) race_* , by(response_id) fast
egen test = rowtotal(race_* )
replace race_white = 0 if test > 1 
replace race_black = 0 if test > 1 
replace race_other = 1 if test > 1 
drop test
save "$input_datapath/tomerge.dta", replace
restore

merge m:1 response_id using "$input_datapath/tomerge.dta", keep(3) nogenerate

gcollapse (max) snf treated* race_*, by(index_id hhid eventid ym tt reltime_months ) fast
sum snf if (treated == 1 & reltime_ < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace snf = snf / `premean' // * 100 // rescale coefficients to be % of outcome

// split regression for each group 
foreach v of varlist race_* { 
	reghdfe snf ib3.tt##i.treated if `v'== 1, ///
		absorb(eventid ym) cluster(hhid)
	regsave using "$input_datapath/figdata_`v'.dta", replace ci p
}


// make figure	
use "$input_datapath/figdata_race_white.dta", clear 
gen model = 1 
append using "$input_datapath/figdata_race_black.dta"
replace model = 2 if missing(model)
append using "$input_datapath/figdata_race_other.dta"
replace model = 3 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 3
set obs `newobs'
replace reltime = -1 if missing(reltime) 
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v') 
}
gsort model reltime
replace model = mod(_n, 3) + 1 if missing(model)

replace reltime = reltime - 0.15 if model == 1
replace reltime = reltime + 0.15 if model == 3

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue) msymbol(square)) ///
	(scatter coef reltime if model == 2, color(midgreen) msymbol(triangle)) ///
	(scatter coef reltime if model == 3, color(maroon) msymbol(circle)), ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(2 "White" 3 "Black" 4 "All Other") ///
		position(11) ring(0) cols(1)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12) ///
	subtitle("Spillover Effect, by Outcome Spouse Race", ///
		position(11) justification(left) size(medsmall)) 
		
graph save "${hoaglandoutput}/SplitEffects_ResponseRace_snf_$today.gph", replace
graph export "${hoaglandoutput}/SplitEffects_ResponseRace_snf_$today.png", as(png) replace
graph export "${hoaglandoutput}/SplitEffects_ResponseRace_snf_$today.pdf", as(pdf) replace
********************************************************************************
