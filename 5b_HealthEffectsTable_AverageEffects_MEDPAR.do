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
replace tt = 3 if reltime_months <= -5 // additional reference points

// some additional outcomes 
gen snf_hosp = (hospitalization == 1 & snf == 1)

// merge in ED visits, if desired (can update this to include other outcomes too)
if ("`1'" == "num_ED") {
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
	gen bene_id = response_id
	merge m:1 bene_id using /disk/aging/medicare/data/harm/20pct/bsf/2010/bsfab2010, keep(1 3) keepusing(bene_id)
	gen in20 = (_merge == 3)
	bys response_id: ereplace in20 = max(in20)
	keep if in20 == 1
	drop bene_id 
}

if ("`1'" == "fall") { 
	gen bene_id = response_id
	merge m:1 bene_id treated ym using "${input_datapath}/responseevents-falls.dta", keep(1 3) nogenerate
	replace fall = 0 if missing(fall)
}

if ("`2'" == "balanced" ) { 
	// keep only households where outcome spouse lives for at least a year post-event
	cap drop bene_id
	gen bene_id = response_id 
	merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop) 
	drop if todrop == 1
	drop test todrop
}

gcollapse (max) `1' treated* index_fem fatal*, by(index_id hhid eventid ym tt reltime_months ) fast
sum `1' if (treated == 1 & reltime_ < 0)
local premean: di %7.6fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

// gen test = runiform() 
// bys index_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression: pooled 
gen post = (reltime_months >= 0)
reghdfe `1' i.post##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// save data 			
regsave , ci
keep if strpos(var, ".post#1.treated")
gen model = "`1'"
gen type = 4 // average effects -- no fatal or nonfatal here 
append using "$hoaglandoutput/5_HealthEffectsTable.dta"
save "$hoaglandoutput/5_HealthEffectsTable.dta", replace
********************************************************************************

// remove ED data if needed
cap rm "$input_datapath/tomerge_ed.dta"
