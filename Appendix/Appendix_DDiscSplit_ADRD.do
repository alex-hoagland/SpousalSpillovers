/*******************************************************************************
* Title: Difference in discontinuitites estimator estimating effect of cutoff on SNF stays
	- are there differences based on ADRD status at time of admission?
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 4/29/2025
* Last modified by:
* Purpose: additional files make the Appendix histograms and run event studies

* NOTES:

*******************************************************************************/

capture confirm file "${input_datapath}/ADRDdx.dta"
if _rc {
	display "***** CREATING ADRD DIAGNOSIS FILE *****"
	***** Identify ADRD diagnoses
	clear
	gen year = .
	save "${input_datapath}/ADRDdx.dta", replace

	// loop through years: start with inpatient claims
	forvalues year = 2010/2017 {

		display "***** WORKING ON YEAR `year' *****"

		use fac_type bene_id from_dt icd_dgns_cd* using /disk/aging/medicare/data/harm/20pct/ip/`year'/ipc`year' if /// Inpatient claims data, using Bynum-standard algorithm for ADRD (see https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9159666/#sup1)
		inlist(icd_dgns_cd1, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd1, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd1, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd1, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd1, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd1, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd1, "R4181") | ///
			inlist(icd_dgns_cd2, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd2, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd2, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd2, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd2, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd2, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd2, "R4181") | ///
			inlist(icd_dgns_cd3, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd3, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd3, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd3, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd3, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd3, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd3, "R4181") | ///
			inlist(icd_dgns_cd4, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd4, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd4, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd4, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd4, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd4, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd4, "R4181") | ///
			inlist(icd_dgns_cd5, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd5, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd5, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd5, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd5, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd5, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd5, "R4181"), clear
		gen test = 1
		gen snfdx = (fac_type == "2" | fac_type == "3" )
		gcollapse (max) test snfdx, by(bene_id from_dt) fast
		drop test

		append using "${input_datapath}/ADRDdx.dta"
		save "${input_datapath}/ADRDdx.dta", replace
	}

		// do the same with the outpatient files
	forvalues year = 2010/2017 {
		display "***** WORKING ON OUTPATIENT YEAR `year' *****"
		use fac_type bene_id thru_dt icd_dgns_cd* using /disk/aging/medicare/data/harm/20pct/op/`year'/opc`year' if  ///
			inlist(icd_dgns_cd1, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd1, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd1, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd1, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd1, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd1, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd1, "R4181") | ///
			inlist(icd_dgns_cd2, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd2, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd2, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd2, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd2, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd2, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd2, "R4181") | ///
			inlist(icd_dgns_cd3, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd3, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd3, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd3, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd3, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd3, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd3, "R4181") | ///
			inlist(icd_dgns_cd4, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd4, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd4, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd4, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd4, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd4, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd4, "R4181") | ///
			inlist(icd_dgns_cd5, "3310", "33111", "33119", "3312", "3317", "33182", "33189") | ///
			inlist(icd_dgns_cd5, "2900", "29010", "29011", "29012", "29013", "29020", "29021") | ///
			inlist(icd_dgns_cd5, "2903", "29040", "29041", "29042", "29043", "2908", "2940") | ///
			inlist(icd_dgns_cd5, "29410", "29411", "29420", "29421", "797", "F0150", "F0151") | ///
			inlist(icd_dgns_cd5, "F0280", "F0281", "F0390", "F0391", "F04", "G300", "G301") | ///
			inlist(icd_dgns_cd5, "G308", "G309", "G3101", "G3109", "G3183", "G311", "G312") | ///
			inlist(icd_dgns_cd5, "R4181") , clear
		gen snfdx = (fac_type == "2" | fac_type == "3" )
		gen test = 1
		rename thru_dt from_dt
		gcollapse (max) test snfdx, by(bene_id from_dt) fast
		append using "${input_datapath}/ADRDdx.dta"
		replace test = 1
		gcollapse (max) test snfdx, by(bene_id from_dt) fast
		save "${input_datapath}/ADRDdx.dta", replace
	}

	compress
	save "${input_datapath}/ADRDdx.dta", replace
}
********************************************************************************


***** Merge this into the RD data
keep bene_id test
// use bene_id test using "${input_datapath}/ADRDdx.dta", clear
gcollapse (max) hasadrd=test, by(bene_id) fast // 1m individuals
rename bene_id response_id

merge 1:m response_id using  "${input_datapath}/RDdata.dta", keep(2 3) nogenerate
replace hasadrd = 0 if missing(hasadrd) // about 6% of this sample has the flag on
********************************************************************************


// pooled estimates
preserve
gen t = day - 1
// first: RD estimate for control group and treatment group pre-event
gen day_c = t - 21 // day 0 is the first day Medicare doesn't pay in full
// rdrobust insnf day_c if treated_post == 0 // estimate is -.014***, h = 11.220
gen wgt = 1 - abs(day_c)/11.22 if abs(day_c) < 11.22
// gen wgt2 = 1 - abs(day_c)/8.474 if abs(day_c) < 8.474 // for second RD below
cap drop past_cutoff
gen past_cutoff = (day_c >= 0)
gen inter1 = day_c * past_cutoff
foreach v of varlist day_c past_cutoff inter1 {
	gen inter2_`v' = treated_post * `v'
}

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 [pw=wgt], absorb(eventid ym)
	global b_rdpre_2: di %4.3fc e(b)[1,2]
	global se_rdpre_2: di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpre_2 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpre_2 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpre_2 "*"
	}
	else {
		global p_rdpre_2 ""
	}

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], absorb(eventid ym)
	global b_rdpost_2: di %4.3fc e(b)[1,2]
	global se_rdpost_2: di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpost_2 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpost_2 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpost_2 "*"
	}
	else {
		global p_rdpost_2 ""
	}

reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 [pw=wgt], absorb(eventid ym) //
	global b_dd_2: di %4.3fc e(b)[1,6]
	global se_dd_2: di %5.4fc sqrt(e(V)[6,6])
	global N_2: di %8.0fc e(N)
	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
		global p_dd_2 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
		global p_dd_2 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
		global p_dd_2 "*"
	}
	else {
		global p_dd_2 ""
	}
restore
********************************************************************************


***** group specific estimates
forvalues g = 0/1 {
	preserve

	keep if hasadrd == `g'

	gen t = day - 1

	// first: RD estimate for control group and treatment group pre-event
	gen day_c = t - 21 // day 0 is the first day Medicare doesn't pay in full
	// rdrobust insnf day_c if treated_post == 0 // estimate is -.014***, h = 11.220
	gen wgt = 1 - abs(day_c)/11.22 if abs(day_c) < 11.22
	// gen wgt2 = 1 - abs(day_c)/8.474 if abs(day_c) < 8.474 // for second RD below
	cap drop past_cutoff
	gen past_cutoff = (day_c >= 0)
	gen inter1 = day_c * past_cutoff
	foreach v of varlist day_c past_cutoff inter1 {
		gen inter2_`v' = treated_post * `v'
	}

// 	reghdfe r day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 [pw=wgt], noabsorb // this replicates rdrobust
// 		global b_rdpre_1: di %4.3fc e(b)[1,2]
// 		global se_rdpre_1: di %5.4fc sqrt(e(V)[2,2])

	reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 [pw=wgt], absorb(eventid ym)
	global b_rdpre_2_fem`g': di %4.3fc e(b)[1,2]
	global se_rdpre_2_fem`g': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpre_2_fem`g' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpre_2_fem`g' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpre_2_fem`g' "*"
	}
	else {
		global p_rdpre_2_fem`g' ""
	}

	// second: RD estimate for treatment group post-event
	// rdrobust insnf day_c if treated_post == 1 // estimate is -.007 (p = 0.104), h = 10.827
// 	reghdfe r day_c past_cutoff inter1 dow_* if abs(day_c) <=10.827 & treated_post == 1 [pw=wgt], noabsorb
// 		global b_rdpost_1: di %4.3fc e(b)[1,2]
// 		global se_rdpost_1: di %5.4fc sqrt(e(V)[2,2])

	reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], absorb(eventid ym)
	global b_rdpost_2_fem`g': di %4.3fc e(b)[1,2]
	global se_rdpost_2_fem`g': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpost_2_fem`g' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpost_2_fem`g' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpost_2_fem`g' "*"
	}
	else {
		global p_rdpost_2_fem`g' ""
	}

	// differences in discontinuities estimator
// 	reghdfe r day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 [pw=wgt], noabsorb // without FEs, p =0.293
// 		global b_dd_1: di %4.3fc e(b)[1,6]
// 		global se_dd_1: di %5.4fc sqrt(e(V)[6,6])
// 		global N_1: di %8.0fc e(N)

	// with FEs (person + year-month of event)
	reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 [pw=wgt], absorb(eventid ym) //
	global b_dd_2_fem`g': di %4.3fc e(b)[1,6]
	global se_dd_2_fem`g': di %5.4fc sqrt(e(V)[6,6])
	global N_2_fem`g': di %8.0fc e(N)
	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
		global p_dd_2_fem`g' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
		global p_dd_2_fem`g' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
		global p_dd_2_fem`g' "*"
	}
	else {
		global p_dd_2_fem`g' ""
	}
	********************************************************************************

	restore
}

***** Make the table in texdoc
texdoc init "$hoaglandoutput/D-DiscTable_byADRD.tex", replace force
tex \begin{table}[htb]
tex \centering
tex \caption{\label{tab:ddisc} Effects of Shock Spouse Health Event on Outcome Spouse's Price Sensitivity for SNF Stay Decision, by Outcome Spouse ADRD Status}
tex \begin{threeparttable}
tex \begin{tabular}{@{}p{\textwidth}@{}}
tex \centering
tex \begin{tabular}{lc|cc}
tex \toprule
tex & (1) & (2) & (3) \\
tex & Pooled & No ADRD & Has ADRD  \\
tex \midrule
tex \$\tau_{\text{pre}}\$ & ${b_rdpre_2}${p_rdpre_2} & ${b_rdpre_2_fem0}${p_rdpre_2_fem0} & ${b_rdpre_2_fem1}${p_rdpre_2_fem1} \\
tex & (${se_rdpre_2}) & (${se_rdpre_2_fem0}) & (${se_rdpre_2_fem1}) \\
tex \$\tau_{\text{post}}\$ & ${b_rdpost_2}${p_rdpost_2}  & ${b_rdpost_2_fem0}${p_rdpost_2_fem0} & ${b_rdpost_2_fem1}${p_rdpost_2_fem1} \\
tex & (${se_rdpost_2}) & (${se_rdpost_2_fem0}) & (${se_rdpost_2_fem1}) \\
tex \\
tex \$\beta_{\text{D-Disc}}\$ & ${b_dd_2}${p_dd_2} & ${b_dd_2_fem0}${p_dd_2_fem0}  & ${b_dd_2_fem1}${p_dd_2_fem1} \\
tex & (${se_dd_2}) & (${se_dd_2_fem0}) & (${se_dd_2_fem1}) \\
tex \\
tex Couple FEs & \checkmark  & \checkmark & \checkmark \\
tex Time FEs & \checkmark & \checkmark & \checkmark \\
tex Bandwidth & 11.22 & 11.22 & 11.22 \\
tex \$N\$ & $N_2 & $N_2_fem0 & $N_2_fem1 \\
tex \bottomrule
tex \end{tabular}
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table presents regression-discontinuity and differences-in-discontinuities estimators identifying the effect of ending Medicare coverage for SNF stays, which ends on day 21 for qualifying stays. The first two rows present the estimated effect of losing coverage on the probability a outcome spouse will remain in the SNF, stratified by before or after the index event. The third row presents the difference-in-discotinuities estimator as discussed in the text. SNF stays within 4 months of the treatment and placebo events are included in the regression. Columns are stratified based on whether the outcome spouse has an ADRD diagnosis in claims (6.2\% of the sample) or not.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}
texdoc close
********************************************************************************






/*
gen t = day - 1
reg insnf t dow* if inrange(t, 21-5.039,20) & treated == 0
predict p0 if inrange(t, 21-5.039 , 21+5.039 ) & treated == 0, xb
gen r_snf0 = insnf - p0
reg insnf t dow* if inrange(t, 21-5.039,20) & treated == 1
predict p1 if inrange(t, 21-5.039 , 21+5.039 ) & treated == 1, xb
gen r_snf1 = insnf - p1
gen r = r_snf0 if treated == 0
replace r = r_snf1 if treated == 1

// first: RD estimate for control group and treatment group pre-event
gen day_c = t - 21 // day 0 is the first day Medicare doesn't pay in full
// rdrobust insnf day_c if treated_post == 0 // estimate is -.014***, h = 11.220
gen wgt = 1 - abs(day_c)/11.22 if abs(day_c) < 11.22
// gen wgt2 = 1 - abs(day_c)/8.474 if abs(day_c) < 8.474 // for second RD below
cap drop past_cutoff
gen past_cutoff = (day_c >= 0)
gen inter1 = day_c * past_cutoff
foreach v of varlist day_c past_cutoff inter1 {
	gen inter2_`v' = treated_post * `v'
}

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 & hasadrd == 0 [pw=wgt], absorb(eventid ym)
// 	global b_rdpre_1: di %4.3fc e(b)[1,2]
// 	global se_rdpre_1: di %5.4fc sqrt(e(V)[2,2])
// 	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
// 		global p_rdpre_1 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
// 		global p_rdpre_1 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
// 		global p_rdpre_1 "*"
// 	}
// 	else {
// 		global p_rdpre_1 ""
// 	}

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 & hasadrd == 1 [pw=wgt], absorb(eventid ym)
// 	global b_rdpre_2: di %4.3fc e(b)[1,2]
// 	global se_rdpre_2: di %5.4fc sqrt(e(V)[2,2])
// 	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
// 		global p_rdpre_2 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
// 		global p_rdpre_2 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
// 		global p_rdpre_2 "*"
// 	}
// 	else {
// 		global p_rdpre_2 ""
// 	}

// second: RD estimate for treatment group post-event
// rdrobust insnf day_c if treated_post == 1 // estimate is -.007 (p = 0.104), h = 10.827
reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 & hasadrd ==0 [pw=wgt], absorb(eventid ym)
// 	global b_rdpost_1: di %4.3fc e(b)[1,2]
// 	global se_rdpost_1: di %5.4fc sqrt(e(V)[2,2])
// 	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
// 		global p_rdpost_1 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
// 		global p_rdpost_1 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
// 		global p_rdpost_1 "*"
// 	}
// 	else {
// 		global p_rdpost_1 ""
// 	}

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 & hasadrd == 1 [pw=wgt], absorb(eventid ym)
// 	global b_rdpost_2: di %4.3fc e(b)[1,2]
// 	global se_rdpost_2: di %5.4fc sqrt(e(V)[2,2])
// 	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
// 		global p_rdpost_2 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
// 		global p_rdpost_2 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
// 		global p_rdpost_2 "*"
// 	}
// 	else {
// 		global p_rdpost_2 ""
// 	}

// differences in discontinuities estimator
reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 & hasadrd==0 [pw=wgt], absorb(eventid ym) //
// 	global b_dd_1: di %4.3fc e(b)[1,6]
// 	global se_dd_1: di %5.4fc sqrt(e(V)[6,6])
// 	global N_1: di %8.0fc e(N)
// 	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
// 		global p_dd_1 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
// 		global p_dd_1 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
// 		global p_dd_1 "*"
// 	}
// 	else {
// 		global p_dd_1 ""
// 	}

// with FEs (person + year-month of event)
reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 & hasadrd==1 [pw=wgt], absorb(eventid ym) //
// 	global b_dd_2: di %4.3fc e(b)[1,6]
// 	global se_dd_2: di %5.4fc sqrt(e(V)[6,6])
// 	global N_2: di %8.0fc e(N)
// 	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
// 		global p_dd_2 "***"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
// 		global p_dd_2 "**"
// 	}
// 	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
// 		global p_dd_2 "*"
// 	}
// 	else {
// 		global p_dd_2 ""
// 	}
********************************************************************************


***** Make the table in texdoc
// texdoc init "$hoaglandoutput/D-DiscTable.tex", replace force
// tex \begin{table}[htb]
// tex \centering
// tex \caption{\label{tab:ddisc} Effects of Index Spouse Health Event on Focal Spouse's Price Sensitivity for SNF Stay Decision}
// tex \begin{threeparttable}
// tex \begin{tabular}{@{}p{\textwidth}@{}}
// tex \centering
// tex \begin{tabular}{lcc}
// tex \toprule
// tex & (1) & (2) \\
// tex \midrule
// tex \$\tau_{\text{pre}}\$ & ${b_rdpre_1}${p_rdpre_1} & ${b_rdpre_2}${p_rdpre_1} \\
// tex & (${se_rdpre_1}) & (${se_rdpre_2}) \\
// tex \$\tau_{\text{post}}\$ & ${b_rdpost_1}${p_rdpost_1} & ${b_rdpost_2}${p_rdpost_1} \\
// tex & (${se_rdpost_1}) & (${se_rdpost_2}) \\
// tex \\
// tex \$\beta_{\text{D-Disc}}\$ & ${b_dd_1}${p_dd_1} & ${b_dd_2}${p_dd_2} \\
// tex & (${se_dd_1}) & (${se_dd_2}) \\
// tex \\
// tex Couple FEs & & \checkmark \\
// tex Time FEs & & \checkmark \\
// tex Bandwidth & 11.22 & 11.22 \\
// tex \$N\$ & $N_1 & $N_2 \\
// tex \bottomrule
// tex \end{tabular}
// tex \end{tabular}
// tex \begin{tablenotes}
// tex \small
// tex \item \textit{Notes}: This table presents regression-discontinuity and differences-in-discontinuities estimators identifying the effect of ending Medicare coverage for SNF stays, which ends on day 21 for qualifying stays. The first two rows present the estimated effect of losing coverage on the probability a focal spouse will remain in the SNF, stratified by before or after the index event. The third row presents the difference-in-discotinuities estimator as discussed in the text. SNF stays within 4 months of the treatment and placebo events are included in the regression.
// tex \end{tablenotes}
// tex \end{threeparttable}
// tex \end{table}
// texdoc close
********************************************************************************
