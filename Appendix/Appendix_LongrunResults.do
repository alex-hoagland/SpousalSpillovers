/*******************************************************************************
* Title: Construct Panel: robustness to alternative gaps between treatment and placebo control group
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 3/5/2026
* Last modified by: 
* Purpose: This file enforces spousal pairs and continuous enrollment

* NOTES: 
	- follows the 3_ConstructPanel.do logic
	- user selects how many years apart the gap should be: treatment effects are defined up to g years
*******************************************************************************/


****************************************************************
**** FIRST, IDENTIFY SPOUSES BASED ON PREVIOUS YEAR ****
****************************************************************

// should this be 3?
local g = 4 // gap in years

use "${input_datapath}/indexevents_base.dta", clear	

// real + placebo events 
expand 2, gen(treated)
replace file_year = file_year - `g' if treated == 0 
replace eventdate_index = eventdate_index - 365*`g' if treated == 0 
drop if treated == 0 & time_pre <= 365*(`g'+2) // require an additional year of look back for the placebo event 
	
// merge spouses in year *prior* to event 
gen year = file_year - 1 // note: this means the first event has to be in 2011 or later
drop if year < 2010 // don't have spousal data for these 
drop if treated == 1 & inrange(file_year, 2010, 2010+`g'-1) // need to drop these since they won't be in the control
gen husbandid = ""

	// merge on bene_id1 first
	gen bene_id1 = index_id
	merge m:1 bene_id1 year using "${input_datapath}/spousal_sample_tomerge.dta", keep(1 3) keepusing(bene_id* year)
	replace husbandid = bene_id2 if _merge == 3
	drop _merge bene_id*
	
	// merge on bene_id2 next
	gen bene_id2 = index_id
	merge m:1 bene_id2 year using "${input_datapath}/spousal_sample_tomerge.dta", keep(1 3) keepusing(bene_id* year)
	replace husbandid = bene_id1 if _merge == 3
	drop _merge bene_id* year 
	
// drop index folks without spouses
drop if missing(husbandid) // about 65% are missing spouses here 
rename husbandid response_id 
egen hhid = group(index_id response_id treated)
compress
save "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs.dta", replace // should be about 1.2M observations with spouses identified 
*******************************************************


****************************************************************
**** SECOND, REQUIRE CONTINUOUS ENROLLMENT OF BOTH SPOUSES  ****
****************************************************************

// note: this requires spouses to be continuously enrolled between t=-1 and (real or placebo) event 
// so one year pre and post for a true event, and one year pre and post for placebo event 

// make list of bene_id and years
use "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs.dta", clear
expand 3
gen eventyear = file_year
bys index_id response_id: replace file_year = file_year - 1 if _n == 2
bys index_id response_id: replace file_year = file_year - 2 if _n == 3 // do we need this? 
save "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs.dta", replace

use "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs.dta", clear
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

use "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs.dta", clear
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
//save "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs_eligible.dta", replace
********************************************************************************


***** Make the panel 
//use  "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs_eligible.dta", clear
bys response_id treated: keep if _n == 1 // drops 1.2% of events (18,233)
gen bene_id = response_id
save "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs_eligible.dta", replace

// merge in response events
use "${input_datapath}/responseevents-MEDPAR.dta", clear
expand 2, generate(treated)
merge m:1 bene_id treated using "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs_eligible.dta", keep(3) nogenerate
// drop if ext_injury == 1 // for replication 
drop bene_id
gen elapse = response_eventdt - eventdate_index

// count these as absorbing across multiple dates of admission
// keep if abs(elapse) <= 365/2 // 6 months in days (limits sample before the "expand" command)
gen response_time = response_ds - response_eventdt + 1
expand response_time // make a copy of the event for each day the person is admitted
gen admission_dt = response_eventdt
bys index_id response_id eventid admission_dt: replace response_eventdt = response_eventdt + _n - 1  // admission_dt

// gen span between male response event and index event
replace elapse = response_eventdt - eventdate_index
gen reltime_weeks = floor(elapse/7)

// save by weeks
keep if abs(elapse) <= 365*4 // leaves you a little wiggle room 

// added 5.21.2025: 2 new outcomes
// one is index_adrd_admit, true in 5% or so of cases 
replace response_orgnpi = . if snf == 0 // keep codes only for SNF (~40% of obs)
	// we have index_npi for about 13% of observations
gen samesnf = (!missing(response_orgnpi) & snf == 1 & ///
		!missing(index_orgnpi) & response_orgnpi == index_orgnpi) // true in 4% or so of cases

gcollapse (max) snf* hosp* fem samesnf index_adrd ext_injury heart_stroke*, ///
	by(response_id index_id eventid reltime_weeks treated) fast

save "${input_datapath}/ax_responseevents_panel_`g'yrs.dta", replace // about 1.2M events
********************************************************************************


***** Merge back in to header **************************************************
// now merge in both treated and control groups
use "${input_datapath}/ax_indexevents_mergedspouses_`g'yrs_eligible.dta", clear
cap drop bene_id 
expand (52*(`g'+1)+1), gen(reltime_weeks)
bysort eventid: replace reltime_weeks = _n - 53
keep if inrange(reltime_weeks, -52, 52*`g')
merge 1:1 index_id response_id eventid reltime_weeks using "${input_datapath}/ax_responseevents_panel_`g'yrs.dta", keep(1 3) nogenerate

// keep only opposite-sex pairs
bys index_id response_id treated: ereplace fem = max(fem)
bys index_id response_id treated: ereplace index_fem = max(index_fem)
drop if fem == 1 & index_fem == 1 
drop if fem == 0 & index_fem == 0 
drop fem // drops ~2% of sample

foreach v of var hosp* snf* fatal* nonfatal* index_adrd samesnf heart_stroke* { // mdc* adrd* iez* { 
	replace `v' = 0 if missing(`v')
}

drop if treated == 1 & file_year == 2017 // can keep this year for control group only 

// why doesn't this merge work?
// merge in predicted SNF probability 
// gen bene_id = response_id 
// merge m:1 bene_id using "${input_datapath_branch}/lasso_prob_snf_3folds.dta", keep(1 3) nogenerate keepusing(l_pred_prob)
// drop bene_id

compress
save "${input_datapath}/ax_weekpanel_`g'yrs.dta", replace // should have about 113M observations
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
gen nosurvive = (!missing(death_dt) & test <= 365*3)
bys index_id response_id: ereplace nosurvive = max(nosurvive) 
drop test 

compress
save "${input_datapath}/ax_weekpanel_`g'yrs.dta", replace 

********************************************************************************/



***** Main regression
use "${input_datapath}/ax_weekpanel_`g'yrs.dta", clear

	
// aggregate to monthly level 
gen reltime_months = floor(reltime_weeks/12) // in quarters
gen workingdate = eventdate_index + 90*reltime_months
gen wknum = month(workingdate)
cap drop year 
gen year = year(workingdate)
// replace year = year - 1 if treated == 0 
gen ym = ym(year, wknum)
gen treated_post = (treated == 1 & reltime_weeks >= 0)

// keep only households where outcome spouse lives for at least a year post-event
drop if nosurvive == 1

gen tt = reltime_months + 3 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 3 = 2)
keep if inrange(reltime_months, -4, 12) 
replace tt = 2 if reltime_months <= -4 // additional reference point for regression

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
reghdfe `1' ib2.tt##i.treated, ///
	absorb(eventid ym) cluster(hhid)

// make figure			
regsave , ci
keep if strpos(var, ".tt#1.treated")
cap drop if strpos(var, "o.")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 3
local newobs = _N + 1
di `newobs'
set obs `newobs'
replace reltime = -1 in `newobs'
foreach v of varlist coef ci_* {
	replace `v' = 0 in `newobs'
}
gsort reltime

// keep if abs(reltime) <= 4
twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime, color(ebblue)) , ///
	xline(-0.25, lpattern(dash)) legend(off) ///
	yline(0) ///
	xtitle("Quarters Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, Relative to Baseline Mean (`textmean'/1,000)", ///
		position(11) justification(left) size(medsmall)) 
graph save "${hoaglandoutput}/LongRunEventStudy_`1'_${today}_`g'yrs.gph", replace
graph export "${hoaglandoutput}/LongRunEventStudy_`1'_${today}_`g'yrs.png", as(png) replace
graph export "${hoaglandoutput}/LongRunEventStudy_`1'_${today}_`g'yrs.pdf", as(pdf) replace
********************************************************************************

