/*******************************************************************************
* Title: Difference in discontinuitites estimator estimating effect of cutoff on SNF stays -- split by severity of index event 
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 1/7/2025
* Last modified by: 
* Purpose: additional files make the Appendix histograms and run event studies

* NOTES: 
	- this does estimation just for the sick spouse group, separately by type of event 
*******************************************************************************/


// do this once for males and once for females 
clear
gen fatal_30days = . 
gen nonfatal_snfrehab = . 
gen allother = . 

foreach v of varlist fatal_30days nonfatal_snfrehab allother {
	***** Regressions using *residuals* of insnf
	use "$input_datapath/RDdata.dta" if treated == 1, clear 
	cap egen nonfatal_snfrehab = rowmax(nonfatal_tosnf nonfatal_torehab)
	egen allother = rowmax(nonfatal_snfrehab fatal_30days)
	replace allother = 1 - allother
	
	bys response_id: ereplace `v' = max(`v') 
	keep if `v' == 1

	gen t = day - 1
	reg insnf t dow* if inrange(t, 21-5.039,20) & treated == 1
	predict p1 if inrange(t, 21-5.039 , 21+5.039 ) & treated == 1, xb
	gen r = insnf - p1

	**** RD estimation 
	gen day_c = t - 21 
	gen wgt = 1 - abs(day_c)/11.22 if abs(day_c) < 11.22
	cap drop past_cutoff
	gen past_cutoff = (day_c >= 0)
	gen inter1 = day_c * past_cutoff

	reghdfe insnf day_c past_cutoff inter1 dow_* if ///
		abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], noabsorb
		
	// store globals (TODO: incorporate these into table)
	global b_rdpost_1_`v': di %4.3fc e(b)[1,2]
	global se_rdpost_1_`v': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) { 
		global p_rdpost_1_`v' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) { 
		global p_rdpost_1_`v' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) { 
		global p_rdpost_1_`v' "*"
	}
	else { 
		global p_rdpost_1_`v' ""
	}
	
	reghdfe insnf day_c past_cutoff inter1 dow_* if ///
		abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], ///
		absorb(eventid ym) 
		
	// store globals (TODO: incorporate these into table)
	global b_rdpost_2_`v': di %4.3fc e(b)[1,2]
	global se_rdpost_2_`v': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) { 
		global p_rdpost_2_`v' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) { 
		global p_rdpost_2_`v' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) { 
		global p_rdpost_2_`v' "*"
	}
	else { 
		global p_rdpost_2_`v' ""
	}
	********************************************************************************
}



// can we get a p-value 
use "$input_datapath/RDdata.dta" if treated == 1, clear 
gen group = (fatal_30days == 1 )
	
gen t = day - 1
reg insnf t dow* if inrange(t, 21-5.039,20) & treated == 1
predict p1 if inrange(t, 21-5.039 , 21+5.039 ) & treated == 1, xb
gen r = insnf - p1

**** RD estimation 
gen day_c = t - 21 
gen wgt = 1 - abs(day_c)/11.22 if abs(day_c) < 11.22
cap drop past_cutoff
gen past_cutoff = (day_c >= 0)
gen inter1 = day_c * past_cutoff
gen fatal = past_cutoff * group

reghdfe insnf fatal day_c past_cutoff inter1 dow_* group if ///
	abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], ///
	absorb(eventid ym) 
global p_fatal_eventtype: di %5.4fc 2*ttail(e(df_r), abs(_b[fatal]/_se[fatal]))
********************************************************************************

***** Make the table in texdoc
texdoc init "$hoaglandoutput/D-DiscTable_byEventType.tex", replace force
tex \begin{table}[htb]
tex \centering
tex \caption{\label{tab:ddisc-eventtype} Cutoff Effects by Index Event Type}
tex \begin{threeparttable}
tex \begin{tabular}{lccc}
tex \toprule
tex & Fatal within 30 days & Nonfatal to SNF/Rehab & Other nonfatal \\
tex \midrule
tex Cutoff effect (no FEs) & ${b_rdpost_1_fatal_30days}${p_rdpost_1_fatal_30days} & ${b_rdpost_1_nonfatal_snfrehab}${p_rdpost_1_nonfatal_snfrehab} & ${b_rdpost_1_allother}${p_rdpost_1_allother} \\
tex & (${se_rdpost_1_fatal_30days}) & (${se_rdpost_1_nonfatal_snfrehab}) & (${se_rdpost_1_allother}) \\
tex Cutoff effect (with FEs) & ${b_rdpost_2_fatal_30days}${p_rdpost_2_fatal_30days} & ${b_rdpost_2_nonfatal_snfrehab}${p_rdpost_2_nonfatal_snfrehab} & ${b_rdpost_2_allother}${p_rdpost_2_allother} \\
tex & (${se_rdpost_2_fatal_30days}) & (${se_rdpost_2_nonfatal_snfrehab}) & (${se_rdpost_2_allother}) \\
tex \midrule
tex Fatal-versus-other interaction p-value & \multicolumn{3}{c}{${p_fatal_eventtype}} \\
tex \bottomrule
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table reports the post-event day-21 cutoff effect for the treated group only, split by the type of index event. The final row reports the p-value from the fixed-effects interaction regression comparing fatal shocks to all other treated-group stays.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}
texdoc close
