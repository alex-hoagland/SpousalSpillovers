/*******************************************************************************
* Title: Stratify the RD output by time since health shock
* Created by: Alex Hoagland
* Created on: 9/26/2025
* Last modified on:
* Last modified by:
* Purpose:

* NOTES:

*******************************************************************************/

***** DDisc regressions -- requires new data that looks over the full year as a robustness check

// following Grembi et al., 2016 -- compare RD estimates for cutoff before/after treatment

// here, the outcome is whether the outcome spouse is in the SNF at day d, and the running variable is the number of paiddays accured (pd)
// there is a sharp cutoff in paiddays at 21 and then again at 100

// restrict only to SNFs affected by the cutoff, which is those preceded by a 3-day stay discharged to SNF

// we will use all outcome spouses in the treated group prior to and following the event
// note that we don't need to assign 0s where no SNF stay has occurred -- RDD requires estimation only in bandwidth around cutoff so conditional differences are great!
// make into panel for spouse outcomes with 4 months weeks before/after
use "${input_datapath}/responseevents-MEDPAR.dta" if snf == 1, clear
gen los = response_ds - response_eventdt + 1
drop if missing(los) // ~17M SNF stays
expand 2, generate(treated)
merge m:1 bene_id treated using "${input_datapath}/indexevents_mergedspouses_eligible.dta", keep(3) nogenerate

gen elapse = response_eventdt - eventdate_index if !missing(response_eventdt)
keep if inrange(elapse, 0, 365) //
gen treated_post = (inrange(elapse, 0, 365) & treated == 1) //

// now convert this to an outcome of 1 = husband in SNF; 0 = husband not in SNF as a function of the date, with the running variable being days in paid care. Look at 4 months before and after the index event as in the histograms
expand los
gen insnf = 1
bys response_id index_id eventid hhid response_eventdt: gen day = _n
// cap this at 150 days for analysis, in keeping with histograms
drop if day > 150
egen id = group(response_id index_id eventid treated* response_eventdt) // ~33k total events
fillin id day
gsort id _fillin
bys id: carryforward response_id index_id eventid hhid eventdate_index response_ds treated* response_eventdt los elapse , replace
replace insnf = 0 if missing(insnf) // about 18% of days are in SNF here
gen past_cutoff = (day >= 22)
drop _fillin id

// for FEs
cap drop year* month*
gen month = month(response_eventdt)
gen year = year(response_eventdt)
gen ym=ym(year, month)
gen month2 = month(eventdate_index)
gen year2 = year(eventdate_index)
gen ym2=ym(year2, month2)

// day of the week dummies
gen dow = dow(eventdate_index + day)
forvalues d = 0/6 {
	gen dow_`d' = (dow == `d')
}

drop if inrange(elapse, -400, -1e-2) // don't need these, just the post-event data for the treated =0 group
drop if treated == 0 & elapse >= 122

local mybw = 5.039

gen t = day - 1
reg insnf t dow* if inrange(t, 21-`mybw',20) & treated == 0
predict p0 if inrange(t, 21-`mybw' , 21+`mybw' ) & treated == 0, xb
gen r_snf0 = insnf - p0
reg insnf t dow* if inrange(t, 21-`mybw',20) & treated == 1
predict p1 if inrange(t, 21-`mybw' , 21+`mybw' ) & treated == 1, xb
gen r_snf1 = insnf - p1
gen r = r_snf0 if treated == 0
replace r = r_snf1 if treated == 1

// stratify by relative time -- note that this are for the post variables
// the pre-regression should just include all where treated_post == 0
gen group = (inrange(elapse, 0, 90))
replace group = 2 if inrange(elapse, 91, 180)
replace group = 3 if inrange(elapse, 181, 270)
replace group = 4 if inrange(elapse, 271, 365)

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

forvalues i = 1/4 {
	reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 [pw=wgt], absorb(eventid ym)
	global b_rdpre_2_`i': di %4.3fc e(b)[1,2]
	global se_rdpre_2_`i': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpre_2_`i' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpre_2_`i' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpre_2_`i' "*"
	}
	else {
		global p_rdpre_2_`i' ""
	}
	reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 & group == `i' [pw=wgt], absorb(eventid ym)
	global b_rdpost_2_`i': di %4.3fc e(b)[1,2]
	global se_rdpost_2_`i': di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpost_2_`i' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpost_2_`i' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpost_2_`i' "*"
	}
	else {
		global p_rdpost_2_`i' ""
	}

// with FEs (person + year-month of event)
	reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 & (group == `i' | treated_post == 0) [pw=wgt], absorb(eventid ym) //
	global b_dd_2_`i': di %4.3fc e(b)[1,6]
	global se_dd_2_`i': di %5.4fc sqrt(e(V)[6,6])
	global N_2_`i': di %8.0fc e(N)
	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
		global p_dd_2_`i' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
		global p_dd_2_`i' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
		global p_dd_2_`i' "*"
	}
	else {
		global p_dd_2_`i' ""
	}
}
********************************************************************************


***** Make the table in texdoc
texdoc init "$hoaglandoutput/D-DiscTable_fullyear.tex", replace force
tex \begin{table}[htb]
tex \centering
tex \caption{\label{tab:ddisc-fullyear} Dynamic Effects on Outcome Spouse's Price Sensitivity for SNF Stay Decision}
tex \begin{threeparttable}
tex \begin{tabular}{@{}p{\textwidth}@{}}
tex \centering
tex \begin{tabular}{lcccc}
tex \toprule
tex & (1) & (2) & (3) & (4) \\
tex & 0--90 days & 91--180 days & 181--270 days & 271--365 days \\
tex \midrule
tex \$\tau_{\text{pre}}\$ & ${b_rdpre_2_1}${p_rdpre_2_1} & ${b_rdpre_2_2}${p_rdpre_2_2} & ${b_rdpre_2_3}${p_rdpre_2_3} & ${b_rdpre_2_4}${p_rdpre_2_4} \\
tex &  (${se_rdpre_2_1}) & (${se_rdpre_2_2}) & (${se_rdpre_2_3}) & (${se_rdpre_2_4}) \\
tex \$\tau_{\text{post}}\$ & ${b_rdpost_2_1}${p_rdpost_2_1} & ${b_rdpost_2_2}${p_rdpost_2_2} & ${b_rdpost_2_3}${p_rdpost_2_3} & ${b_rdpost_2_4}${p_rdpost_2_4} \\
tex & (${se_rdpost_2_1}) & (${se_rdpost_2_2}) &  (${se_rdpost_2_3}) &  (${se_rdpost_2_4}) \\
tex \\
tex \$\beta_{\text{D-Disc}}\$ & ${b_dd_2_1}${p_dd_2_1} & ${b_dd_2_2}${p_dd_2_2} & ${b_dd_2_3}${p_dd_2_3} & ${b_dd_2_4}${p_dd_2_4} \\
tex & (${se_dd_2_1}) & (${se_dd_2_2}) & (${se_dd_2_3}) & (${se_dd_2_4}) \\
tex \\
tex Couple FEs & \checkmark & \checkmark & \checkmark & \checkmark \\
tex Time FEs &  \checkmark & \checkmark & \checkmark & \checkmark \\
tex \$N\$ & $N_2_1 & $N_2_2 & $N_2_3 & $N_2_4 \\
tex \bottomrule
tex \end{tabular}
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table presents regression-discontinuity and differences-in-discontinuities estimators identifying the effect of ending Medicare coverage for SNF stays, which ends on day 21 for qualifying stays. The first two rows present the estimated effect of losing coverage on the probability a focal spouse will remain in the SNF, stratified by before or after the index event. The third row presents the difference-in-discotinuities estimator as discussed in the text. The column indicates the duration of time for which SNF stays are included in the regression (relative to both treatment and placebo events).
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}
texdoc close
********************************************************************************
