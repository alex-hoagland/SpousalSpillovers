/*******************************************************************************
* Title: Split main health effect DD by if the response spouse had a chronic condition 
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 1/10/2025
* Last modified by: Hoagland
* Purpose: 

* NOTES: 
	- update 1.10.2025 to include only conditions that likely require caregiving 
*******************************************************************************/

***** Main Regression , split by if husband has chronic condition or not 
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

// keep only households where outcome spouse lives for at least a year post-event
if ("`2'" == "balanced" ) { 
	drop if nosurvive == 1
}

//
// gen test = runiform() 
// bys index_id eventid: ereplace test = mean(test) 
// keep if (test < .5 & treated == 0) | (test >= .5 & treated == 1)

// split based on chronic conditions in year prior to (treatment or control) event 
gen rfrnc_yr = year - 1 // already has been split based on treatment/control status 
cap drop bene_id
gen bene_id = response_id
gen any_chronic = 0 
drop if rfrnc_yr < 2010 // to have sufficient lookback 
levelsof rfrnc_yr, local(allyears) 
cap drop file_year
foreach y of local allyears { 
	di "***** YEAR = `y' ***** "
	merge m:1 bene_id rfrnc_yr using /disk/aging/medicare/data/harm/100pct/bsfcc/`y'/bsfcc`y'.dta, ///
		keep(1 3) nogenerate
	foreach v of varlist alzh chrnkidn copd ischmcht strketia cncrclrc cncrprst cncrlung  { 
		// note: a more complete list inlucded the following as well: ami anemia chf diabetes depressn osteoprs
		
		cap replace any_chronic = 1 if `v' == 3 // had claims + appropriate coverage 
		// cap replace any_chronic = 1 if !missing(`v'e) // date claims were first met (perhaps more than 1 year prior)
	} 
// 	foreach v of varlist atrialfe chrnkdne diabtese ischmche deprssne osteopre strktiae cncrclre cncrprse cncrlnge anemia_e { // catarcte glaucmae ra_oa_e asthma_e hyperl_e hypert_e hypoth_e
// 		cap replace any_chronic = 1 if !missing(`v') // date claims were first met (perhaps more than 1 year prior)
// 	}
	drop ami-file_year
}
bys response_id eventid: ereplace any_chronic = max(any_chronic) // ~40% of sample

gcollapse (max) `1' treated* any_chronic index_fem, by(index_id hhid eventid ym tt reltime_months ) fast
sum `1' if (treated == 1 & reltime_ < 0)
local premean: di %5.4fc `r(mean)'
local textmean: di %3.1fc `r(mean)' * 1000
replace `1' = `1' / `premean' // * 100 // rescale coefficients to be % of outcome

// run regression for p-value
egen ym_sex = group(ym index_fem)

reghdfe `1' ib3.tt##i.treated##any_chronic, ///
	absorb(eventid ym) cluster(hhid)
test 4bn.tt#1bn.treated#1bn.any_chronic 5bn.tt#1bn.treated#1bn.any_chronic 6bn.tt#1bn.treated#1bn.any_chronic 7bn.tt#1bn.treated#1bn.any_chronic 8bn.tt#1bn.treated#1bn.any_chronic

// run split regression: any_chronic
reghdfe `1' ib3.tt##i.treated if any_chronic == 1, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_chronic.dta", replace ci p

// run split regression: no any_chronic
reghdfe `1' ib3.tt##i.treated if any_chronic == 0, ///
	absorb(eventid ym) cluster(hhid)
regsave using "$input_datapath/figdata_nochronic.dta", replace ci p

// make figure	
use "$input_datapath/figdata_nochronic.dta", clear 
gen model = 1 
append using "$input_datapath/figdata_chronic.dta"
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
	(scatter coef reltime if model == 1, color(ebblue) msymbol(square)) ///
	(scatter coef reltime if model == 2, color(maroon) msymbol(circle)) , ///
	xline(-0.25, lpattern(dash))  ///
	yline(0) ///
	legend(order(2 "No Spousal Chronic Condition" 3 "Spouse has Chronic Condition") ///
		position(11) ring(0) cols(1)) ///
	xtitle("Months Around Shock Spouse's First Heart Attack/Stroke") ///
	xsc(r(-4(2)12)) xlab(-4(2)12) ///
	subtitle("Spillover Effect, by Spillover Spouse Health", ///
		position(11) justification(left) size(medsmall)) 
if ("`2'" == "balanced") { 
	graph save "${hoaglandoutput}/Split_ChronicCondition_`1'_balanced_$today.gph", replace
	graph export "${hoaglandoutput}/Split_ChronicCondition_`1'_balanced_$today.png", as(png) replace
	graph export "${hoaglandoutput}/Split_ChronicCondition_`1'_balanced_$today.pdf", as(pdf) replace
}
else { 
	graph save "${hoaglandoutput}/SplitEffects_ChronicCondition_`1'_$today.gph", replace
	graph export "${hoaglandoutput}/SplitEffects_ChronicCondition_`1'_$today.png", as(png) replace
	graph export "${hoaglandoutput}/SplitEffects_ChronicCondition_`1'_$today.pdf", as(pdf) replace
}
********************************************************************************

// clean up data
rm "$input_datapath/figdata_chronic.dta"
rm "$input_datapath/figdata_nochronic.dta"

