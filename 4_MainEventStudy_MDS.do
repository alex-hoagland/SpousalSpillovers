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
use "${input_datapath}/weekpanel.dta", clear

cap drop bene_id
gen bene_id = response_id

gen reltime_months = floor(reltime_weeks/4)
gen workingdate = eventdate_index + 30*reltime_months
gen wknum = month(workingdate)
cap drop year
gen year = year(workingdate)
replace year = year - 1 if treated == 0
gen ym = ym(year, wknum)

// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

// some additional outcomes 
if ("`1'" == "snf_hosp") {
	gen snf_hosp = (hospitalization == 1 & snf == 1)
} 
else if ("`1'" == "fall") { 
	cap drop bene_id
	gen bene_id = response_id
	merge m:1 bene_id treated ym using "${input_datapath}/responseevents-falls.dta", keep(1 3) nogenerate
	replace fall = 0 if missing(fall)
}
else if ("`1'" == "snf_mds") {
	
	/* For each bene_id reltime_week pair, generate new column "snf_mds" that 
	   is 1 if in SNF and 0 otherwise. Match back to main dataset. */
	
	preserve
	
	// Quick reformatting
	keep bene_id eventdate_index reltime_weeks snf
	sort bene_id eventdate_index reltime_weeks
	 
	// Merge with MDS stays so each bene_id reltime_week pair has new columns
	// entry_dt_ext and dschrg_dt_ext for each MDS SNF visit bene_id has.
	joinby bene_id using "${input_datapath}/MDS-stays.dta", unmatched(master)
	
	
	// Check if bene_id reltime_week pair is within entry_dt_ext and 
	// dschrg_dt_ext
	gen day = eventdate_index + 7*reltime_weeks 
	format day %td
	gen snf_mds = 0
	forvalues D = 0/6 {
		replace snf_mds = inrange(day+`D', entry_dt_ext , dschrg_dt_ext) ///
		if snf_mds == 0 /// only add (since they might be in snf on day 0 but not day 1)
		& !missing(entry_dt_ext) // stata inrange treats . as -inf and + inf
	}	
			
	
	// New SNF outcome: entry into SNF
	gen snf_mds_entry = 0
	bysort bene_id eventdate_index entry_dt_ext (reltime_weeks): ///
		replace snf_mds_entry = 1 ///
		if (snf_mds == 1 ///
		   & snf_mds[_n-1] == 0 ///
		   & _n > 1) ///
		| (snf_mds == 1 & ///
		  (day-7 <= entry_dt_ext) /// not within the visit a week ago
		  & _n == 1)
		
		
	/* Checks */
		assert snf_mds == 0 & snf_mds_entry == 0 ///
			if missing(entry_dt_ext)
		
		assert entry_dt_ext <= dschrg_dt_ext ///
			if !missing(entry_dt_ext)

		assert snf_mds == 1 ///
			if snf_mds_entry == 1
		
	
		
	// Each bene_id is duplicated the number of stays they've had so collapse 
	// to bene_id reltime_week level and take the max 
	collapse (max) snf snf_mds snf_mds_entry, ///
		by(bene_id eventdate_index reltime_weeks)

		
	// New SNF outcome: in MDS but not in Medpar
	gen snf_mds_only = (snf_mds == 1 & snf == 0)
	
	
	/* Checks */
		
		// Weekly match rate should be about 94.5% (last checked)
		qui sum snf_mds if snf == 1
		local mu = r(mean)
		assert `mu' >= 0.945
	
	
	// Save dataset with new columns
	tempfile snf_mds_months
	save "${input_datapath}/snf_mds_months.dta", replace
	restore
	
	// Merge main panel with new columns 
	merge m:1 bene_id eventdate_index reltime_weeks using "${input_datapath}/snf_mds_months.dta", nogen
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

if ("`2'" == "balanced") {
	// keep only households where outcome spouse lives for at least a year post-event
	gen test = death_dt - eventdate_index
	gen todrop = (!missing(death_dt) & test <= 365)
	bys index_id response_id: ereplace todrop = max(todrop) 
	drop if todrop == 1
	drop test todrop
}

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

// Collapse to month-level
if ("`1'" == "prob_snf") { 
	gcollapse (mean) `1' (max) treated* index_fem, by(index_id response_id hhid eventid ym tt reltime_months ) fast
} 
else { 
	gcollapse (max) snf snf_mds snf_mds_entry snf_mds_only treated* index_fem ///
		  , ///
		  by(index_id response_id hhid eventid ym tt reltime_months) fast
}


if ("`1'" == "snf_mds") {
	global outcomes snf snf_mds snf_mds_entry snf_mds_only
}
else {
	global outcomes `1'
}

foreach O in $outcomes {
	
preserve
sum `O' if (treated == 1 & reltime_months < 0) // | treated == 0 
local premean: di %7.6fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `O' = `O' / `premean' // rescale coefficients to be % of outcome

// robustness option 
// gen test = runiform() 
// bys index_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)
	
// run regression
reghdfe `O' ib3.tt##i.treated, ///
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
local test = "`O'"
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/EventStudy_`test'_$today_requiresurvival.gph", replace
graph export "${hoaglandoutput}/EventStudy_`test'_$today_requiresurvival.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_`test'_$today_requiresurvival.pdf", as(pdf) replace

restore 
}
********************************************************************************
