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

if ("`2'" == "balanced") {
	// keep only households where outcome spouse lives for at least a year post-event
	cap drop bene_id
	gen bene_id = response_id 
	merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
}
	
// aggregate to monthly level 
gen reltime_months = floor(reltime_weeks/4)
gen workingdate = eventdate_index + 30*reltime_months
gen wknum = month(workingdate)
cap drop year 
gen year = year(workingdate)
replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)

if ("`2'" == "balanced") {
	// keep only households where outcome spouse lives for at least a year post-event
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop) 
	drop if todrop == 1
	drop test todrop
}

// some additional outcomes 
if ("`1'" == "snf_hosp") {
	gen snf_hosp = (hospitalization == 1 & snf == 1)
} 

else if ("`1'"' == "prob_snf") { 
	// merge in from "${input_datapath}/lasso_prob_snf_3folds.dta"
	// data constructed in INPROGRESS_updatelasso.do 
	merge m:1 response_id treated reltime_months using "$input_datapath/tomerge_probsnf.dta", ///
		keep(1 3) nogenerate
	replace prob_snf = 0 if missing(prob_snf) | hosp == 0 // need a hospitalization for pr(snf) to matter; missing values convert to 0 below (or with max, go away)
}
else if ("`1'" == "fall") { 
	cap drop bene_id
	gen bene_id = response_id
	merge m:1 bene_id treated ym using "${input_datapath}/responseevents-falls.dta", keep(1 3) nogenerate
	replace fall = 0 if missing(fall)
}
else if ("`1'" == "num_ED") {
	preserve
	use "${input_datapath}/EDdx.dta", clear // what file creates this?
	drop if missing(rev_dt)

	// count # of ED visits at month level 
	replace year = year(rev_dt)
	gen wknum = month(rev_dt)
	gen ym = ym(year, wknum)
	drop wknum year 
	drop if missing(ym)
	gen num_ED = 1 	
	gcollapse (sum) num_ED, by(bene_id ym) fast

	rename bene_id response_id
	save $input_datapath/tomerge_ed.dta, replace
	restore

	merge m:1 response_id ym using $input_datapath/tomerge_ed.dta, keep(1 3) nogenerate
	replace num_ED = 0 if missing(num_ED)

	// will need to drop those who aren't in the 20% files for the regression 
	cap drop bene_id
	gen bene_id = response_id
	merge m:1 bene_id using /disk/aging/medicare/data/harm/20pct/bsf/2010/bsfab2010, keep(1 3) keepusing(bene_id)
	gen in20 = (_merge == 3)
	bys response_id: ereplace in20 = max(in20)
	keep if in20 == 1
	drop bene_id 
}

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

if ("`1'" == "prob_snf") { 
	gcollapse (max) `1' snf treated* index_fem, by(index_id response_id hhid eventid ym tt reltime_months ) fast
	// take highest Pr(SNF) in a month, reverts to 0 if there is no hospitalization in a month
	// regressions for both SNF and pred_SNF in levels 
		
	// robustness option 
	// gen test = runiform() 
	// bys index_id: ereplace test = mean(test) 
	// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

	// run regression
	reghdfe prob_snf ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)
	regsave using "$input_datapath/regdata_probsnf", p ci replace
	
	reghdfe snf ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)
	regsave, p ci 

	// make figure	
	gen model = 0 
	append using "$input_datapath/regdata_probsnf"
	replace model = 1 if missing(model)
	keep if strpos(var, ".tt#1.treated")
	cap drop if strpos(var, "o.")
	gen reltime = substr(var, 1, 2)
	destring reltime, replace
	replace reltime = reltime - 4
	local newobs = _N + 2
	di `newobs'
	set obs `newobs'
	replace reltime = -1 if missing(reltime) 
	foreach v of varlist coef ci_* {
		replace `v' = 0 if reltime == -1 
	}
	local obs = _N
	replace model = 0 in `obs'
	replace model = 1 if missing(model)
	gsort reltime
	
	replace reltime = reltime - 0.15 if model == 0 
	replace reltime = reltime + 0.15 if model == 1

	// keep if abs(reltime) <= 4
	sum coef if model == 0 & reltime > -0.5 
	local mean0 = `r(mean)'
	sum coef if model == 1 & reltime > -0.5
	local mean1 = `r(mean)'
	twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
		(scatter coef reltime if model == 0, color(ebblue)) ///
		(scatter coef reltime if model == 1, color(maroon)) , ///
		xline(-0.25, lpattern(dash)) ///
		legend(order(2 "Full SNF Effect" 3 "LASSO-Predicted SNF Effect") ///
			rows(1) ring(0) position(11)) ///
		yline(0) yline(`mean0', lpattern(dash) lcolor(ebblue)) ///
		yline(`mean1', lpattern(dash) lcolor(maroon))  ///
		xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
		xsc(r(-4(2)12)) xlab(-4(2)12) 
	graph save "${hoaglandoutput}/EventStudy_prob_snf_${today}_`2'.gph", replace
	graph export "${hoaglandoutput}/EventStudy_prob_snf_${today}_`2'.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_prob_snf_${today}_`2'.pdf", as(pdf) replace
} 
else { 
	gcollapse (max) `1' treated* index_fem, by(index_id response_id hhid eventid ym tt reltime_months ) fast
	
	// rescale only for non-decomposed results
	sum `1' if (treated == 1 & reltime_ < 0) // | treated == 0 
	local premean: di %7.6fc `r(mean)'
	local textmean: di %3.1fc `r(mean)' * 1000
	replace `1' = `1' / `premean' // rescale coefficients to be % of outcome
	
	// robustness option 
	// gen test = runiform() 
	// bys index_id: ereplace test = mean(test) 
	// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

	// run regression
	reghdfe `1' ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)

	// make figure			
	regsave , ci
	keep if strpos(var, ".tt#1.treated")
	cap drop if strpos(var, "o.")
	gen reltime = substr(var, 1, 2)
	destring reltime, replace
	replace reltime = reltime - 4
	local newobs = _N + 1
	di `newobs'
	set obs `newobs'
	replace reltime = -1 in `newobs'
	foreach v of varlist coef ci_* {
		replace `v' = 0 in `newobs'
	}
	gsort reltime

	// keep if abs(reltime) <= 4
	local test = "`1'"
	twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
		(scatter coef reltime, color(ebblue)) , ///
		xline(-0.25, lpattern(dash)) legend(off) ///
		yline(0) ///
		xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
		xsc(r(-4(2)12)) xlab(-4(2)12) ///
		subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
			position(11) justification(left) size(medsmall)) 
	graph save "${hoaglandoutput}/EventStudy_`test'_${today}_`2'.gph", replace
	graph export "${hoaglandoutput}/EventStudy_`test'_${today}_`2'.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_`test'_${today}_`2'.pdf", as(pdf) replace
}
********************************************************************************
