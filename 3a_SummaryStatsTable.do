/*******************************************************************************
* Title: Make summary stat table 
* Created by: Prabidhik 
* Created on: 2/8/24
* Last modified on: 11/8/2024
* Last modified by: Alex Hoagland
* Purpose: 

* NOTES: 

*******************************************************************************/


**** Load data and merge in outcomes 
// we want demographics: age, sex, race, dual eligibility status, FFS/HMO status, pr(SNF)
// we also want health stuff: SNF/hosp use and # in previous year, # and incidence of chronic conditions, and total spending 
use *id treated reltime* eventdate using ///
	"${input_datapath}/weekpanel.dta" if treated == 1 & reltime_weeks == 0, clear
// note: this is where you would get the pr(snf) -- everything else comes from BSF

duplicates drop
cap drop bene_id
expand 2, gen(group)
gen bene_id = response_id if group == 1 
replace bene_id = index_id if group == 0 
gen file_year = year(eventdate_index)-1 // we are summarizing in the year prior to the event

// link in BSF data 
forvalues y = 2010/2015 {
	di "***** YEAR `y' *****"
	merge m:1 bene_id file_year using ///
		/disk/aging/medicare/data/harm/100pct/bsfab/`y'/bsfab`y'.dta, nogenerate ///
		update replace keep(1 3 4 5) // keepusing(covstart hmoin* buyin* hmo*)
}

// link in BSF-CC data 
forvalues y = 2010/2015 {
	di "***** YEAR `y' *****"
	merge m:1 bene_id file_year using ///
		/disk/aging/medicare/data/harm/100pct/bsfcc/`y'/bsfcc`y'.dta, nogenerate ///
		update replace keep(1 3 4 5) // keepusing(covstart hmoin* buyin* hmo*)
}
gen any_chronic = 0 
foreach v of varlist ami alzh chrnkidn copd chf diabetes ischmcht depressn osteoprs strketia cncrclrc cncrprst cncrlung anemia { // cataract glaucoma hipfrac ra_oa asthma hyperl hyperp hypert hypoth
	cap replace any_chronic = 1 if `v' == 3 // had claims + appropriate coverage 
	// cap replace any_chronic = 1 if !missing(`v'e) // date claims were first met (perhaps more than 1 year prior)
} 
drop ami* alzh* chrnkidn* copd* chf* diabetes* ischmcht* depressn* osteoprs* strketia* cncrclrc* cncrprst* cncrlung* anemia* cataract* glaucoma* hipfrac* ra_oa* asthma* hyperl* hyperp* hypert* hypoth*

// merge in annual spending 
forvalues year = 2010/2012 {
	display "***** WORKING ON YEAR `year' *****"
	merge m:1 bene_id file_year using ///
		/disk/aging/medicare/data/harm/100pct/bsfcu/`year'/bsfcu`year', ///
		keep(1 3 4 5) replace update nogenerate 
}
gen g_fileyear = file_year
forvalues year = 2013/2015 {
	display "***** WORKING ON YEAR `year' *****"
	merge m:1 bene_id g_fileyear using ///
		/disk/aging/medicare/data/harm/100pct/bsfcu/`year'/bsfcu`year', ///
		keep(1 3 4 5) replace update nogenerate 
	replace file_year = `year' if missing(file_year)
}

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
egen tot_pmt = rowtotal(*pmt)
// inflation adjust and topcode all spending
gen year = file_year

qui do "${allcode}/Inflation.do" "tot_pmt"

replace tot_pmt = 250000 if tot_pmt > 250000 & !missing(tot_pmt)
drop test* ptd* phys* othc* ptb* oproc* img* hos* hop* hh* dial* em* asc* anes* 
********************************************************************************


***** Now create globals for the table 
// we also want health stuff: SNF/hosp use and # in previous year
gen fem = (sex == "2")
gen white = (race == "1")
gen black = (race == "2")
gen hispanic = (race == "5")
gen other_race = (white != 1 & black != 1 & hispanic != 1)

preserve
keep bene_id file_year
duplicates drop
tempfile sample_benes
save `sample_benes', replace
restore

preserve
use "${input_datapath}/lasso_prob_snf_3folds.dta", clear
capture confirm variable l_pred_prob
if _rc {
	local predicted_var prob_snf
}
else {
	local predicted_var l_pred_prob
}
keep bene_id file_year `predicted_var'
drop if missing(file_year)
gcollapse (mean) predicted_snf = `predicted_var', by(bene_id file_year) fast
tempfile predicted_snf
save `predicted_snf', replace
restore

merge m:1 bene_id file_year using `predicted_snf', keep(1 3) nogenerate
replace predicted_snf = 0 if missing(predicted_snf)

local months 01 02 03 04 05 06 07 08 09 10 11 12
foreach i of local months {
	gen is_ffs_`i' = !inlist(buyin`i', "0", "1", "2", "A", "B") & inlist(hmoind`i', "0", "4") 
	gen is_hmo_`i' = inlist(hmoind`i', "1", "2", "A", "B", "C")
	gen is_dual_`i' = inlist(buyin`i', "A", "B", "C") 
}
egen is_ffs = rowmax(is_ffs_*) // at any point in year
egen is_hmo = rowmax(is_hmo_*)
egen is_dual = rowmax(is_dual_*)
drop is_ffs_* is_hmo_* is_dual_* 

gen snf = (snf_stays > 0 & !missing(snf_stays))
gen snf_no = snf_stays if !missing(snf_stays) & snf > 0
gen hosp = (acute_stays > 0 & !missing(acute_stays))
replace hosp = 1 if oip_stays > 0 & !missing(oip_stays)
gen hosp_no = acute_stays if hosp > 0 & !missing(acute_stays)
replace hosp_no = hosp_no + oip_stays if oip_stays > 0 & !missing(oip_stays)
replace hosp_no = oip_stays if missing(hosp_no) & oip_stays > 0 & !missing(oip_stays)

macro drop sum_* 
foreach v of varlist fem white black hispanic other_race is_* any_chronic predicted_snf tot_pmt snf* hosp* age year { // keep year last to get the N right
	sum `v' if group == 0 //index_id
	global sum_`v'_0: di %9.2fc `r(mean)'
	global sum_`v'_0_se: di %4.3fc `r(sd)'/sqrt(`r(N)')
	global sum_N_0: di %11.0fc `r(N)'
	
	sum `v' if group == 1 // response_id
	global sum_`v'_1: di %9.2fc `r(mean)'
	global sum_`v'_1_se: di %4.3fc `r(sd)'/sqrt(`r(N)')
	global sum_N_1: di %11.0fc `r(N)'
}
********************************************************************************


***** texdoc
texdoc init "$hoaglandoutput/sumstats-new.tex", replace force
tex \begin{table}[htbp]
tex \centering
tex \def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi}
tex \caption{Summary Statistics}\lab{tab:summary_stats}
tex \begin{tabular}{lcc}
tex \toprule
tex & Index Spouses & Focal Spouses \\ 
tex \midrule 
tex \multicolumn{3}{l}{\textbf{Panel A: Demographics}} \\
tex Age & ${sum_age_0} & ${sum_age_1} \\ 
tex & (${sum_age_0_se}) & (${sum_age_1_se}) \\
tex Female & ${sum_fem_0} & ${sum_fem_1} \\ 
tex & (${sum_fem_0_se}) & (${sum_fem_1_se}) \\
tex White & ${sum_white_0} & ${sum_white_1} \\ 
tex & (${sum_white_0_se}) & (${sum_white_1_se}) \\
tex Black & ${sum_black_0} & ${sum_black_1} \\ 
tex & (${sum_black_0_se}) & (${sum_black_1_se}) \\
tex Hispanic & ${sum_hispanic_0} & ${sum_hispanic_1} \\ 
tex & (${sum_hispanic_0_se}) & (${sum_hispanic_1_se}) \\
tex FFS Status & ${sum_is_ffs_0} & ${sum_is_ffs_1} \\ 
tex & (${sum_is_ffs_0_se}) & (${sum_is_ffs_1_se}) \\
tex HMO Status & ${sum_is_hmo_0} & ${sum_is_hmo_1} \\ 
tex & (${sum_is_hmo_0_se}) & (${sum_is_hmo_1_se}) \\
tex Dual Eligibility Status & ${sum_is_dual_0} & ${sum_is_dual_1} \\ 
tex & (${sum_is_dual_0_se}) & (${sum_is_dual_1_se}) \\
tex \midrule 
tex \multicolumn{3}{l}{\textbf{Panel B: Healthcare Utilization}} \\
tex Has a Chronic Condition & ${sum_any_chronic_0} & ${sum_any_chronic_1} \\ 
tex & (${sum_any_chronic_0_se}) & (${sum_any_chronic_1_se}) \\
tex Predicted Risk(SNF Stay) & ${sum_predicted_snf_0} & ${sum_predicted_snf_1}  \\
tex & (${sum_predicted_snf_0_se}) & (${sum_predicted_snf_1_se}) \\
tex SNF Stay, Any & ${sum_snf_0} & ${sum_snf_1} \\ 
tex & (${sum_snf_0_se}) & (${sum_snf_1_se}) \\
tex Conditional \# of SNF Stays & ${sum_snf_no_0} & ${sum_snf_no_1} \\ 
tex & (${sum_snf_no_0_se}) & (${sum_snf_no_1_se}) \\
tex Inpatient Admission, Any & ${sum_hosp_0} & ${sum_hosp_1} \\ 
tex & (${sum_hosp_0_se}) & (${sum_hosp_1_se}) \\
tex Conditional \# of Inpatient Admissions & ${sum_hosp_no_0} & ${sum_hosp_no_1} \\ 
tex & (${sum_hosp_no_0_se}) & (${sum_hosp_no_1_se}) \\
tex Total Spending & ${sum_tot_pmt_0} & ${sum_tot_pmt_1} \\ 
tex & (${sum_tot_pmt_0_se}) & (${sum_tot_pmt_1_se}) \\
tex \midrule 
tex Year & ${sum_year_0} & ${sum_year_1} \\ 
tex N & ${sum_N_0} &  ${sum_N_1}  \\
tex \bottomrule
tex \end{tabular}
tex \vspace*{0.29cm}
tex 
tex \begin{minipage}{1.05\textwidth} 
tex 
tex {\footnotesize \textit{Notes:} This table presents summary statistics for the analytical sample. Index spouses are those who experienced a first heart attack or stroke as discussed above; focal spouses are their partners whose outcomes we study. Averages with standard errors in parentheses are presented for the year prior to the true index event.}
tex \end{minipage}
tex \end{table}
texdoc close 
********************************************************************************
