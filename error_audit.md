# Error Audit

Issues are sorted by severity and prioritized toward silent logic errors, identification threats, and pipeline-breaking dependencies.

## Critical

1. `2_ResponseEvents_MDS.do:14-45` and `ValueHealthySpouse_Master.do:40-44`
Severity: Critical  
Problem: The MDS constructor drops all existing globals and then hard-codes a different project root mid-pipeline.  
Why it is risky: `macro drop _all` wipes the master's configured paths, and the replacement globals point to Jimmy Yung's external directories instead of the current replication tree. If the master script calls this file, every downstream script can read from or write to the wrong project, or fail because globals like `$hoaglandoutput` no longer exist.  
Suggested fix: Remove `macro drop _all`, stop redefining global paths inside the script, and either inherit the caller's globals or pass a local path block guarded by `if c(filename)==...` logic for standalone use only.

2. `1_IdentifyIndexEvents.do:109-114`
Severity: Critical  
Problem: The code computes the SNF-stay gap with `eventdate_ind`, which is not defined.  
Why it is risky: The NPI-linking block at the end of the index-event constructor will stop when it reaches `gen elapse = admsndt - eventdate_ind`, so `indexevents.dta` will not be updated with the SNF organization identifier used later for same-facility analyses.  
Suggested fix: Replace `eventdate_ind` with `eventdate_index` and rerun the end-of-file SNF-linking block.

3. `5_HealthEffectsTable_MEDPAR.do:84-97`
Severity: Critical  
Problem: The script overwrites the requested outcome with `local 1 = "fall"` immediately after collapsing the data.  
Why it is risky: The master calls this script for `snf`, `hospitalization`, `fall`, `num_ED`, and `snf_hosp`, but after line 85 every pre-mean, rescaling step, and regression targets `fall`. For non-fall runs that either fails outright because `fall` is absent after `gcollapse`, or produces the wrong estimates if `fall` happens to be present.  
Suggested fix: Delete line 85 entirely and keep the original argument `\`1''` through the rescaling and regression blocks.

4. `11_CostSharingRD.do:46-68,137-138`
Severity: Critical  
Problem: The RD builder references multiple variables that do not exist in the assembled sample (`response_event`, `index_female`) and also tries to `replace year = ...` after dropping `year`.  
Why it is risky: The script uses `response_event` where the response-event file stores `response_eventdt`, uses `index_female` where the panel stores `index_fem`, and never regenerates `year` before `replace year = year(response_eventdt)`. Those mistakes prevent `RDdata.dta` from being built, which blocks the main RD figure and Table 5.  
Suggested fix: Replace `response_event` with `response_eventdt`, replace `index_female` with `index_fem`, and change `replace year = year(response_eventdt)` to `gen year = year(response_eventdt)`.

5. `9_LASSOTable.do:90-96`
Severity: Critical  
Problem: The first comparison regression uses `hospital`, an undefined variable.  
Why it is risky: The script appears to intend a predicted-SNF comparison, but `reghdfe hospital ...` cannot run because the collapsed data contain `hospitalization`, `snf`, and `prob_snf`, not `hospital`. That breaks the LASSO table/figure branch before any output is written.  
Suggested fix: Replace `hospital` with the intended variable, almost certainly `hospitalization` if the goal is the constant-average-risk comparison or `prob_snf` if the goal is the predicted-SNF decomposition.

6. `3a_SummaryStatsTable.do:208`
Severity: Critical  
Problem: `black ! = 1` is invalid Stata syntax.  
Why it is risky: The summary-statistics script will stop at the construction of `other_race`, so Table 1 cannot be produced from a clean run.  
Suggested fix: Change the expression to `black != 1`.

## High

1. `ValueHealthySpouse_Master.do:43,68-72,127,130`
Severity: High  
Problem: The master driver calls several script names or paths that do not exist as written.  
Why it is risky: The tree contains `2c_ResponseEvents_Falls.do`, `5b_HealthEffectsTable_AverageEffects_MEDPAR.do`, and appendix files inside the `Appendix/` subdirectory, but the master asks for `2c_ResponseEvents_falls.do`, `5b_HealthEffectsTable_AverageEffects.do`, `Appendix_EventStudy_weeks_MEDPAR.do`, and `Appendix_LongrunResults_MEDPAR.do`. Those calls will fail on a clean or case-sensitive filesystem.  
Suggested fix: Update the master file to the exact on-disk names: `2c_ResponseEvents_Falls.do`, `5b_HealthEffectsTable_AverageEffects_MEDPAR.do`, `Appendix/Appendix_EventStudy_weeks_MEDPAR.do`, and `Appendix/Appendix_LongrunResults_MEDPAR.do`.

2. `ValueHealthySpouse_Master.do:62`, `5_HealthEffectsTable_MEDPAR.do:109-110,127-128,145-146`, `5a_MakeTable_MEDPAR.do:15`, `5b_HealthEffectsTable_AverageEffects_MEDPAR.do:104-105`
Severity: High  
Problem: The Table 2 staging dataset is initialized under one filename and read/appended under another.  
Why it is risky: The master creates `5_HealthEffectsTable_MEDPAR.dta`, but every downstream script reads or appends `5_HealthEffectsTable.dta`. On a clean run the first `append using "$hoaglandoutput/5_HealthEffectsTable.dta"` will fail, and on a dirty run the code could silently reuse a stale file from a previous session.  
Suggested fix: Standardize all of these references to a single filename, preferably `5_HealthEffectsTable_MEDPAR.dta`, in the master, Scripts 5/5a/5b, and any cleanup logic.

3. `2_ResponseEvents_MEDPAR.do:73-81`
Severity: High  
Problem: The ADRD discharge loop checks `dgnscd1` for most code lists even when looping over `dgnscd2` through `dgnscd10`.  
Why it is risky: Only the first diagnosis position is fully scanned for ADRD discharge codes; diagnoses 2--10 are partially ignored, so ADRD-related response events are systematically undercounted. Any downstream analysis that uses `adrd_disc` or related sample splits will be mismeasured without an obvious failure.  
Suggested fix: Replace each `dgnscd1` inside the loop body with `dgnscd\`i''` so that every diagnosis slot is evaluated against the full code list.

4. `Appendix/Appendix_EventStudy_weeks_MEDPAR.do:40-46`
Severity: High  
Problem: The weekly appendix script uses `reltime_w`, which is never created.  
Why it is risky: The file only has `reltime_weeks`, so the window restriction, event-time recoding, and `gcollapse` keys all fail before the weekly figure is estimated.  
Suggested fix: Replace each `reltime_w` reference with `reltime_weeks`.

5. `4_MainEventStudy_MDS.do:19-29`, `6_MainEventStudy_FatalitySplit_MDS.do:20,48-56,90-96`, `7a_SplitEffects_ChronicCondition_MDS.do:18,121-138`, `7b_SplitEffects_IndexDischarge_MDS.do:20,108-126`, `Appendix/Appendix_SplitEffects_IndexLOS_MDS.do:18,109-129`
Severity: High  
Problem: The MDS analysis branch is disconnected from the rest of the replication tree.  
Why it is risky: `4_MainEventStudy_MDS.do` hard-codes an external `main_eventstudy.dta`, while the other MDS split scripts assume an in-memory variable `nosurvive` and a global `$output_path` that are never defined anywhere in this tree. As written, these scripts either pull stale results from an outside workspace or fail when they try to subset or save outputs.  
Suggested fix: Rewire all MDS scripts to use locally generated inputs from this project, define survival flags inside the script from `mortality.dta`, and replace `$output_path` with the same output global used by the master (`$hoaglandoutput` or a passed local).

6. `11b_CostSharingRD_EventStudy.do:14-54,88`
Severity: High  
Problem: The code that creates `affected_SNFstays.dta` is commented out, but the live regression still merges that file.  
Why it is risky: A clean run cannot reproduce Figure 8 because the only builder for `affected_SNFstays.dta` is inside a block comment. The script will therefore fail unless an old copy of the intermediate already exists in the data directory.  
Suggested fix: Uncomment and repair the stay-construction block, or move it into a separate precursor script that the master runs before `11b_CostSharingRD_EventStudy.do`.

7. `Appendix/Appendix_Eventstudy_agesplits_MEDPAR.do:11,15`
Severity: High  
Problem: The age-split appendix script bypasses the local pipeline and reads an external branch dataset directly.  
Why it is risky: It uses a hard-coded `/disk/.../chars_weekpanel.dta` path rather than anything built inside the current tree, so the figure is not reproducible from the local scripts and can silently reflect stale or branch-specific data.  
Suggested fix: Either generate `chars_weekpanel.dta` inside this repository or switch the script to merge the needed age fields onto the local `weekpanel.dta`.

8. `Appendix/Appendix_DDiscSplit_QuarterofYear.do:14` and `Appendix/Appendix_DDiscSplit_ADRD.do:14-18`
Severity: High  
Problem: Two appendix RD tables depend on derived inputs that are not created anywhere in this tree.  
Why it is risky: `RDdata_fullyear.dta` and `ADRDdx.dta` are never written by any script under `SpousalSpillovers`, so Appendix Tables A3 and A4 cannot be reproduced end-to-end from the current code alone.  
Suggested fix: Add explicit builder scripts for those datasets and call them from the master, or document them as required shipped inputs and store them under the project's data root.

9. `Appendix/Appendix_DDiscSplit_EventType.do:20-106`
Severity: High  
Problem: The script is wired into the master as Appendix Table A1, but it never exports a table.  
Why it is risky: It runs subgroup regressions, stores globals, and ends with a placeholder comment about a p-value; there is no `texdoc`, `putexcel`, or saved result file. A master run therefore cannot produce the event-type appendix table it claims to produce.  
Suggested fix: Add a final formatting/export block, or remove the master call until the table-writing step is implemented.

## Medium

1. `5a_MakeTable_MEDPAR.do:16-19`
Severity: Medium  
Problem: Significance stars are computed from a one-sided p-value formula.  
Why it is risky: `1 - normal(abs(coef/stderr))` is half the usual two-sided p-value, so stars will be assigned too aggressively even when the underlying regression results are correct. That changes the reported significance in Table 2 without changing the coefficients.  
Suggested fix: Replace the formula with `2 * (1 - normal(abs(coef/stderr)))`.

2. `Appendix/Appendix_MainEventStudy_gendersplit_MEDPAR.do:65-67`
Severity: Medium  
Problem: The interaction test refers to `index_female`, but the regression uses `index_fem`.  
Why it is risky: The subgroup regressions themselves can run, but the reported joint p-value for gender differences will fail or test the wrong interaction term because the factor-variable name does not match the model specification.  
Suggested fix: Change every `index_female` in the `test` statement to `index_fem`.

3. `11_CostSharingRD.do:268-270`
Severity: Medium  
Problem: The second RD table column reuses the first column's significance stars.  
Why it is risky: Column 2 reports FE estimates `b_rdpre_2` and `b_rdpost_2`, but the table interpolates `${p_rdpre_1}` and `${p_rdpost_1}` rather than `${p_rdpre_2}` and `${p_rdpost_2}`. Readers can therefore see the wrong star pattern even if the estimates themselves are correct.  
Suggested fix: Replace `${p_rdpre_1}` with `${p_rdpre_2}` and `${p_rdpost_1}` with `${p_rdpost_2}` in the `texdoc` block.

4. `3a_SummaryStatsTable.do:195,275-276`
Severity: Medium  
Problem: Table 1 still contains an unresolved external helper path and hard-coded `TK` placeholders for predicted SNF risk.  
Why it is risky: Even after fixing the syntax error, the summary table depends on an off-tree `Inflation.do` path and emits incomplete cells in the predicted-risk row, so the pipeline produces a visibly unfinished table.  
Suggested fix: Call the local `Inflation.do` in this repository and replace the `TK` placeholders with code that merges and summarizes the predicted SNF-risk measure from the LASSO branch.
