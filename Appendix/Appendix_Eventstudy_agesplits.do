 /*******************************************************************************
* Title: Run event study split by age of shock spouse, response spouse, and age
	difference
* Created by: Prabidhik KC
* Created on: 2/8/24
* Last modified on: 05/20
* Last modified by:
* Purpose: This file makes figures -- can be edited to impose restrictions

*******************************************************************************/
********************************************************************************
***** Main Regression
// TODO: include code generating the chars_weekpanel data set with age differences for spouses (doesn't matter here because this will be done in the MDS version of the file)
// use "/disk/agedisk3/medicare.work/layton-DUA54204/WorkingDatasets/Replication_Package/output_dataset/ReplicationData_branch/chars_weekpanel.dta", clear
use "${input_datapath}/weekpanel.dta", clear

preserve
keep index_id response_id eventdate_index
duplicates drop
gen file_year = year(eventdate_index) - 1
tempfile eventpairs
save `eventpairs', replace
restore

preserve
use `eventpairs', clear
keep index_id file_year
duplicates drop
rename index_id bene_id
tempfile index_ages
save `index_ages', replace
restore

preserve
use `index_ages', clear
levelsof file_year, local(index_years)
clear
gen bene_id = ""
gen file_year = .
gen index_age = .
tempfile index_age_lookup
save `index_age_lookup', replace
foreach y of local index_years {
	use bene_id age if year == `y' using /disk/aging/medicare/data/harm/100pct/bsfab/`y'/bsfab`y'.dta, clear
	rename age index_age
	gen file_year = `y'
	append using `index_age_lookup'
	save `index_age_lookup', replace
}
use `index_age_lookup', clear
rename bene_id index_id
save `index_age_lookup', replace
restore

preserve
use `eventpairs', clear
keep response_id file_year
duplicates drop
rename response_id bene_id
tempfile response_ages
save `response_ages', replace
restore

preserve
use `response_ages', clear
levelsof file_year, local(response_years)
clear
gen bene_id = ""
gen file_year = .
gen response_age = .
tempfile response_age_lookup
save `response_age_lookup', replace
foreach y of local response_years {
	use bene_id age if year == `y' using /disk/aging/medicare/data/harm/100pct/bsfab/`y'/bsfab`y'.dta, clear
	rename age response_age
	gen file_year = `y'
	append using `response_age_lookup'
	save `response_age_lookup', replace
}
use `response_age_lookup', clear
rename bene_id response_id
save `response_age_lookup', replace
restore

merge m:1 index_id response_id eventdate_index using `eventpairs', keep(3) nogenerate
rename file_year lookup_year
merge m:1 index_id lookup_year using `index_age_lookup', keep(1 3) nogenerate update replace
merge m:1 response_id lookup_year using `response_age_lookup', keep(1 3) nogenerate update replace
rename lookup_year file_year
gen age_diff = index_age - response_age if !missing(index_age) & !missing(response_age)

keep if inrange(age_diff, -20, 20)

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
if ("`2'" == "balanced" ) { 
	drop if nosurvive == 1
}

gen tt = reltime_months + 4 // makes regression code easier to have no negative values here -- note that 3 is now the base period (-1 + 4 = 3)
keep if inrange(reltime_months, -5, 12)
replace tt = 3 if reltime_months <= -5 // additional reference point for regression

// splits for each group
xtile split_index = index_age, nq(2)
xtile split_response = response_age, nq(2)
xtile split_gap = age_diff, nq(2)

gcollapse (max) `1' treated* split_* index_fem, by(index_id hhid eventid ym tt reltime_months ) fast
********************************************************************************


***** 1. Split by shock spouse age
preserve

sum `1' if (split_index == 1 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_1: di %3.1fc `r(mean)' * 1000

sum `1' if (split_index == 2 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_2: di %3.1fc `r(mean)' * 1000

sum `1' if (treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

reghdfe `1' ib3.tt##i.treated if split_index == 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age1.dta", replace ci p

// run regression: above median
reghdfe `1' ib3.tt##i.treated if split_index == 2, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age2.dta", replace ci p

use "$input_datapath/figdata_age1.dta", clear
gen model = 1
append using "$input_datapath/figdata_age2.dta"
replace model = 2 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
set obs `newobs'
replace reltime = -1 if missing(reltime)
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v')
}

gsort model reltime
replace model = 1 in `newobs'
replace model = 2 if missing(model)

replace reltime = reltime - 0.15 if model == 1
replace reltime = reltime + 0.15 if model == 2

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue)) ///
	(scatter coef reltime if model == 2, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0, lcolor(black)) ///
	legend(order(2 "Index Spouse Age Below Median (Baseline mean = `textmean_1' per 1000)" 3 "Index Spouse Age Above Median (Baseline mean = `textmean_2' per 1000)") ///
		position(11) ring(0) rows(2)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack or Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12)
graph save "${hoaglandoutput}/Stratify_IndexSpouseAgeDifference_`1'_${today}_balanced.gph", replace
graph export "${hoaglandoutput}/Stratify_IndexSpouseAgeDifference_`1'_${today}_balanced.png", as(png) replace
graph export "${hoaglandoutput}/Stratify_IndexSpouseAgeDifference_`1'_${today}_balanced.pdf", as(pdf) replace
restore
********************************************************************************

***** 2. Split by outcome spouse age
preserve

sum `1' if (split_response == 1 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_1: di %3.1fc `r(mean)' * 1000

sum `1' if (split_response == 2 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_2: di %3.1fc `r(mean)' * 1000

sum `1' if (treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

reghdfe `1' ib3.tt##i.treated if split_response == 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age1.dta", replace ci p

// run regression: above median
reghdfe `1' ib3.tt##i.treated if split_response == 2, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age2.dta", replace ci p

use "$input_datapath/figdata_age1.dta", clear
gen model = 1
append using "$input_datapath/figdata_age2.dta"
replace model = 2 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
set obs `newobs'
replace reltime = -1 if missing(reltime)
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v')
}

gsort model reltime
replace model = 1 in `newobs'
replace model = 2 if missing(model)

replace reltime = reltime - 0.15 if model == 1
replace reltime = reltime + 0.15 if model == 2

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue)) ///
	(scatter coef reltime if model == 2, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0, lcolor(black)) ///
	legend(order(2 "Outcome Spouse Age Below Median (Baseline mean = `textmean_1' per 1000)" 3 "Outcome Spouse Age Above Median (Baseline mean = `textmean_2' per 1000)") ///
		position(11) ring(0) rows(2)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack or Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12)
graph save "${hoaglandoutput}/Stratify_OutcomeSpouseAgeDifference_`1'_${today}_balanced.gph", replace
graph export "${hoaglandoutput}/Stratify_OutcomeSpouseAgeDifference_`1'_${today}_balanced.png", as(png) replace
graph export "${hoaglandoutput}/Stratify_OutcomeSpouseAgeDifference_`1'_${today}_balanced.pdf", as(pdf) replace
restore
********************************************************************************

***** 3. Split by age difference
preserve

sum `1' if (split_gap == 1 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_1: di %3.1fc `r(mean)' * 1000

sum `1' if (split_gap == 2 & treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean_2: di %3.1fc `r(mean)' * 1000

sum `1' if (treated == 1 & reltime_months < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

reghdfe `1' ib3.tt##i.treated if split_gap == 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age1.dta", replace ci p

// run regression: above median
reghdfe `1' ib3.tt##i.treated if split_gap == 2, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_age2.dta", replace ci p

use "$input_datapath/figdata_age1.dta", clear
gen model = 1
append using "$input_datapath/figdata_age2.dta"
replace model = 2 if missing(model)

keep if strpos(var, ".tt#1.treated")
gen reltime = substr(var, 1, 2)
destring reltime, replace
replace reltime = reltime - 4
local newobs = _N + 2
set obs `newobs'
replace reltime = -1 if missing(reltime)
foreach v of varlist coef ci_* {
	replace `v' = 0 if missing(`v')
}

gsort model reltime
replace model = 1 in `newobs'
replace model = 2 if missing(model)

replace reltime = reltime - 0.15 if model == 1
replace reltime = reltime + 0.15 if model == 2

twoway (rcap ci_lower ci_upper reltime, color(gs10)) ///
	(scatter coef reltime if model == 1, color(ebblue)) ///
	(scatter coef reltime if model == 2, color(maroon)) , ///
	xline(-0.25, lpattern(dash)) ///
	yline(0, lcolor(black)) ///
	legend(order(2 "Spousal Age Gap Below Median (Baseline mean = `textmean_1' per 1000)" 3 "Spousal Age Gap Above Median (Baseline mean = `textmean_2' per 1000)") ///
		position(11) ring(0) rows(2)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack or Stroke") ///
	xsc(r(-4(1)12)) xlab(-4(1)12)
graph save "${hoaglandoutput}/Stratify_AgeDifference_`1'_${today}_balanced.gph", replace
graph export "${hoaglandoutput}/Stratify_AgeDifference_`1'_${today}_balanced.png", as(png) replace
graph export "${hoaglandoutput}/Stratify_AgeDifference_`1'_${today}_balanced.pdf", as(pdf) replace
restore
********************************************************************************

rm "$input_datapath/figdata_age1.dta"
rm "$input_datapath/figdata_age2.dta"
