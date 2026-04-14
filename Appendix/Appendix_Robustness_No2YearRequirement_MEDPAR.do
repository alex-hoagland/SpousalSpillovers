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

****************************************************************
**** FIRST, IDENTIFY RELEVANT INDEX EVENTS ****
****************************************************************

use "${input_datapath}/indexevents.dta", clear	
rename bene_id index_id
	
rename year file_year	
foreach v of var dgnscd* ad_d dsch* admsnday sslssnf dstntncd sex los female-deathdate orgnpinm adrd_admit { 
	rename `v' index_`v' 
}
cap rename index_file_year file_year

// restrictions to impose
replace file_year = year(eventdate_index)
drop if file_year <= 2010 // need 2 full years of lookback, can only merge in spouses for 2010 and need that to be year before event
// note: will drop 2017 for treated year at the end 
// keep if inrange(file_year, 2011, 2016) // to generate treatment and control groups 
	// by this point we are down to ~37M events

drop if inlist(substr(index_ad_dgns, 1, 1), "S", "T") // no external injuries as primary diagnosis
forvalues i = 1/5 { // no external injuries in first 5 diagnoses
	drop if inlist(substr(index_dgnscd`i', 1, 1), "S", "T")
} // not a lot thrown out here -- still around 30M events

// limit to an index spouse's heart attack or stroke
gen heart_stroke = ((inlist(substr(index_ad_dgns,1, 3), "410", "I21") | inlist(substr(index_dgnscd1,1, 3), "410", "I21")))
replace heart_stroke = 1 if (inlist(substr(index_ad_dgns,1, 3), "I63", "433", "434") | inlist(substr(index_dgnscd1,1, 3), "I63", "433", "434"))
keep if heart_stroke == 1 // down to roughly 2M events between 2011 and 2016

compress
save "${input_datapath}/indexevents_base_no2y.dta", replace
********************************************************************************


****************************************************************
**** FIRST, IDENTIFY SPOUSES BASED ON PREVIOUS YEAR ****
****************************************************************

use "${input_datapath}/indexevents_base_no2y.dta", clear	

// real + placebo events 
expand 2, gen(treated)
replace file_year = file_year - 1 if treated == 0 
replace eventdate_index = eventdate_index - 365 if treated == 0 
	
// merge spouses in year *prior* to event 
gen year = file_year - 1 // note: this means the first event has to be in 2011 or later
drop if year < 2010 // don't have spousal data for these 
drop if treated == 1 & file_year == 2011 // need to drop these since they won't be in the control
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
save "${input_datapath}/indexevents_mergedspouses_no2y.dta", replace // should be about 1.2M observations with spouses identified 
*******************************************************


****************************************************************
**** SECOND, REQUIRE CONTINUOUS ENROLLMENT OF BOTH SPOUSES  ****
****************************************************************

// note: this requires spouses to be continuously enrolled between t=-1 and (real or placebo) event 
// so one year pre and post for a true event, and one year pre and post for placebo event 

// make list of bene_id and years
use "${input_datapath}/indexevents_mergedspouses_no2y.dta", clear
expand 3
gen eventyear = file_year
bys index_id response_id: replace file_year = file_year - 1 if _n == 2
bys index_id response_id: replace file_year = file_year - 2 if _n == 3 // do we need this? 
save "${input_datapath}/indexevents_mergedspouses_no2y.dta", replace


// note: this requires spouses to be continuously enrolled between t=-1 and (real or placebo) event 
// so one year pre and post for a true event, and one year pre and post for placebo event 

use "${input_datapath}/indexevents_mergedspouses_no2y.dta", clear
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

use "${input_datapath}/indexevents_mergedspouses_no2y.dta", clear
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
save "${input_datapath}/indexevents_mergedspouses_eligible__no2y.dta", replace
********************************************************************************


***** Make the panel 
use  "${input_datapath}/indexevents_mergedspouses_eligible__no2y.dta", clear
bys response_id treated: keep if _n == 1 // drops 1.2% of events (18,233)
gen bene_id = response_id
save "${input_datapath}/indexevents_mergedspouses_eligible__no2y.dta", replace

// merge in response events
use "${input_datapath}/responseevents-MEDPAR.dta", clear
expand 2, generate(treated)
merge m:1 bene_id treated using "${input_datapath}/indexevents_mergedspouses_eligible__no2y.dta", keep(3) nogenerate
// drop if ext_injury == 1 // for replication 
drop bene_id
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

gcollapse (max) snf* hosp* fem ext_injury, ///
	by(response_id index_id eventid reltime_weeks treated) fast

save "${input_datapath}/responseevents_panel_weeks_no2y.dta", replace // about 1.2M events
********************************************************************************


***** Merge back in to header **************************************************
// now merge in both treated and control groups
use "${input_datapath}/indexevents_mergedspouses_eligible__no2y.dta", clear
cap drop bene_id 
expand 105, gen(reltime_weeks)
bysort eventid: replace reltime_weeks = _n - 53
keep if inrange(reltime_weeks, -52, 52)
merge 1:1 index_id response_id eventid reltime_weeks using "${input_datapath}/responseevents_panel_weeks_no2y.dta", keep(1 3) nogenerate

// keep only opposite-sex pairs
bys index_id response_id treated: ereplace fem = max(fem)
bys index_id response_id treated: ereplace index_fem = max(index_fem)
drop if fem == 1 & index_fem == 1 
drop if fem == 0 & index_fem == 0 
drop fem // drops ~2% of sample

foreach v of var hosp* snf* fatal* nonfatal*  { // mdc* adrd* iez* { 
	replace `v' = 0 if missing(`v')
}

drop if treated == 1 & file_year == 2017 // can keep this year for control group only 

// why doesn't this merge work?
// merge in predicted SNF probability 
// gen bene_id = response_id 
// merge m:1 bene_id using "${input_datapath_branch}/lasso_prob_snf_3folds.dta", keep(1 3) nogenerate keepusing(l_pred_prob)
// drop bene_id

compress
save "${input_datapath}/weekpanel_no2y.dta", replace // should have about 113M observations
********************************************************************************/

	
***** Main Regression 
// gen todrop = (time_pre <= 365*3)
// bys index_id: ereplace todrop = max(todrop) 
// drop if todrop == 1 
// drop todrop 

	use "${input_datapath}/weekpanel_no2y.dta" , clear 
	
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

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 5 is now the base period (-1 + 6 = 5)
keep if inrange(reltime_months, -5, 12) 
replace tt = 3 if reltime_months <= -5 // additional reference points


// keep only households where outcome spouse lives for at least a year post-event
gen test = death_dt - eventdate_index
gen todrop = (!missing(death_dt) & test <= 365)
bys index_id response_id: ereplace todrop = max(todrop) 
drop if todrop == 1
drop test todrop

	gcollapse (max) snf treated* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast

sum snf if (treated == 1 & reltime_ < 0) // | treated == 0 
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace snf = snf / `premean' // * 100 // rescale coefficients to be % of outcome

// gen test = runiform() 
// bys index_id: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// run regression
reghdfe snf ib3.tt##i.treated, ///
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
graph save "${hoaglandoutput}/EventStudy_snf-no2y_$today.gph", replace
graph export "${hoaglandoutput}/EventStudy_snf-no2y_$today.png", as(png) replace
graph export "${hoaglandoutput}/EventStudy_snf-no2y_$today.pdf", as(pdf) replace
********************************************************************************
