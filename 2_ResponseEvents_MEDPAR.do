/*******************************************************************************
* Title: Response events (MEDPAR) 
* Created by: Alex Hoagland
* Created on: 9/21/2023
* Last modified on: 2/7/2024
* Last modified by: 
* Purpose: This file pulls all response claims 


* NOTES:

*******************************************************************************/


***** 1. Organize response events***********************************************
clear

gen year = .
save "${input_datapath}/responseevents-MEDPAR.dta", replace

forvalues year = 2008/2017 {
	
	display "***** WORKING ON YEAR `year' *****"
	// quietly {
	use orgnpinm bene_id sex age* race* admsndt ad_dgns dgnscd* sslssnf ds* drg* prvdrnum using /disk/aging/medicare/data/harm/100pct/med/`year'/med`year', clear

	// demographics ultimately used for regression prediction
	gen fem = (sex == "2")
	gen year = `year' 
	// merge in predicted probability of SNF discharge
	levelsof race, local(allrace) 
	foreach r of local allrace { 
		gen dummy_`r' = (race == "`r'")
	}
	destring drg_cd, replace
		
	gen hospitalization = (sslssnf != "N") // hospitalization
	gen snf = (sslssnf == "N") // snf stay 
	gen hosp_2snf = (dstntncd == "03")
	gen hosp_2home = (dstntncd == "01")
	
	// identiy externl injury
	gen ext_injury = 0
	foreach var of varlist dgnscd1-dgnscd5 {
		replace ext_injury = 1 if inlist(substr(`var', 1, 1), "E", "S", "T") 
		// Starting with E for ICD 9 and starting with S or T for ICD 10 (reference: ICD9Data.com, ICD10Data.com)
	}
	bysort bene_id admsndt year: ereplace ext_injury = max(ext_injury)
	
	gen heart_stroke = ((inlist(substr(ad_dgns,1, 3), "410", "I21", "I63", "433", "434")))
	gen heart_stroke2 = heart_stroke
	replace heart_stroke2 = 1 if inlist(substr(ad_dgns, 1, 2),  "I6", "43") // broader definition of strokes
	
	// identify ADRD-related events
	// uses the Bynum-standard algorithm (see https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9159666/#sup1)
	// use ad_dgns and dgnscd1 (which often overlap) to identify these
	gen adrd_admit = 0
	replace adrd_admit = 1 if inlist(ad_dgns, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | /// 
		inlist(ad_dgns, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
		inlist(ad_dgns, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
		inlist(ad_dgns, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
		inlist(ad_dgns, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
		inlist(ad_dgns, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
		inlist(ad_dgns, "R4181")
	replace adrd_admit = 1 if inlist(dgnscd1, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | /// 
		inlist(dgnscd1, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
		inlist(dgnscd1, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
		inlist(dgnscd1, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
		inlist(dgnscd1, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
		inlist(dgnscd1, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
		inlist(dgnscd1, "R4181")
		
	gen adrd_disc = 0
	forvalues i = 1/10 {
		replace adrd_disc = 1 if inlist(dgnscd`i', "3310", "33111", "33119", "3312", "3317", "33182", "33189") | /// 
			inlist(dgnscd1, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(dgnscd1, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(dgnscd1, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(dgnscd1, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(dgnscd1, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(dgnscd1, "R4181")
	}
			
	rename admsndt response_eventdt
	bys bene_id response_eventdt year : egen response_ds = max(dschrgdt) 
	
	destring orgnpinm, replace force
	gcollapse (max) response_ds hosp* snf adrd_* fem ext_injury heart_stroke* ///
		(first) drg_cd (firstnm) response_orgnpi=orgnpinm, ///
			by(bene_id response_eventdt year) fast 
		// just need a dummy for each response event 
	
	append using "${input_datapath}/responseevents-MEDPAR.dta"
	save "${input_datapath}/responseevents-MEDPAR.dta", replace
	// }
} 

compress
save "${input_datapath}/responseevents-MEDPAR.dta", replace
*******************************************************
