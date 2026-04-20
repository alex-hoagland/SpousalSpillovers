/*******************************************************************************
* Title: Difference in discontinuitites estimator estimating effect of cutoff on SNF stays
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/7/2024
* Last modified by:
* Purpose: additional files make the Appendix histograms and run event studies

* NOTES:

*******************************************************************************/


***** Prep data
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
keep if inrange(elapse, 0, 122) // inrange(elapse, -122, 122)
gen treated_post = (inrange(elapse, 0, 122) & treated == 1) // ~33k SNF stays in this group  (13k in control and 20k in treated)

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

compress
save "$input_datapath/RDdata.dta", replace
********************************************************************************


***** Regressions using *residuals* of insnf
use "$input_datapath/RDdata.dta", clear

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

// visualize the RD
binscatter r t if inrange(t, 21-5.039, 21+5.039), rd(20.5) by(treated) nq(100) linetype(none) ///
	xtitle("Day at SNF") ytitle("") ///
	subtitle("Share of Patients (Residualized)", position(11) justification(left) ///
		size(small)) symbols(square circle) ///
	yline(0, lcolor(black)) xsc(r(16(2)26)) xlab(16(2)26) ///
	legend(order(1 "Healthy Spouse Group" 2 "Sick Spouse Group") position(11) ring(0))
graph save "$hoaglandoutput/RD_Residuals.gph", replace
graph export "$hoaglandoutput/RD_Residuals.pdf", replace as(pdf)
graph export "$hoaglandoutput/RD_Residuals.png", replace as(png)

// construct the Appendix histogram (non-residualized)
hist los if treated == 0 & inrange(los, 0, 150) & elapse >= 0, ///
	lcolor(ebblue) fcolor(ebblue%40) ///
	percent discrete xline(21.5, lpattern(dash) lcolor(black)) ///
	xline(101.5, lpattern(longdash) lcolor(gs10)) ///
	xtitle("Length of Focal Spouse SNF Stay (days)") ///
	xsc(r(0(10)150)) xlab(0(10)150) ///
	ytitle("")
graph save "$hoaglandoutput/RD_PDFHealthySpouseGroup.gph", replace
graph export "$hoaglandoutput/RD_PDFHealthySpouseGroup.pdf", replace as(pdf)
graph export "$hoaglandoutput/RD_PDFHealthySpouseGroup.png", replace as(png)

hist los if treated == 1 & inrange(los, 0, 150) & elapse >= 0 , ///
	lcolor(maroon) fcolor(maroon%40) ///
	percent discrete xline(21.5, lpattern(dash) lcolor(black)) ///
	xline(101.5, lpattern(longdash) lcolor(gs10)) ///
	xtitle("Length of Focal Spouse SNF Stay (days)") ///
	xsc(r(0(10)150)) xlab(0(10)150) ///
	ytitle("")
graph save "$hoaglandoutput/RD_PDFSickSpouseGroup.gph", replace
graph export "$hoaglandoutput/RD_PDFSickSpouseGroup.pdf", replace as(pdf)
graph export "$hoaglandoutput/RD_PDFSickSpouseGroup.png", replace as(png)
********************************************************************************


**** RD estimation
// note: can consider updating the FEs here to add power, but I don't think we need it.
bys index_id: ereplace index_fem = max(index_fem)
egen ym_sex = group(ym index_fem)

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

reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <= 11.22 & treated_post == 0 [pw=wgt], noabsorb // this replicates rdrobust
	global b_rdpre_1: di %4.3fc e(b)[1,2]
	global se_rdpre_1: di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpre_1 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpre_1 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpre_1 "*"
	}
	else {
		global p_rdpre_1 ""
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

// second: RD estimate for treatment group post-event
// rdrobust insnf day_c if treated_post == 1 // estimate is -.007 (p = 0.104), h = 10.827
reghdfe insnf day_c past_cutoff inter1 dow_* if abs(day_c) <=11.22 & treated_post == 1 [pw=wgt], noabsorb
	global b_rdpost_1: di %4.3fc e(b)[1,2]
	global se_rdpost_1: di %5.4fc sqrt(e(V)[2,2])
	if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.01) {
		global p_rdpost_1 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.05) {
		global p_rdpost_1 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[past_cutoff]/_se[past_cutoff])) < 0.1) {
		global p_rdpost_1 "*"
	}
	else {
		global p_rdpost_1 ""
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

// differences in discontinuities estimator
reghdfe insnf day_c past_cutoff inter1 treated_post inter2* dow_* if abs(day_c) <= 11.22 [pw=wgt], noabsorb // without FEs, p =0.293
	global b_dd_1: di %4.3fc e(b)[1,6]
	global se_dd_1: di %5.4fc sqrt(e(V)[6,6])
	global N_1: di %8.0fc e(N)
	if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.01) {
		global p_dd_1 "***"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.05) {
		global p_dd_1 "**"
	}
	else if (2*ttail(e(df_r), abs(_b[inter2_past_cutoff]/_se[inter2_past_cutoff])) < 0.1) {
		global p_dd_1 "*"
	}
	else {
		global p_dd_1 ""
	}

// with FEs (person + year-month of event)
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
********************************************************************************


***** Make the table in texdoc
texdoc init "$hoaglandoutput/D-DiscTable.tex", replace force
tex \begin{table}[htb]
tex \centering
tex \caption{\label{tab:ddisc} Effects of Index Spouse Health Event on Focal Spouse's Price Sensitivity for SNF Stay Decision}
tex \begin{threeparttable}
tex \begin{tabular}{@{}p{\textwidth}@{}}
tex \centering
tex \begin{tabular}{lcc}
tex \toprule
tex & (1) & (2) \\
tex \midrule
tex \$\tau_{\text{pre}}\$ & ${b_rdpre_1}${p_rdpre_1} & ${b_rdpre_2}${p_rdpre_2} \\
tex & (${se_rdpre_1}) & (${se_rdpre_2}) \\
tex \$\tau_{\text{post}}\$ & ${b_rdpost_1}${p_rdpost_1} & ${b_rdpost_2}${p_rdpost_2} \\
tex & (${se_rdpost_1}) & (${se_rdpost_2}) \\
tex \\
tex \$\beta_{\text{D-Disc}}\$ & ${b_dd_1}${p_dd_1} & ${b_dd_2}${p_dd_2} \\
tex & (${se_dd_1}) & (${se_dd_2}) \\
tex \\
tex Couple FEs & & \checkmark \\
tex Time FEs & & \checkmark \\
tex Bandwidth & 11.22 & 11.22 \\
tex \$N\$ & $N_1 & $N_2 \\
tex \bottomrule
tex \end{tabular}
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table presents regression-discontinuity and differences-in-discontinuities estimators identifying the effect of ending Medicare coverage for SNF stays, which ends on day 21 for qualifying stays. The first two rows present the estimated effect of losing coverage on the probability a focal spouse will remain in the SNF, stratified by before or after the index event. The third row presents the difference-in-discotinuities estimator as discussed in the text. SNF stays within 4 months of the treatment and placebo events are included in the regression.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table}
texdoc close
********************************************************************************
