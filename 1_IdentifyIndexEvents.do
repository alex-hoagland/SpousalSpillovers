/*******************************************************************************
* Title: Identify Focal Events based on MEDPAR file 
* Created by: Alex Hoagland
* Created on: 9/21/2023
* Last modified on: 11/4/2024
* Last modified by: 
* Purpose: This file pulls all MEDPAR hospitalization events as index events. 

* NOTES: 

*******************************************************************************/


******* 1. Pull index events *************
clear

gen year = .
save "${input_datapath}/indexevents.dta", replace	

// loop through years: start with inpatient claims 
forvalues year = 2008/2017 { // note: we start with 2008 to have a lookback period before index events -- first "treated" event will be in 2011
	
	display "***** WORKING ON YEAR `year' *****"
	use bene_id sex admsndt admsnday sslssnf ad_dgns dschrg* dgnscd1 dgnscd2 dgnscd3 dgnscd4 dgnscd5 dstntncd if sslssnf != "N" /// don't pull SNF stays as index events 
		using /disk/aging/medicare/data/harm/100pct/med/`year'/med`year', clear 
	gen female = (sex == "2")
	gen year = `year'
	
	append using "${input_datapath}/indexevents.dta"
	save "${input_datapath}/indexevents.dta", replace
} // there are ~150M events here
********************************************************************************


***** 2. Classify index events based on severity
use "${input_datapath}/indexevents.dta", clear 
// merge in death dates using bsf files 
gen deathdate = .
forvalues y = 2011/2017 { // note: only need death dates for these years since we will focus on index events between 2011 and 2016 
	display "***** WORKING ON YEAR `y' *****"
	merge m:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsf/`y'/bsfab`y'.dta, ///
		keep(1 3) nogenerate keepusing(bene_id death_dt)
	replace deathdate = death_dt if missing(deathdate) & !missing(death_dt)
	drop death_dt
}
	
// now classify 
rename admsndt eventdate_index
gen fatal_disc = dschrgcd == "B"
gen fatal_30days = (!missing(deathdate) & (deathdate - eventdate_index) <= 30)
gen fatal_90days = (!missing(deathdate) & (deathdate - eventdate_index) <= 90)
gen fatal_1year = (!missing(deathdate) & (deathdate - eventdate_index) <= 365)
gen fatal_2years = (!missing(deathdate) & (deathdate - eventdate_index) <= 365*2)
gen fatal_3years = (!missing(deathdate) & (deathdate - eventdate_index) <= 365*3)
replace fatal_3years = . if year(eventdate_index) >= 2015 // don't have 3-year followup
gen nonfatal_tosnf = (fatal_disc == 0 & inlist(dstntncd, "03")) 
gen nonfatal_torehab = (fatal_disc == 0 & inlist(dstntncd, "62")) 
gen nonfatal_tohome = (fatal_disc == 0 & inlist(dstntncd, "01", "06", "08")) // note: includes home health 
gen los = (dschrgdt - eventdate_index + 1)

// classify whether or not the hospitalization included ADRD 
gen adrd_admit = 0
	replace adrd_admit = 1 if inlist(ad_dgns, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | /// 
		inlist(ad_dgns, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
		inlist(ad_dgns, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
		inlist(ad_dgns, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
		inlist(ad_dgns, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
		inlist(ad_dgns, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
		inlist(ad_dgns, "R4181")
		forvalues i = 1/5 {
	replace adrd_admit = 1 if inlist(dgnscd`i', "3310", "33111", "33119", "3312", "3317", "33182", "33189") | /// 
		inlist(dgnscd`i', "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
		inlist(dgnscd`i', "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
		inlist(dgnscd`i', "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
		inlist(dgnscd`i', "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
		inlist(dgnscd`i', "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
		inlist(dgnscd`i', "R4181")
		} // about 5% of all events
		
compress
save "${input_datapath}/indexevents.dta", replace // no events have been deleted here. 
********************************************************************************


***** ADDED 5.20.2025: For those who are discharged to facility, identify the organization NPI
use "${input_datapath}/indexevents.dta" if nonfatal_tosnf == 1, clear
bys bene_id (eventdate_index): gen i = _n 
keep if i <= 10 // keeps 99% of data
keep bene_id eventdate_index i 
reshape wide eventdate_index, i(bene_id) j(i)

compress
save "$input_datapath/tomerge.dta", replace 

clear
gen orgnpinm = . 
save "${input_datapath}/tomerge_snf.dta", replace

forvalues year = 2008/2017 { 
	
	display "***** WORKING ON YEAR `year' *****"
	// quietly {
	use orgnpinm bene_id admsndt sslssnf using /disk/aging/medicare/data/harm/100pct/med/`year'/med`year' if sslssnf == "N", clear // SNF stays only
	drop sslssnf
	
	merge m:1 bene_id using "$input_datapath/tomerge.dta", keep(3) nogenerate
	bys bene_id (admsndt): gen i = _n 
	reshape long eventdate_index, i(bene_id admsndt i) j(j)
	drop if missing(eventdate_index) 
	keep if inrange(admsndt, eventdate_index, eventdate_index + 90) 
	drop i j
	gen elapse = admsndt - eventdate_index
	bys bene_id eventdate_index: egen test = min(elapse) 
	keep if test == elapse
	drop test elapse
	keep bene_id eventdate_index orgnpinm
	bys bene_id eventdate_index: keep if _n == 1 // drops < 1% of cases here 			
	destring orgnpinm, replace force
	append using "${input_datapath}/tomerge_snf.dta"
	save "${input_datapath}/tomerge_snf.dta", replace
	// }
} 

use "${input_datapath}/tomerge_snf.dta", clear
bys bene_id eventdate_index: keep if _n == 1 // ignore spillover across years
merge 1:m bene_id eventdate_index using "${input_datapath}/indexevents.dta", keep(2 3) nogenerate
save "${input_datapath}/indexevents.dta", replace

rm "$input_datapath/tomerge.dta" 
rm "${input_datapath}/tomerge_snf.dta"
********************************************************************************
