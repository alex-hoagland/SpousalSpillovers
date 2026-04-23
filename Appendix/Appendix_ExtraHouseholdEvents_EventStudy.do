/*******************************************************************************
* Title: Make figures
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: June 2025
* Last modified by: 
* Purpose: This file makes figures -- can be edited to impose restrictions

* NOTES: 
	- now needs to be run through the mastre file to accommodate multiple outcomes
	- pooled across spouses
*******************************************************************************/


****************************************************************
**** UPDATE PANEL TO ALLOW MULTIPLE EVENTS  ****
****************************************************************

// note: this requires spouses to be continuously enrolled between t=-1 and (real or placebo) event 
// so one year pre and post for a true event, and one year pre and post for placebo event 

use "${input_datapath}/indexevents_mergedspouses.dta", clear
preserve
keep index_id file_year
duplicates drop
tempfile mywives
save `mywives', replace
restore

keep response_id file_year 
duplicates drop
tempfile myhusbands
save `myhusbands', replace

forvalues yr = 2009/2016 { // if not requiring two years pre, then this isn't 2009
	di "***** YEAR `yr': WIVES *****"
	use `mywives' if file_year == `yr'
	keep index_id
	gen bene_id = index_id
	merge 1:m bene_id using  "/disk/aging/medicare/data/harm/100pct/bsfab/`yr'/bsfab`yr'.dta", keep(3) nogenerate 	
	cap gen ms_cd = ""
	cap replace ms_cd = "10" if missing(ms_cd) & mdcr_stus_cd_01 == "10" & mdcr_stus_cd_02 == "10" & ///
		mdcr_stus_cd_03 == "10" & mdcr_stus_cd_04 == "10" & mdcr_stus_cd_05 == "10" & mdcr_stus_cd_06 == "10" & ///
		mdcr_stus_cd_07 == "10" & mdcr_stus_cd_08 == "10" & mdcr_stus_cd_09 == "10" & mdcr_stus_cd_10 == "10" & ///
		mdcr_stus_cd_11 == "10" & mdcr_stus_cd_12 == "10"
	cap replace ms_cd = "11" if missing(ms_cd) & mdcr_stus_cd_01 == "11" & mdcr_stus_cd_02 == "11" & ///
		mdcr_stus_cd_03 == "11" & mdcr_stus_cd_04 == "11" & mdcr_stus_cd_05 == "11" & mdcr_stus_cd_06 == "11" & ///
		mdcr_stus_cd_07 == "11" & mdcr_stus_cd_08 == "11" & mdcr_stus_cd_09 == "11" & mdcr_stus_cd_10 == "11" & ///
		mdcr_stus_cd_11 == "11" & mdcr_stus_cd_12 == "11"
	keep if inlist(ms_cd, "10", "11") // only eligibility we want
	keep index_id file_year 
	gen eligible = 1
	tempfile mywives_`yr'
	save `mywives_`yr'', replace
	
	di "***** YEAR `yr': HUSBANDS *****"
	use `myhusbands' if file_year == `yr'
	keep response_id
	duplicates drop
	gen bene_id = response_id
	merge 1:m bene_id using  "/disk/aging/medicare/data/harm/100pct/bsfab/`yr'/bsfab`yr'.dta", keep(3) nogenerate 
	cap gen ms_cd = ""
	cap replace ms_cd = "10" if missing(ms_cd) & mdcr_stus_cd_01 == "10" & mdcr_stus_cd_02 == "10" & ///
		mdcr_stus_cd_03 == "10" & mdcr_stus_cd_04 == "10" & mdcr_stus_cd_05 == "10" & mdcr_stus_cd_06 == "10" & ///
		mdcr_stus_cd_07 == "10" & mdcr_stus_cd_08 == "10" & mdcr_stus_cd_09 == "10" & mdcr_stus_cd_10 == "10" & ///
		mdcr_stus_cd_11 == "10" & mdcr_stus_cd_12 == "10"
	cap replace ms_cd = "11" if missing(ms_cd) & mdcr_stus_cd_01 == "11" & mdcr_stus_cd_02 == "11" & ///
		mdcr_stus_cd_03 == "11" & mdcr_stus_cd_04 == "11" & mdcr_stus_cd_05 == "11" & mdcr_stus_cd_06 == "11" & ///
		mdcr_stus_cd_07 == "11" & mdcr_stus_cd_08 == "11" & mdcr_stus_cd_09 == "11" & mdcr_stus_cd_10 == "11" & ///
		mdcr_stus_cd_11 == "11" & mdcr_stus_cd_12 == "11"
	keep if inlist(ms_cd, "10", "11") // only eligibility we want
	keep response_id file_year 
	gen eligible = 1
	tempfile myhusbands_`yr'
	save `myhusbands_`yr'', replace
}

use "${input_datapath}/indexevents_mergedspouses.dta", clear
drop if file_year >= 2017 // don't have data for these years, and they shouldn't be index events anyway.
gen w_elig = 0
gen h_elig = 0
forvalues yr = 2009/2016 { 
	merge m:1 index_id file_year using `mywives_`yr'', keep(1 3) nogenerate
	replace w_elig = 1 if eligible == 1
	drop eligible
	merge m:1 response_id file_year using `myhusbands_`yr'', keep(1 3) nogenerate
	replace h_elig = 1 if eligible == 1
	drop eligible 
} 

bys index_id response_id eventdate_index treated: egen w = mean(w_elig)
bys index_id response_id eventdate_index treated: egen h = mean(h_elig)
keep if w == 1 & h == 1 // drops ~1/5 of the remaining sample 
drop w w_elig h h_elig file_year
rename eventyear file_year 
duplicates drop // we have ~1.2M events

egen eventid = group(index_id response_id eventdate_index treated)
compress
save "${input_datapath}/indexevents_mergedspouses_eligible_me.dta", replace
********************************************************************************


***** Make the panel 
// merge is a bit more complicated since we now have multiple events 
use "${input_datapath}/indexevents_mergedspouses_eligible_me.dta", clear 
bys index_id response_id treated: gen test = _n
keep response_id index_id eventid treated eventdate_index test
duplicates drop

// reshape here 
reshape wide eventdate_index, i(index_id response_id eventid treated) j(test)
gen bene_id = response_id 
bys bene_id treated: keep if _n == 1 // drops < 1% of sample
tempfile tomerge
save `tomerge', replace

// merge in response events
use "${input_datapath}/responseevents-MEDPAR.dta", clear
expand 2, generate(treated)
merge m:1 bene_id treated using `tomerge', keep(3) nogenerate
// drop if ext_injury == 1 // for replication 
drop bene_id

// reshape back 
bys index_id response_id eventid treated response_eventdt: gen i = _n
reshape long eventdate_index, i(index_id response_id eventid treated response_eventdt i) j(j)
drop if missing(eventdate_index)
drop i j 
gen elapse = response_eventdt - eventdate_index

// count these as absorbing across multiple dates of admission
// keep if abs(elapse) <= 365/2 // 6 months in days (limits sample before the "expand" command)
gen response_time = response_ds - response_eventdt + 1
expand response_time // make a copy of the event for each day the person is admitted
gen admissiondt = response_eventdt
bys index_id response_id eventid admissiondt: replace response_eventdt = response_eventdt + _n - 1 

// gen span between male response event and index event
replace elapse = response_eventdt - eventdate_index
gen reltime_weeks = floor(elapse/7)

// save by weeks
keep if abs(elapse) <= 400 

gcollapse (max) snf* hosp* fem, ///
	by(response_id index_id eventid reltime_weeks treated) fast

save "${input_datapath}/responseevents_panel_weeks_me.dta", replace // about 1.2M events
********************************************************************************


***** Merge back in to header **************************************************
// now merge in both treated and control groups
use "${input_datapath}/indexevents_mergedspouses_eligible_me.dta", clear
cap drop bene_id 
expand 105, gen(reltime_weeks)
bysort eventid: replace reltime_weeks = _n - 53
keep if inrange(reltime_weeks, -52, 52)
merge 1:1 index_id response_id eventid reltime_weeks using "${input_datapath}/responseevents_panel_weeks_me.dta", keep(1 3) nogenerate

// keep only opposite-sex pairs
bys index_id response_id treated: ereplace fem = max(fem)
bys index_id response_id treated: ereplace index_fem = max(index_fem)
drop if fem == 1 & index_fem == 1 
drop if fem == 0 & index_fem == 0 
drop fem // drops ~2% of sample

foreach v of var hosp* snf*  { // mdc* adrd* iez* { 
	replace `v' = 0 if missing(`v')
}

drop if treated == 1 & file_year == 2017 // can keep this year for control group only 

// why doesn't this merge work?
// merge in predicted SNF probability 
// gen bene_id = response_id 
// merge m:1 bene_id using "${input_datapath_branch}/lasso_prob_snf_3folds.dta", keep(1 3) nogenerate keepusing(l_pred_prob)
// drop bene_id

compress
save "${input_datapath}/weekpanel_me.dta", replace // should have about 113M observations
********************************************************************************/

cap gen bene_id = response_id 

/* For each bene_id reltime_week pair, generate new column "snf_mds" that 
   is 1 if in SNF and 0 otherwise. Match back to main dataset. */

// save "${input_datapath}/weekpanel_backup.dta", replace
  
preserve

// Quick reformatting
keep bene_id eventdate_index reltime_weeks snf

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
	cap assert `mu' >= 0.945
	if _rc {
		dis "match rate is `mu'"
		error 9
	}

// Save dataset with new columns
tempfile snf_mds_months
save "${input_datapath}/snf_mds_months.dta", replace
restore

// Merge main panel with new columns 
merge m:1 bene_id eventdate_index reltime_weeks using "${input_datapath}/snf_mds_months.dta", nogen


// Indicator for if outcome spouse dies within a year of shock
cap drop bene_id
gen bene_id = response_id 
merge m:1 bene_id using "${input_datapath}/mortality.dta", keep(1 3) nogenerate

gen test = death_dt - eventdate_index
gen nosurvive = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace nosurvive = max(nosurvive) 
drop test 

compress
save "${input_datapath}/weekpanel_me.dta", replace 

********************************************************************************/

	
***** Main Regression 
// gen todrop = (time_pre <= 365*3)
// bys index_id: ereplace todrop = max(todrop) 
// drop if todrop == 1 
// drop todrop 

use "${input_datapath}/weekpanel_me.dta" , clear 
	
	
// aggregate to monthly level 
gen reltime_months = floor(reltime_weeks/4)
gen workingdate = eventdate_index + 30*reltime_months
gen wknum = month(workingdate)
cap drop year 
gen year = year(workingdate)
replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 5 is now the base period (-1 + 6 = 5)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points

// keep only households where outcome spouse lives for at least a year post-event
drop if nosurvive == 1

gcollapse (max) `1' treated* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast

sum `1' if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

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
twoway (rcap ci_lower ci_upper reltime, color(gs10)) (scatter coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/EventStudy_`1'-extraevents_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_`1'-extraevents_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_`1'-extraevents_$today.pdf", as(pdf) replace
********************************************************************************
