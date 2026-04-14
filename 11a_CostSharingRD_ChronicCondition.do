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

use "${input_datapath}/RDdata.dta", clear


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
bys response_id eventid: ereplace any_chronic = max(any_chronic) // ~63% of sample
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
	
	keep if any_chronic == `g'

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
texdoc init "$hoaglandoutput/D-DiscTable_byChronicCondition.tex", replace force
tex \begin{table}[htb]
tex \centering
tex \caption{\label{tab:ddisc} Effects of Shock Spouse Health Event on Outcome Spouse's Price Sensitivity for SNF Stay Decision, by Outcome Spouse Chronic Condition Status}
tex \begin{threeparttable}
tex \begin{tabular}{@{}p{\textwidth}@{}}
tex \centering
tex \begin{tabular}{lc|cc}
tex \toprule
tex & (1) & (2) & (3) \\
tex & Pooled & No Chronic Condition & Has Chronic Condition  \\ 
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
tex \item \textit{Notes}: This table presents regression-discontinuity and differences-in-discontinuities estimators identifying the effect of ending Medicare coverage for SNF stays, which ends on day 21 for qualifying stays. The first two rows present the estimated effect of losing coverage on the probability a outcome spouse will remain in the SNF, stratified by before or after the index event. The third row presents the difference-in-discotinuities estimator as discussed in the text. SNF stays within 4 months of the treatment and placebo events are included in the regression. Columns are stratified based on whether the outcome spouse has a chronic condition in claims (63\% of the sample) or not in the year prior to the index event. 
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}
texdoc close 
********************************************************************************
