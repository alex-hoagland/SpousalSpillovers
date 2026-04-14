/*******************************************************************************
* Title: Makes regression table of annual spending on various categories
* Created by: Alex Hoagland
* Created on: 2/8/24
* Last modified on: 11/4
* Last modified by: Prabidhik KC
* Purpose: This file makes figures -- can be edited to impose restrictions

* NOTES: 
	- now needs to be run through the master file to accommodate multiple outcomes
	- pooled across spouses
*******************************************************************************/

	
***** Prep data 
use "${input_datapath}/weekpanel.dta" if inrange(reltime_weeks, -1, 1), clear  // three observations per event-treatment 
gen todrop = (time_pre <= 365*3) // need to require sufficient time before to get adequate results for annual level 
bys index_id: ereplace todrop = max(todrop) 
drop if todrop == 1 
drop todrop 
	
// aggregate to yearly level 
cap drop year
gen year = year(eventdate_index) 
replace year = year - 1 if reltime_weeks == 0 
replace year = year - 2 if reltime_weeks == -1
drop reltime_weeks
gen treated_post = (treated == 1 & year == year(eventdate_index))
gen weight = mdy(12,31,year(eventdate_index )) - eventdate_index  + 1 // days remaining in year after event 
gcollapse (max) treated* index_fem fatal* weight, by(index_id response_id hhid eventid year) fast 
compress
save "${input_datapath}/yearpanel.dta", replace
********************************************************************************


***** Now merge in spending 
clear 
gen year = . 
save "$input_datapath/spendingdata.dta", replace

forvalues year = 2009/2016 { 
	
	display "***** WORKING ON YEAR `year' *****"
	use response_id year if year == `year' using "${input_datapath}/yearpanel.dta", clear 
	keep response_id 
	duplicates drop 
	rename response_id bene_id 
	merge 1:1 bene_id using /disk/aging/medicare/data/harm/100pct/bsfcu/`year'/bsfcu`year', ///
		keep(3) nogenerate // keepusing(admsndt bene_id totchrg cvrchrg) 
	append using "$input_datapath/spendingdata.dta"
	save "$input_datapath/spendingdata.dta", replace
}

use "$input_datapath/spendingdata.dta", clear
duplicates drop
rename bene_id response_id
replace file_year = rfrnc_y if missing(file_year)
drop rfrnc_y 

// have to clean up some variables with different names across years 
ereplace acute_bene_pmt = rowtotal(acute_be*)
drop acute_be
ereplace acute_cov_days = rowtotal(acute_co*)
drop acute_co
ereplace acute_mdcr_pmt = rowtotal(acute_md*)
drop acute_md
ereplace acute_perdiem_pmt = rowtotal(acute_pe*) 
drop acute_pe
ereplace acute_prmry_pmt = rowtotal(acute_pr*)
drop acute_pr
ereplace acute_stays = rowtotal(acute_st*)
drop acute_st 

ereplace anes_bene_pmt = rowtotal(anes_ben*)
ereplace anes_events = rowtotal(anes_eve*)
ereplace anes_mdcr_pmt = rowtotal(anes_mdc*)
ereplace anes_prmry_pmt = rowtotal(anes_prm*)
drop anes_ben anes_eve anes_mdc anes_prm

ereplace asc_bene_pmt = rowtotal(asc_bene*)
ereplace asc_events = rowtotal(asc_eve*)
ereplace asc_mdcr_pmt = rowtotal(asc_mdcr*)
ereplace asc_prmry_pmt = rowtotal(asc_pr*)
drop asc_bene asc_even asc_mdcr asc_prmr

ereplace dialys_bene_pmt = rowtotal(dialys_b*)
ereplace dialys_events = rowtotal(dialys_e*)
ereplace dialys_mdcr_pmt = rowtotal(dialys_m*)
ereplace dialys_prmry_pmt = rowtotal(dialys_p*)
drop dialys_b dialys_e dialys_m dialys_p 

ereplace dme_bene_pmt = rowtotal(dme_bene*)
ereplace dme_events = rowtotal(dme_even*)
ereplace dme_mdcr_pmt = rowtotal(dme_mdcr*)
ereplace dme_prmry_pmt = rowtotal(dme_prm*)
drop dme_prmr dme_mdcr dme_even dme_bene 

ereplace em_bene_pmt = rowtotal(em_bene*)
ereplace em_events = rowtotal(em_event*)
ereplace em_mdcr_pmt = rowtotal(em_mdcr*)
ereplace em_prmry_pmt = rowtotal(em_prm*)
drop em_bene_ em_event em_mdcr_ em_prmry 

ereplace hh_mdcr_pmt = rowtotal(hh_mdcr*) 
ereplace hh_prmry_pmt = rowtotal(hh_prmr*)
ereplace hh_visits = rowtotal(hh_visi*)
drop hh_mdcr_ hh_prmry hh_visit 

ereplace hop_bene_pmt = rowtotal(hop_bene*)
ereplace hop_er_visits = rowtotal(hop_er*)
ereplace hop_mdcr_pmt = rowtotal(hop_mdcr*)
ereplace hop_prmry_pmt = rowtotal(hop_prmr*)
ereplace hop_visits = rowtotal(hop_vis*)
drop hop_bene hop_er_v hop_mdcr hop_prmr hop_visi 

ereplace hos_cov_days = rowtotal(hos_cov*)
ereplace hos_mdcr_pmt = rowtotal(hos_mdcr*)
ereplace hos_prmry_pmt = rowtotal(hos_prmr*)
ereplace hos_stays = rowtotal(hos_stay*)
drop hos_cov_ hos_mdcr hos_prmr hos_stay

ereplace img_bene_pmt = rowtotal(img_bene*)
ereplace img_events = rowtotal(img_even*) 
ereplace img_mdcr_pmt = rowtotal(img_mdcr*)
ereplace img_prmry_pmt = rowtotal(img_prmr*)
drop img_bene img_even img_mdcr img_prmr

ereplace ip_er_visits = rowtotal(ip_er_vi*)
drop ip_er_vi 

ereplace oip_bene_pmt = rowtotal(oip_bene*) 
ereplace oip_cov_days = rowtotal(oip_cov*)
ereplace oip_mdcr_pmt = rowtotal(oip_mdcr*)
ereplace oip_perdiem_pmt = rowtotal(oip_perd*)
ereplace oip_prmry_pmt = rowtotal(oip_prmr*)
ereplace oip_stays = rowtotal(oip_stay*)
drop oip_bene oip_cov_ oip_mdcr oip_perd oip_prmr oip_stay 

ereplace oproc_bene_pmt = rowtotal(oproc_be*)
ereplace oproc_events = rowtotal(oproc_ev*)
ereplace oproc_mdcr_pmt = rowtotal(oproc_md*)
ereplace oproc_prmry_pmt = rowtotal(oproc_pr*)
drop oproc_be oproc_ev oproc_md oproc_pr 

ereplace othc_bene_pmt = rowtotal(othc_ben*)
ereplace othc_events = rowtotal(othc_ev*)
ereplace othc_mdcr_pmt = rowtotal(othc_mdc*)
ereplace othc_prmry_pmt = rowtotal(othc_prm*)
drop othc_ben othc_eve othc_mdc othc_prm 

ereplace phys_bene_pmt = rowtotal(phys_ben*)
ereplace phys_events = rowtotal(phys_eve*)
ereplace phys_mdcr_pmt = rowtotal(phys_mdc*)
ereplace phys_prmry_pmt = rowtotal(phys_prm*)
drop phys_ben phys_eve phys_mdc phys_prm

ereplace ptb_drug_bene_pmt = rowtotal(ptbrxbp ptb_drug_bene_pmt)
ereplace ptb_drug_events = rowtotal(ptbrxevt ptb_drug_events)
ereplace ptb_drug_mdcr_pmt = rowtotal(ptbrxmp ptb_drug_mdcr_pmt)
ereplace ptb_drug_prmry_pmt = rowtotal(ptbrxpp ptb_drug_prmry_pmt)
drop ptbrxbp ptbrxevt ptbrxmp ptbrxpp

ereplace ptd_bene_pmt = rowtotal(ptd_bene*)
ereplace ptd_events = rowtotal(ptd_even*)
ereplace ptd_fill_cnt = rowtotal(ptd_fill*)
ereplace ptd_mdcr_pmt = rowtotal(ptd_mdcr*)
ereplace ptd_total_rx_cst = rowtotal(ptd_tota*)
drop ptd_bene ptd_even ptd_fill ptd_mdcr ptd_tota 

ereplace readmissions = rowtotal(readmiss*) 
drop readmiss

ereplace snf_bene_pmt = rowtotal(snf_bene*)
ereplace snf_cov_days = rowtotal(snf_cov*)
ereplace snf_mdcr_pmt = rowtotal(snf_mdcr*)
ereplace snf_prmry_pmt = rowtotal(snf_prmr*)
ereplace snf_stays = rowtotal(snf_stay*)
drop snf_bene snf_cov_ snf_mdcr snf_prmr snf_stay

ereplace test_bene_pmt = rowtotal(test_ben*)
ereplace test_events = rowtotal(test_eve*)
ereplace test_mdcr_pmt = rowtotal(test_mdc*)
ereplace test_prmry_pmt = rowtotal(test_prm*)
drop test_ben test_eve test_mdc test_prm 

replace year =  file_year
merge 1:m response_id year using "$input_datapath/yearpanel.dta", keep(3) nogenerate

compress 
save "${input_datapath}/yearpanel.dta", replace
********************************************************************************


***** Main Regression 
// first, do it for total spending 
use "${input_datapath}/yearpanel.dta", clear 
egen outcome = rowtotal(*mdcr_pmt) // mdcr_pmt just to measure fiscal externality instead of total payment (bene + mdcr + prmy)
// inflation adjust and topcode all spending
qui do "/disk/agedisk3/medicare.work/layton-DUA54204/WorkingDatasets/Replication_Package/code/swap-indexevents/Inflation.do" "outcome"
replace outcome = 250000 if outcome > 250000 & !missing(outcome)

sum outcome if (treated_post == 0), d 
global tot_premean: di %8.0fc `r(mean)'
global tot_premed: di %8.0fc `r(p50)'

// egen year_sex = group(year index_fem)
reghdfe outcome treated_post [pw=weight], absorb(eventid year) vce(cluster hhid)
global c1_tot_coef: di %6.0fc e(b)[1,1]
global c1_tot_se: di %6.2fc sqrt(e(V)[1,1])
if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
	global p1_tot "***"
}
else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
	global p1_tot "**"
}
else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
	global p1_tot "*"
}
else { 
	global p1_tot ""
}

qui reghdfe outcome treated_post if fatal_disc == 1 [pw=weight], absorb(eventid year) vce(cluster hhid)
global c2_tot_coef: di %6.0fc e(b)[1,1]
global c2_tot_se: di %6.2fc sqrt(e(V)[1,1])
if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
	global p2_tot "***"
}
else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
	global p2_tot "**"
}
else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
	global p2_tot "*"
}
else { 
	global p2_tot ""
}

ppmlhdfe outcome treated_post [pw=weight], absorb(eventid year) vce(cluster hhid)
global c3_tot_coef: di %4.2fc e(b)[1,1]
global c3_tot_se: di %4.3fc sqrt(e(V)[1,1])
if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
	global p3_tot "***"
}
else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
	global p3_tot "**"
}
else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
	global p3_tot "*"
}
else { 
	global p3_tot ""
}

qui ppmlhdfe outcome treated_post if fatal_disc == 1 [pw=weight], absorb(eventid year) vce(cluster hhid)
global c4_tot_coef: di %4.2fc e(b)[1,1]
global c4_tot_se: di %4.3fc sqrt(e(V)[1,1])
if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
	global p4_tot "***"
}
else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
	global p4_tot "**"
}
else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
	global p4_tot "*"
}
else { 
	global p4_tot ""
}

// now loop over some spending categories 
foreach v in "snf" "acute" "ptd" "asc" "hh" "hos" "hop" "oip" "em" "phys" {
	di in red "***** SPENDING REGRESSIONS: `v' *****"
	
	use "${input_datapath}/yearpanel.dta", clear 
	egen outcome = rowtotal(`v'*mdcr_pmt) // total payment (bene + mdcr + prmy)
	// inflation adjust and topcode all spending
	qui do "/disk/agedisk3/medicare.work/layton-DUA54204/WorkingDatasets/Replication_Package/code/swap-indexevents/Inflation.do" "outcome"
	replace outcome = 50000 if outcome > 50000 & !missing(outcome)

	qui sum outcome if (treated_post == 0), d 
	global `v'_premean: di %8.0fc `r(mean)'
	global `v'_premed: di %8.0fc `r(p50)'

	qui reghdfe outcome treated_post [pw=weight], absorb(eventid year) vce(cluster hhid)
	global c1_`v'_coef: di %6.0fc e(b)[1,1]
	global c1_`v'_se: di %6.2fc sqrt(e(V)[1,1])
	if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
		global p1_`v' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
		global p1_`v' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
		global p1_`v' "*"
	}
	else { 
		global p1_`v' ""
	}
	
	qui reghdfe outcome treated_post [pw=weight] if fatal_disc == 1,  ///
		absorb(eventid year) vce(cluster hhid)
	global c2_`v'_coef: di %6.0fc e(b)[1,1]
	global c2_`v'_se: di %6.2fc sqrt(e(V)[1,1])
	if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
		global p2_`v' "***"
	}
	else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
		global p2_`v' "**"
	}
	else if (2*ttail(e(df_r), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
		global p2_`v' "*"
	}
	else { 
		global p2_`v' ""
	}

	qui ppmlhdfe outcome treated_post [pw=weight], absorb(eventid year) vce(cluster hhid)
	global c3_`v'_coef: di %4.2fc e(b)[1,1]
	global c3_`v'_se: di %4.3fc sqrt(e(V)[1,1])
	if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
		global p3_`v' "***"
	}
	else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
		global p3_`v' "**"
	}
	else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
		global p3_`v' "*"
	}
	else { 
		global p3_`v' ""
	}
	
	qui ppmlhdfe outcome treated_post if fatal_disc == 1 [pw=weight], ///
		absorb(eventid year) vce(cluster hhid)
	global c4_`v'_coef: di %4.2fc e(b)[1,1]
	global c4_`v'_se: di %4.3fc sqrt(e(V)[1,1])
	if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.01) { 
		global p4_`v' "***"
	}
	else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.05) { 
		global p4_`v' "**"
	}
	else if (2*ttail(e(df), abs(_b[treated_post]/_se[treated_post])) < 0.1) { 
		global p4_`v' "*"
	}
	else { 
		global p4_`v' ""
	}
}
********************************************************************************


***** Make the table 
texdoc init "$hoaglandoutput/RegTable_Annual.tex", replace force
tex \begin{table}[htbp]
tex \centering
tex \caption{\label{tab:annual-regs} Effect of Index Event on Focal Spouse Spending, Annual Level}
tex \begin{threeparttable}
tex \begin{tabular}{lccccc}
tex \toprule
tex & Pre-Treatment & \multicolumn{2}{c}{Levels} & \multicolumn{2}{c}{Poisson} \\\cmidrule{3-4}\cmidrule{5-6}
tex Spending Measure & Average & All & Fatal Events & All & Fatal Events \\
tex \midrule
tex \multicolumn{5}{l}{\textbf{Panel A}: Total Spending} \\
tex & \$ $tot_premean & \$ ${c1_tot_coef}${p1_tot} & \$ ${c2_tot_coef}${p2_tot} & ${c3_tot_coef}${p3_tot} & ${c4_tot_coef}${p4_tot} \\ 
tex  &  & (${c1_tot_se}) & (${c2_tot_se}) & (${c3_tot_se}) & (${c4_tot_se}) \\ 
tex \multicolumn{5}{l}{\textbf{Panel B}: Long-term Care} \\ 
tex SNF  & \$ $snf_premean &  \$ ${c1_snf_coef}${p1_snf} & \$ ${c2_snf_coef}${p2_snf} & ${c3_snf_coef}${p3_snf} & ${c4_snf_coef}${p4_snf} \\ 
tex  &  & (${c1_snf_se}) & (${c2_snf_se}) & (${c3_snf_se}) & (${c4_snf_se}) \\ 
tex Home Health  & \$ $hh_premean &  \$ ${c1_hh_coef}${p1_hh} & \$ ${c2_hh_coef}${p2_hh} & ${c3_hh_coef}${p3_hh} & ${c4_hh_coef}${p4_hh} \\ 
tex  &  & (${c1_hh_se}) & (${c2_hh_se}) & (${c3_hh_se}) & (${c4_hh_se}) \\ 
tex Hospice  & \$ $hos_premean &  \$ ${c1_hos_coef}${p1_hos} & \$ ${c2_hos_coef}${p2_hos} & ${c3_hos_coef}${p3_hos} & ${c4_hos_coef}${p4_hos} \\ 
tex  &  & (${c1_hos_se}) & (${c2_hos_se}) & (${c3_hos_se}) & (${c4_hos_se}) \\ 
tex \multicolumn{5}{l}{\textbf{Panel C}: Hospital \& Surgical Care} \\ 
tex Acute Inpatient  &  \$ $acute_premean &  \$ ${c1_acute_coef}${p1_acute} & \$ ${c2_acute_coef}${p2_acute} & ${c3_acute_coef}${p3_acute} & ${c4_acute_coef}${p4_acute} \\ 
tex  &  & (${c1_acute_se}) & (${c2_acute_se}) & (${c3_acute_se}) & (${c4_acute_se}) \\ 
tex Other Inpatient  & \$ $oip_premean &  \$ ${c1_oip_coef}${p1_oip} & \$ ${c2_oip_coef}${p2_oip} & ${c3_oip_coef}${p3_oip} & ${c4_oip_coef}${p4_oip} \\ 
tex  &  & (${c1_oip_se}) & (${c2_oip_se}) & (${c3_oip_se}) & (${c4_oip_se}) \\ 
tex Hospital Outpatient  & \$ $hop_premean &  \$ ${c1_hop_coef}${p1_hop} & \$ ${c2_hop_coef}${p2_hop} & ${c3_hop_coef}${p3_hop} & ${c4_hop_coef}${p4_hop} \\ 
tex  &  & (${c1_hop_se}) & (${c2_hop_se}) & (${c3_hop_se}) & (${c4_hop_se}) \\ 
tex Ambulatory Surgical Center  & \$ $asc_premean &  \$ ${c1_asc_coef}${p1_asc} & \$ ${c2_asc_coef}${p2_asc} & ${c3_asc_coef}${p3_asc} & ${c4_asc_coef}${p4_asc} \\ 
tex  &  & (${c1_asc_se}) & (${c2_asc_se}) & (${c3_asc_se}) & (${c4_asc_se}) \\ 
tex \multicolumn{5}{l}{\textbf{Panel D}: Other Care} \\ 
tex Physician Payments  & \$ $phys_premean &  \$ ${c1_phys_coef}${p1_phys} & \$ ${c2_phys_coef}${p2_phys} & ${c3_phys_coef}${p3_phys} & ${c4_phys_coef}${p4_phys} \\ 
tex  &  & (${c1_phys_se}) & (${c2_phys_se}) & (${c3_phys_se}) & (${c4_phys_se}) \\ 
tex Evaluation \& Management  & \$ $em_premean &  \$ ${c1_em_coef}${p1_em} & \$ ${c2_em_coef}${p2_em} & ${c3_em_coef}${p3_em} & ${c4_em_coef}${p4_em} \\ 
tex  &  & (${c1_em_se}) & (${c2_em_se}) & (${c3_em_se}) & (${c4_em_se}) \\ 
tex Part D Spending  & \$ $ptd_premean &  \$ ${c1_ptd_coef}${p1_ptd} & \$ ${c2_ptd_coef}${p2_ptd} & ${c3_ptd_coef}${p3_ptd} & ${c4_ptd_coef}${p4_ptd} \\ 
tex  &  & (${c1_ptd_se}) & (${c2_ptd_se}) & (${c3_ptd_se}) & (${c4_ptd_se}) \\ 
tex \bottomrule 
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table plots estimates of pooled post-treatment effects tracking the year following an index event's first heart attack or stroke. Regressions include calendar-time fixed effects and person-specific fixed effects. The first two columns present models estimated via OLS and the second two columns present models estimate via Poisson regression. Columns (1) and (3) report the estimate for all events, while columns (2) and (4) report the estimate only for fatal index events. Standard errors are clustered at the household level.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table} 
texdoc close 
****************************************************************************************


***** Make the table without Poisson
texdoc init "$hoaglandoutput/RegTable_Annual_olsonly.tex", replace force
tex \begin{table}[htbp]
tex \centering
tex \caption{\label{tab:annual-regs} Effect of Index Event on Focal Spouse Spending, Annual Level}
tex \begin{threeparttable}
tex \begin{tabular}{lccc}
tex \toprule
tex & & \multicolumn{2}{c}{Year of Index Event} \\\cmidrule{3-4}
tex & Pre-Treatment  & (1) & (2) \\
tex Spending Measure & Average & All & Fatal Events \\
tex \midrule
tex \multicolumn{4}{l}{\textbf{Panel A}: Total Spending} \\
tex & \$ $tot_premean & \$ ${c1_tot_coef}${p1_tot} & \$ ${c2_tot_coef}${p2_tot}  \\ 
tex  &  & (${c1_tot_se}) & (${c2_tot_se}) \\ 
tex \multicolumn{4}{l}{\textbf{Panel B}: Long-term Care} \\ 
tex SNF  & \$ $snf_premean &  \$ ${c1_snf_coef}${p1_snf} & \$ ${c2_snf_coef}${p2_snf} \\ 
tex  &  & (${c1_snf_se}) & (${c2_snf_se})  \\ 
tex Home Health  & \$ $hh_premean &  \$ ${c1_hh_coef}${p1_hh} & \$ ${c2_hh_coef}${p2_hh} \\ 
tex  &  & (${c1_hh_se}) & (${c2_hh_se})  \\ 
tex Hospice  & \$ $hos_premean &  \$ ${c1_hos_coef}${p1_hos} & \$ ${c2_hos_coef}${p2_hos} \\ 
tex  &  & (${c1_hos_se}) & (${c2_hos_se}) \\ 
tex \multicolumn{4}{l}{\textbf{Panel C}: Hospital \& Surgical Care} \\ 
tex Acute Inpatient  &  \$ $acute_premean &  \$ ${c1_acute_coef}${p1_acute} & \$ ${c2_acute_coef}${p2_acute}  \\ 
tex  &  & (${c1_acute_se}) & (${c2_acute_se})  \\ 
tex Other Inpatient  & \$ $oip_premean &  \$ ${c1_oip_coef}${p1_oip} & \$ ${c2_oip_coef}${p2_oip} \\ 
tex  &  & (${c1_oip_se}) & (${c2_oip_se}) \\ 
tex Hospital Outpatient  & \$ $hop_premean &  \$ ${c1_hop_coef}${p1_hop} & \$ ${c2_hop_coef}${p2_hop} \\ 
tex  &  & (${c1_hop_se}) & (${c2_hop_se})  \\ 
tex Ambulatory Surgical Center  & \$ $asc_premean &  \$ ${c1_asc_coef}${p1_asc} & \$ ${c2_asc_coef}${p2_asc}  \\ 
tex  &  & (${c1_asc_se}) & (${c2_asc_se}) \\ 
tex \multicolumn{4}{l}{\textbf{Panel D}: Other Care} \\ 
tex Physician Payments  & \$ $phys_premean &  \$ ${c1_phys_coef}${p1_phys} & \$ ${c2_phys_coef}${p2_phys}  \\ 
tex  &  & (${c1_phys_se}) & (${c2_phys_se}) \\ 
tex Evaluation \& Management  & \$ $em_premean &  \$ ${c1_em_coef}${p1_em} & \$ ${c2_em_coef}${p2_em} \\ 
tex  &  & (${c1_em_se}) & (${c2_em_se}) \\ 
tex Part D Spending  & \$ $ptd_premean &  \$ ${c1_ptd_coef}${p1_ptd} & \$ ${c2_ptd_coef}${p2_ptd} \\ 
tex  &  & (${c1_ptd_se}) & (${c2_ptd_se})  \\ 
tex \bottomrule 
tex \end{tabular}
tex \begin{tablenotes}
tex \small
tex \item \textit{Notes}: This table plots estimates of pooled post-treatment effects tracking the year following an index event's first heart attack or stroke. Regressions include calendar-time fixed effects and person-specific fixed effects. Column (1) reports the estimate for all events, while column (2) reports the estimate only for fatal index events. Standard errors are clustered at the household level.
tex \end{tablenotes}
tex \end{threeparttable}
tex \end{table} 
texdoc close 
****************************************************************************************
