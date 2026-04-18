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

// some additional outcomes 

	// merge in from "${input_datapath}/lasso_prob_snf_3folds.dta"
	// data constructed in INPROGRESS_updatelasso.do 
	merge m:1 response_id treated reltime_months using "$input_datapath/tomerge_probsnf.dta", ///
		keep(1 3) nogenerate
	replace prob_snf = 0 if missing(prob_snf) | hospitalization == 0 // need a hosp first
		// note: this will convert to 0 below in gcollapse 

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

	gcollapse (max) prob_snf snf hospitalization treated* index_fem, by(index_id response_id hhid eventid ym tt reltime_months ) fast // will keep max Pr(SNF) in a given month, if there is no hospitalization then = 0
	
	// regressions for both SNF and pred_SNF in levels 
		
	// robustness option 
	// gen test = runiform() 
	// bys index_id: ereplace test = mean(test) 
	// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

	// run regression
// 	reghdfe prob_snf ib3.tt##i.treated, ///
// 		absorb(eventid ym) cluster(hhid)
//	
// 	reghdfe snf ib3.tt##i.treated, ///
// 		absorb(eventid ym) cluster(hhid)
//		
// 	gen post = (reltime_months >= 0)
// 	reghdfe prob_snf i.post##i.treated, ///
// 		absorb(eventid ym) cluster(hhid)
//	
// 	reghdfe snf i.post##i.treated, ///
// 		absorb(eventid ym) cluster(hhid)
		
	// do the same thing but for constant average effects
	// for this, need to know the overall rate at which a hospitalization turns into a SNF stay
	// use the full data for this
// 	preserve
// 	use orgnpinm bene_id sex age* race* admsndt ad_dgns dgnscd* sslssnf ds* drg* prvdrnum using /disk/aging/medicare/data/harm/100pct/med/2011/med2011, clear
// 	keep if sslssnf != "N" // hospitalization
// 	gen hosp_2snf = (dstntncd == "03") // overall, 18.699% of hospitalizations end in snf stays
// 	restore
	
	replace hospitalization = 0.18699 if hospitalization == 1
// 	reghdfe hospitalization i.post##i.treated, ///
// 		absorb(eventid ym) cluster(hhid)
		
	reghdfe hospitalization ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)
	regsave using "$input_datapath/regdata_probsnf_levels", p ci replace
	
	reghdfe snf ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)
	preserve
	regsave, p ci 

	// make figure	
	gen model = 0 
	append using "$input_datapath/regdata_probsnf_levels"
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
		legend(order(2 "Full SNF Effect" 3 "Predicted SNF Effect") ///
			rows(1) ring(0) position(11)) ///
		yline(0) yline(`mean0', lpattern(dash) lcolor(ebblue)) ///
		yline(`mean1', lpattern(dash) lcolor(maroon))  ///
		xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
		xsc(r(-4(2)12)) xlab(-4(2)12) 
	graph save "${hoaglandoutput}/EventStudy_prob_snf-base_${today}_requiresurvival.gph", replace
	graph export "${hoaglandoutput}/EventStudy_prob_snf-base_${today}_requiresurvival.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_prob_snf-base_${today}_requiresurvival.pdf", as(pdf) replace
	restore
