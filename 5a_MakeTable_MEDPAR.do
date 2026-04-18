/*******************************************************************************
* Title: Make table for health effects
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/4
* Last modified by: 
* Purpose: Requires you to run the file "5_*.do" with desired outcomes first

* NOTES: 
	- 
*******************************************************************************/

	
***** Make table using texdoc 
use "$hoaglandoutput/5_HealthEffectsTable_MEDPAR.dta", clear
gen p = 2 * (1 - normal(abs(coef/stderr))) // gen p-values
gen star = "***" if p < .001
replace star = "**" if missing(star) & p < .01
replace star = "*" if missing(star) & p < .05

format coef %4.3fc
format stderr %5.4fc
gsort model type 

levelsof model, local(mymod)
macro drop te_* se_* star_* n_*
forvalues t = 0/2 { 
	foreach m of local mymod { 
		preserve
		keep if model == "`m'" & type == `t'
		global te_`m'_`t': di %4.3fc coef[1]
		global se_`m'_`t': di %5.4fc stderr[1]
		global star_`m'_`t': di star[1]
		global n_`m'_`t': di %12.0fc N[1]
		restore
	}
}
********************************************************************************


***** texdoc
texdoc init "$hoaglandoutput/health_effects_pooled.tex", replace force
tex \begin{table}[htbp]
tex \centering
tex \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}
tex \caption{Change in Spillover Risk of Health Events After a Focal Spouse’s Index Event}
tex \begin{tabular}{lccccc}
tex \toprule
tex & (1) & (2) & (3) & (4) & (5) \\ 
tex   & SNF & Hospitalization & Fall & ED Visits & Hospitalization \& SNF  \\
tex \midrule
tex Treatment Effect,  & ${te_snf_0}${star_snf_0} & ${te_hospitalization_0}${star_hospitalization_0}  & ${te_fall_0}${star_fall_0} & ${te_num_ED_0}${star_num_ED_0}  & ${te_snf_hosp_0}${star_snf_hosp_0} \\
tex   \hspace{0.2cm} Month 0  & (${se_snf_0})  & (${se_hospitalization_0})  & (${se_fall_0}) & (${se_num_ED_0})  & (${se_snf_hosp_0})  \\
tex \\ 
tex Fatal Events Only,  & ${te_snf_1}${star_snf_1} & ${te_hospitalization_1}${star_hospitalization_1}  & ${te_fall_1}${star_fall_1} &  ${te_num_ED_1}${star_num_ED_1}  & ${te_snf_hosp_1}${star_snf_hosp_1} \\
tex   \hspace{0.2cm} Month 0  & (${se_snf_1})  & (${se_hospitalization_1}) & (${se_fall_1}) & (${se_num_ED_1})  & (${se_snf_hosp_1}) \\
tex Nonfatal Events Only,  & ${te_snf_2}${star_snf_2} & ${te_hospitalization_2}${star_hospitalization_2}  & ${te_fall_2}${star_fall_2} & ${te_num_ED_2}${star_num_ED_2}  & ${te_snf_hosp_2}${star_snf_hosp_2} \\
tex   \hspace{0.2cm} Month 0  & (${se_snf_2})  & (${se_hospitalization_2}) & (${se_fall_2}) & (${se_num_ED_2})  & (${se_snf_hosp_2}) \\
tex \\
tex Baseline Rate/1,000 & 10.1 & 32.8 & 0.06 & 31.5 & 6.8 \\ 
tex  \\
tex N & ${n_snf_0} & ${n_hospitalization_0} & ${n_fall_0} & ${n_num_ED_0} & ${n_snf_hosp_0}  \\
tex \bottomrule
tex \end{tabular}
tex \label{tab:health-effects}
tex \vspace*{0.29cm}
tex 
tex \begin{minipage}{1.05\textwidth} 
tex 
tex {\footnotesize \textit{Notes:} This table presents pooled difference-in-differences coefficients estimating the effect of a focal spouse's first heart attack or stroke on the spillover spouse's health outcomes (indicated in each column). ``Hospitalization \& SNF" indicates that a spouse both was hospitalized and visited a SNF in the same month. ED Visits are measured as total number of visits. All other outcomes are binary. Note that ED visits are measured using the 20\% sample of Medicare beneficiaries, hence the reduced sample size. Treatment effects are estimated in month 0, capturing the effect for the first four weeks post-event. We re-scale all coefficient such that they indicate the change relative to the initial baseline risk of diagnosis in each category, and we cluster standard errors at the household level. Regressions include calendar-time fixed effects and person-specific fixed effects.  \sym{*} \(p<0.05\), \sym{**} \(p<0.01\), \sym{***} \(p<0.001\)}
tex \end{minipage}
tex \end{table}
texdoc close 
********************************************************************************
