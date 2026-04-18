/*******************************************************************************
* Title: Master Code File for the paper: "The Protective Effects of a Healthy Spouse: Medicare as the Family Member of Last Resort"
* Created by: Alex Hoagland
* Created on: 2/8/22
* Last modified on: 4/14/2026
* Last modified by: Alex Hoagland
* Purpose: Use this to run main code for paper

* NOTES: 
	- contains primary globals, etc. 
	- last successful replication: November 2025
*******************************************************************************/


// low-tech way of preventing rewriting 
DO YOU REALLY WANT TO RERUN THIS WHOLE DOCUMENT? COMMENT THIS OUT IF SO.

**** Globals
set more off
macro drop _all 

version 15 // so that .gph files save in a way my old machine can read

global head // Set to location of replication package, ex: "/homes/nber/hoagland-dua54204/layton-DUA54204/WorkingDatasets/Replication_Package"
global allcode // Set to subdirectory where code files are stored, ex: "$head/code/swap-indexevents/ValueHealthySpouse_Replication"
global input_datapath // Set to subdirectory where temporary data are stored, ex: "$head/output_dataset/ReplicationData"
global hoaglandoutput // Set to subdirectory where outputs are stored, ex: "$head/output/Outputs"

global today: di %td_CYND date("$S_DATE", "DMY")
global today $today // second command removes leading spaces 

set scheme cblind1
set seed 081323
********************************************************************************


***** Data setup *****
do "$allcode/1_IdentifyIndexEvents.do"  // all MEDPAR claims, with flags for severity; filtered below
do "$allcode/2_ResponseEvents_MEDPAR.do" // identify all response events using the MEDPAR file 
do "$allcode/2_ResponseEvents_MDS.do" // identify all response events using the MDS file 
do "${allcode}/2a_ResponseEvents_ED.do" // all ED visits 
do "${allcode}/2b_ResponseEvents_mortality.do" // mortality 
do "${allcode}/2c_ResponseEvents_Falls.do" // falls
do "${allcode}/3_ConstructPanel.do"
********************************************************************************


***** Main tables and figures
// Table 1: Summary stats
do "$allcode/3a_SummaryStatsTable.do" 

// Figures 1, 2, Appendix Figure A7: SNF effects -- overall MDS, MEDPAR (and entry, for Appendix)
do "$allcode/4_MainEventStudy_MEDPAR.do" "snf" "balanced"
do "$allcode/4_MainEventStudy_MDS.do" "snf_mds" "balanced" // this runs all outcomes, doesn't need additional arguments
do "$allcode/4a_MainEventStudy_snf-entry.do" "balanced" 
	// constructs data for the MEDPAR version of the Appendix figure (the MDS output is estimated above)

// Table 2: multiple outcomes
// THIS STILL NEEDS TO BE UPDATED WITH MDS
clear
gen model = ""
save "$hoaglandoutput/5_HealthEffectsTable_MEDPAR.dta", replace // blank data for table 
do "$allcode/5_HealthEffectsTable_MEDPAR.do" "snf" "balanced"
do "$allcode/5_HealthEffectsTable_MEDPAR.do" "hospitalization" "balanced"
do "$allcode/5_HealthEffectsTable_MEDPAR.do" "fall" "balanced" 
do "$allcode/5_HealthEffectsTable_MEDPAR.do" "num_ED" "balanced"
do "$allcode/5_HealthEffectsTable_MEDPAR.do" "snf_hosp" "balanced"
do "$allcode/5b_HealthEffectsTable_AverageEffects_MEDPAR.do" "snf" "balanced" // average effects run separately for speed
do "$allcode/5b_HealthEffectsTable_AverageEffects_MEDPAR.do" "hospitalization" "balanced"
do "$allcode/5b_HealthEffectsTable_AverageEffects_MEDPAR.do" "num_ED" "balanced"
do "$allcode/5b_HealthEffectsTable_AverageEffects_MEDPAR.do" "fall" "balanced"
do "$allcode/5b_HealthEffectsTable_AverageEffects_MEDPAR.do" "snf_hosp" "balanced"
do "$allcode/5a_MakeTable_MEDPAR.do" // produces tex code for table 

// Figure 3: split by fatal/nonfatal 
do "$allcode/6_MainEventStudy_FatalitySplit_MDS.do" "balanced" // MEDPAR code exists as well

// FIGURE 4: Stratified by if the outcome spouse has a chronic condition
do "${allcode}/7a_SplitEffects_ChronicCondition_MDS.do" "snf" "balanced"

// FIGURE 5: Stratified by shock spouse's severity 
do "${allcode}/7b_SplitEffects_IndexDischarge_MDS.do" "snf" "balanced"

// Figure 6: Mortality Effects
do "$allcode/8_MortalityEffects.do"

// Table 3: change in predicted prob(SNF) using LASSO and costant aerage marginal effects
do "$allcode/9_LASSO_predict_snf.do" // run the LASSO model
do "$allcode/9_merge_LASSOdata.do" // merge into main panel 
do "$allcode/9_LASSOTable.do" // makes the appendix figures and the data needed for the table. 
// OLD: do "$allcode/4_MainEventStudy.do" "prob_snf" "balanced" 

// TABLE 4: Yearly spending (BSF)
do "$allcode/10_AnnualSpending.do"

// FIGURE 7: RD plot (histograms + first stage)
do "$allcode/11_CostSharingRD.do" 
	// this also makes Table 5 (Diff-in-disc table)
	// this is pooled

// Table 5 as reported in text has chronic condition split
do "$allcode/11a_CostSharingRD_ChronicCondition.do" 
 
// FIGURE 8: fraction of SNF stays not fully covered
do "$allcode/11b_CostSharingRD_EventStudy.do"

// FIGURE 9: Heat map for structural model welfare estimates -- produced in R

********************************************************************************


***** Appendix A: Figures ****
// Figure A1: Robustness to alternative specifications
do "$allcode/Appendix/Appendix_Validate_Specification_MEDPAR.do" // TODO: update with MDS 

// Figure A2: circularity 
do "$allcode/Appendix/Appendix_Circularity.do" "balanced"

// Figure A3: robustness to alternative event definitions 
do "$allcode/Appendix/Appendix_ExtraHouseholdEvents_EventStudy_MEDPAR.do" // -- balanced
do "$allcode/Appendix/Appendix_Robustness_No2YearRequirement_MEDPAR.do" // -- balanced

// Figure A4: gender symmetry 
do "$allcode/Appendix/Appendix_MainEventStudy_gendersplit_MEDPAR.do" "snf" 

// Figure A5: weekly results
do "$allcode/Appendix/Appendix_EventStudy_weeks_MEDPAR.do" "snf" "balanced"

// Figure A6: Long-run results
do "$allcode/Appendix/Appendix_LongrunResults_MEDPAR.do"

// Figure A7: made above

// Figure A8: location of SNFs 
do "$allcode/Appendix/Appendix_LocationPreferences_MEDPAR.do" "balanced"

// Figure A9: event studies for individual health outcomes, made above

// Figure A10: non-SNF nursing homes, made above

// Figure A11: Split by Age (gaps)
do "$allcode/Appendix/Appendix_Eventstudy_agesplits_MEDPAR.do" "balanced"

// Figure A12: Split by Race
do "$allcode/Appendix/Appendix_SplitEffects_Race_MEDPAR.do" "balanced"

// Figure A13: Split by Index LOS 
do "$allcode/Appendix/Appendix_SplitEffects_IndexLOS_MDS.do" "balanced"

// Figure A14: SNF Effects by Time of Death over Year
do "$allcode/Appendix/Appendix_SplitEffect_TimeofDeath_MEDPAR.do" "balanced"

// Figure A15: Unbalanced panel results (can be constructed using the code above)

// Figure A16: Predicted Probability of Discharge (validation) -- made above in "$allcode/Appendix/LASSO_predict_snf.do"

// Figure A17: Change in predicted probability of SNF -- made above

// Figure A18: LOS for SNF stays -- made above ("$allcode/10a_CostSharingRD_EventStudy.do")

********************************************************************************


***** Appendix A: Tables ****
// Table A1: D-disc by event type
do "$allcode/Appendix/Appendix_DDiscSplit_EventType.do" 

// Table A2: D-disc by gender
do "$allcode/Appendix/Appendix_DDiscSplit_Gender.do" 

// Table A3: D-disc by ADRD
do "$allcode/Appendix/Appendix_DDiscSplit_ADRD.do" 

// Table A4: D-disc over Course of Year  
do "$allcode/Appendix/Appendix_DDiscSplit_QuarterofYear.do" 
********************************************************************************


***** Appendix B -- all tables and figures come from R ****
