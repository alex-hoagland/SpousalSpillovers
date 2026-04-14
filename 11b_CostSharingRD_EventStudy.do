/*******************************************************************************
* Title: Event studies predicting monthly LOS in SNF and extent of Medicare coverage
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/7/2024
* Last modified by: 
* Purpose: compare with 10_CostSharing which does the rest of the RD exercise 

* NOTES: 

*******************************************************************************/


/***** First, pull in all SNF stays and the key variables 
clear
gen response_id = ""
save "$input_datapath/affected_SNFstays.dta", replace 
 
 // this pulls in *all* SNF stays 
forvalues year = 2010/2016 {
	display "***** WORKING ON YEAR `year' *****"
	use bene_id sex admsndt ad_dgns dgnscd* sslssnf ds* drg* cvrlvldt using /disk/aging/medicare/data/harm/100pct/med/`year'/med`year' if sslssnf == "N", clear 
			// limited to SNF stays only 
	
	replace dschrgdt = cvrlvldt + 1 if missing(dschrgdt) & !missing(cvrlvldt)
	replace dschrgdt = dmy(31,12,`year') if missing(dschrgdt) // note: we don't observe discharge if the stay goes over a year; we can observe if coverage exceeded its paid limits but not full LOS (would need SNF claims for that)
		// here, LOS is censored at end of year

	gen year = `year' 
	
	rename admsndt response_eventdt
	bys bene_id response_eventdt year : egen response_ds = max(dschrgdt)
	gen los = response_ds - response_eventdt + 1
	
	keep bene_id response_* los ad_dgns year cvrlvldt
	duplicates drop 
	
	rename bene_id response_id
	append using "$input_datapath/affected_SNFstays.dta"
	
	compress
	save "$input_datapath/affected_SNFstays.dta", replace			
} 

use "$input_datapath/affected_SNFstays.dta", clear
cap drop year 
gen year = year(response_event)
gen month = month(response_event)
gen ym = ym(year, month)
keep response_id ym los cvrlvldt
gcollapse (sum) los (max) cvrlvldt, by(response_id ym) fast // aggregate at person-month level 
compress
save "$input_datapath/affected_SNFstays.dta", replace
********************************************************************************/


***** Regression 1: Average LOS by month of admission *****
// merge in average LOS (with 0s for all non-admitted person-months) at person-month level 
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

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points

// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

merge m:1 response_id ym using "$input_datapath/affected_SNFstays.dta", keep(1 3) nogenerate
replace los = 0 if missing(los) 
replace cvrlvldt = 0 if missing(cvrlvldt)	
rename los snf_los
replace cvrlvldt = . if cvrlvldt == 0
gen past_coverage = !missing(cvrlvldt) // Pr(coverage expiring while in SNF)

gcollapse (mean) snf_los (max) past_coverage treated* index_fem, ///
	by(index_id hhid eventid ym tt reltime_months ) fast

foreach outcome of var snf_los past_coverage { 
	
	preserve
	sum `outcome' if (treated == 1 & reltime_ < 0)
	local premean: di %5.4fc `r(mean)'
	replace `outcome' = `outcome' / `premean' // * 100 // rescale coefficients to be % of outcome

// 	gen test = runiform() 
// 	bys index_id: ereplace test = mean(test) 
// 	keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

	// run regression
	reghdfe `outcome' ib3.tt##i.treated, ///
		absorb(eventid ym) cluster(hhid)

	// make figure			
	regsave , ci
	keep if strpos(var, ".tt#1.treated")
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

	twoway (rcap ci_lower ci_upper reltime, color(gs10)) (scatter coef reltime, color(ebblue)) , ///
		xline(-0.25, lpattern(dash)) legend(off) ///
		yline(0) ///
		xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
		xsc(r(-4(2)12)) xlab(-4(2)12) ///
		subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
			position(11) justification(left) size(medsmall)) 
			
	local test = "`outcome'"
	graph save "${hoaglandoutput}/EventStudy_`test'_$today.gph", replace
	graph export "${hoaglandoutput}/EventStudy_`test'_$today.png", as(png) replace
	graph export "${hoaglandoutput}/EventStudy_`test'_$today.pdf", as(pdf) replace
	restore
	}

// foreach outcome of var past_coverage { // cvrlvldt { 
//		
// 		sum `outcome' if (treated == 0 | reltime_months < 0)  // unconditional 
// 		local premean: di %5.4fc `r(mean)'
// 		sum `outcome' if (treated == 0 | reltime_months < 0) & snf_los > 0 // conditional on staying
// 		local premean_cond: di %5.2fc `r(mean)'
//
// 		preserve
// 		gcollapse (max) treated* (max) `outcome', by(wifeid eventid yw tt) fast
// 		replace `outcome' = `outcome' / `premean' // * 100 // rescale coefficients to be % of outcome
//
// 		// run regression
// 		reghdfe `outcome' ib3.tt##i.treated, ///
// 			absorb(eventid  yw) cluster(wifeid)
//
// 		// make figure			
// 		regsave , ci
// 		keep if strpos(var, ".tt#1.treated")
// 		gen reltime = substr(var, 1, 2)
// 		destring reltime, replace
// 		replace reltime = reltime - 4
// 		local newobs = _N + 1
// 		di `newobs'
// 		set obs `newobs'
// 		replace reltime = -1 in `newobs'
// 		foreach v of varlist coef ci_* {
// 			replace `v' = 0 in `newobs'
// 		}
// 		gsort reltime
//		
// 		twoway (connect coef reltime) (rcap ci_lower ci_upper reltime), ///
// 			xline(-0.25, lpattern(dash)) legend(off) ///
// 			yline(0) ///
// 			xtitle("Months Around Wife's First Heart Attack/Stroke") ///
// 			ytitle("Effect, Relative to Baseline Mean") ///
// 			xsc(r(-4(1)4)) xlab(-4(1)4) ///
// 			text(0.65 -3 "Pre-treatment conditional mean: `premean_cond'", place(e)) 
// 		graph save "${hoaglandoutput}/DynDD_`outcome'_rand`randomize'_$today.gph", replace
// 		graph export "${hoaglandoutput}/DynDD_`outcome'_rand`randomize'_$today.png", as(png) replace
// 		restore
// 	}
********************************************************************************

