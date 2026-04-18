/*******************************************************************************
* Title: Response Events (Minimum Dataset) 
* Created by: Jimmy Yung
* Created on: 12/1/2025
* Last modified on: ...
* Last modified by: Jimmy Yung
* Purpose: This file cleans and appends SNF stays (Medicare & Non-medicare) onto
the analysis dataset


* NOTES: 
	
*******************************************************************************/
version 15 // so that .gph files save in a way my old machine can read
// set maxvar 100000
// ssc install ereplace

if `"`input_datapath'"' == "" {
	global project_head "/homes/nber/kwtjima-dua58151/layton-DUA58151"
	global head "$project_head/kwtjima-dua58151"
	global input_datapath "$head/data/derived"
}

if `"`today'"' == "" {
	global today: di %td_CYND date("$S_DATE", "DMY")
	global today $today // second command removes leading spaces
}

// set scheme cblind1
set seed 081323

********************************************************************************
*** Globals ********************************************************************
********************************************************************************

// Path to cleaned dataset
if `"$raw_stacked_mds"' == "" global raw_stacked_mds "${input_datapath}/responseevents-stacked-MDS.dta"
if `"$cleaned_mds"' == "" global cleaned_mds "${input_datapath}/responseevents-MDS.dta"
if `"$raw_stacked_mds_backup"' == "" global raw_stacked_mds_backup "${input_datapath}/responseevents-MDS_backup.dta"
if `"$mds"' == "" global mds "$project_head/extracts/mds/20220808/100pct"
if `"$cleaned_stays"' == "" global cleaned_stays "${input_datapath}/MDS-stays.dta"
if `"$cleaned_stays_1p"' == "" global cleaned_stays_1p "${input_datapath}/MDS-stays_1p.dta"


// Final dta, empty initially, to be appended with observations 
tempfile responsevents_mds
gen bene_id = ""
gen dschrg_dt = ""
gen trgt_dt = ""
gen submsn_dt = ""
gen entry_dt = ""
gen reentry_dt = ""
gen year = .
gen dschrg_cd = ""
gen fac_int_id = .
save "${raw_stacked_mds}", replace


********************************************************************************
*** Stack Datasets from 2008 - 2017 ********************************************
********************************************************************************


// Stack observations from each year (MDS V2)
forvalues Y = 2008/2009 {
	dis "Grabbing `Y' MDS observations"
	use bene_id target_date submission_date ab1_entry_dt r3a_discharge_cd fac_int_id a4a_reentry_dt ///
		using "$mds/V2/mds2_`Y'.dta", clear
	keep if bene_id != ""
	rename (target_date submission_date ab1_entry_dt r3a_discharge_cd a4a_reentry_dt) ///
	       (trgt_dt submsn_dt entry_dt dschrg_cd reentry_dt)
	gen year = `Y'
	gen dschrg_dt = trgt_dt if dschrg_cd != ""
	append using "${raw_stacked_mds}"
	save "${raw_stacked_mds}", replace
} 	

		
	
// Stack observations from each year (MDS V3)
forvalues Y = 2010/2016 {
	dis "Grabbing `Y' MDS observations"
	use bene_id trgt_dt submsn_dt a1600_entry_dt a0310f_entry_dschrg_cd fac_prvdr_intrnl_id ///
		using "$mds/V3/mds3_`Y'.dta", clear
	keep if bene_id != ""
	rename (a1600_entry_dt a0310f_entry_dschrg_cd fac_prvdr_intrnl_id) ///
	       (entry_dt dschrg_cd fac_int_id)
	
	// Infer Discharge Date using Target Date and Discharge Code 
	// to harmonize with MDS 2017 which has no given discharge date
	gen dschrg_dt = trgt_dt if inlist(dschrg_cd, "10", "11", "12") 
	
	gen year = `Y'
	append using "${raw_stacked_mds}"
	save "${raw_stacked_mds}", replace
} 


// 2017 MDS V3 has its own formatting
dis "Grabbing 2017 MDS observations"
use bene_id ///
    clndr_trgt_dt_sk_6 ///
    clndr_submsn_dt_sk_4 ///
    entry_dschrg_cd_3 ///
    clndr_entry_dt_sk_1 ///
    prvdr_fac_intrnl_num ///
    using "$mds/V3/mds3_2017.dta"
rename (clndr_trgt_dt_sk_6 clndr_submsn_dt_sk_4 entry_dschrg_cd_3 clndr_entry_dt_sk_1 prvdr_fac_intrnl_num) ///
       (trgt_dt submsn_dt dschrg_cd entry_dt fac_int_id)
keep if bene_id != ""
// Discharge date as date they were discharged or died       
gen dschrg_dt = trgt_dt if inlist(dschrg_cd, "10", "11", "12") 
gen year = 2017 
append using "${raw_stacked_mds}"
save "${raw_stacked_mds}", replace
save "$raw_stacked_mds_backup", replace


/* Checks */
// this actually refers to discharges inlist(dschrg_cd, "10", "11", "12")

use "$raw_stacked_mds_backup", clear

// take 1% random sample
preserve
contract bene_id
sample 1
keep bene_id
save "random_bene_ids.dta", replace
restore
merge m:1 bene_id using "random_bene_ids.dta", keep(3) nogen
save "${input_datapath}/responseevents-MDS_backup_1p.dta", replace
erase "random_bene_ids.dta"


********************************************************************************
*** Clean **********************************************************************
********************************************************************************


// Helper function
cap program drop pull
program define pull
args bene_id
br if bene_id == "`bene_id'"
end


use "${raw_stacked_mds}", clear
// use "${input_datapath}/responseevents-MDS_backup_1p.dta", clear
drop submsn

// Having a discharge code in 2008/9 means discharge.
replace dschrg_dt = trgt_dt ///
		if !missing(dschrg_cd) ///
		& inlist(year, 2008, 2009)

// Convert date variables to datetime variables for min/max operations
foreach D in trgt entry dschrg reentry {
	gen `D'_dt_tmp = date(`D'_dt,"YMD")
	format `D'_dt_tmp %td
	drop `D'_dt
	rename `D'_dt_tmp `D'_dt
}

/* Drop useless noisy obs */ {

	// Duplicates
	duplicates drop bene_id fac_int_id trgt_dt entry_dt reentry_dt dschrg_dt, force

	// Drop assessments if they have no information while other assessments of
	// the same date show entry/reentry/discharge dates
	foreach V in entry_dt reentry_dt dschrg_dt {
		bysort bene_id fac_int_id trgt_dt: ///
			egen `V'_info = count(`V')
	}
	gen same_dt_available_info = entry_dt_info + reentry_dt_info + dschrg_dt_info 
	drop ///
		if missing(entry_dt) ///
		& missing(reentry_dt) ///
		& missing(dschrg_dt) ///
		&  same_dt_available_info != 0
	drop *_info
}
	

/* First run: eliminate erroraneous inputs */

	/* Arrange assessments in order */ {
	/* A bit troublesome, sometimes there are multiple assessments on the same day
	   probably due to same day discharges and reentries. So sort them by assessment
	   dates and put discharges first then reentries if non empty 
	   
	 > But this doesn't make sense if it's the last obs we see. So in that case,
	   put reentry over discharge.*/
	   
		   
	   // Generate order variable 
	   // (vars in brackets are arranged st non empty is first)
	   bysort bene_id fac_int_id (trgt_dt dschrg_dt reentry_dt): ///
		   gen order = _n
										
		// Put re-entry first if last.				
		// Flip the order of discharge and reentry if reentry is the last one
		// and last reentry is not within 6 months of data cutoff in which case
		// reentry is valid
		bysort bene_id fac_int_id (trgt_dt dschrg_dt reentry_dt): ///
		   replace order = order[_n+1] if !missing(dschrg_dt[_n]) ///
										& missing(dschrg_dt[_n+1]) /// identifies entries
										& trgt_dt[_n] == trgt_dt[_n+1] ///
										& entry_dt[_n] == entry_dt[_n+1] ///
										& (_n+1 == _N | _n == 1)
																	
		bysort bene_id fac_int_id (trgt_dt dschrg_dt reentry_dt): ///
		   replace order = order - 1 if !missing(dschrg_dt[_n-1]) ///
										& missing(dschrg_dt[_n]) ///
										& trgt_dt[_n] == trgt_dt[_n-1] ///
										& entry_dt[_n] == entry_dt[_n-1] ///
										& (_n == _N | _n == 2)
		
		// Quick check that unless it's the last two obs, order increments by 1
		bys bene_id fac_int_id (trgt_dt dschrg_dt reentry_dt): ///
			assert (order == order[_n-1]+1) ///
			if _n>3 & (_n+1 != _N & _n != _N)
	   
	}

	/* Helpful variables */ {
	   
		// Time from last assessment: split into two stays if last assessment
		// is over 6 months ago
		bysort bene_id fac_int_id (order): ///
			gen assmnt_gap = trgt_dt - trgt_dt[_n-1]
			
		/* End of stay indicator */
		
			// Self is discharge and next is not discharge 
			// (compatible with consecutive discharge submissions)
			bysort bene_id fac_int_id (order): ///
				gen stay_ends = 1 ///
					if !missing(dschrg_dt[_n]) ///
					& missing(dschrg_dt[_n+1]) ///
					& _n < _N
			
			// Self is discharge and no next
			bysort bene_id fac_int_id (order): ///
				replace stay_ends = 1 ///
					if !missing(dschrg_dt[_n]) ///
					& _n == _N
			
			/* Missing discharge records */
			
				// Entry date suddenly changes (for years >= 2010)
				// and there's no discharge record
				bysort bene_id fac_int_id (order): ///
					replace stay_ends = 1 ///
						if year >= 2010 ///
						& missing(stay_ends) ///
						& entry_dt[_n] != entry_dt[_n+1] ///
						& missing(dschrg_dt[_n+1]) ///
						& trgt_dt[_n] < entry_dt[_n+1] ///
						& _n < _N
						
				
				// Sudden reentry without prior discharge
				// This just takes the first reentry (but could be erroraneous)
	// 			bysort bene_id fac_int_id (order): ///
	// 				replace stay_ends = 1 ///
	// 					if inlist(year, 2008, 2009) ///
	// 					& missing(stay_ends) ///
	// 					& missing(reentry_dt) ///
	// 					& !missing(reentry_dt[_n+1]) ///
	// 					& _n < _N 
				
				// 180 days since last assessment
				bys bene_id fac_int_id (order): ///
					replace stay_ends = 1 ///
						if missing(stay_ends) ///
						& assmnt_gap[_n+1] >= 180 ///
						& _n < _N
						
				// Last is 6m prior to data timeline end but no discharge 
				bys bene_id fac_int_id (order): ///
					replace stay_ends = 1 ///
						if missing(stay_ends) ///
						& (trgt_dt - td(30jun2017) <= 0) ///
						& _n == _N
						
			
		/* New stay indicator */
		
			// First obs
			bys bene_id fac_int_id (order): ///
				gen stay_starts = 1 ///
					if _n == 1
					
			// Has prior discharge
			bys bene_id fac_int_id (order): ///
				replace stay_starts = 1 ///
					if stay_ends[_n-1] == 1 ///
					& _n > 1
		
	}
	   
	/* Identify Discharge Dates */ {
	/* Rule 1: Discharge codes are different between MDS V2 and V3. So having a 
		   discharge code in 2008/9 means discharge. */

		// (1) Identify Discharge Records
		gen dschrg_dt_ext = dschrg_dt ///
			if stay_ends == 1
		replace dschrg_dt_ext = trgt_dt ///
			if missing(dschrg_dt_ext) ///
			& stay_ends == 1
		format dschrg_dt_ext %td
		
		//(2) Expand up until reaches row before next stay_ends
		gsort bene_id fac_int_id -order
		by bene_id fac_int_id: ///
			replace dschrg_dt_ext = dschrg_dt_ext[_n-1] ///
			if missing(dschrg_dt_ext) ///
			& stay_ends != 1 ///
			& _n > 1
			
	}

	/* Identify Entry Dates */ {
	/* - Rule 1: Only 2008 and 2009 have missing entry dates
	   - Rule 2: entry_dt mens first entry date for 2008 - 2009 while it means 
			 contemporaneous entry date after 2009
	   - Rule 2: If an observation has both an entry date and a reentry date, 
			 use the reentry date because in this case, the entry always refers
			 the first SNF entry date (i.e. prior to the current one). 
			 Reentry date hence superceedes in 2008-2009.
	   - Rule 3: Use first assessment date as entry date if neither entry nor reentry
			 date is present
	   - Rule 4: Entry dates can only increase with time
	   
	   Goal: Create a column (entry_dt_ext) that states the entry date of the 
		 current SNF visit */
		
	   
		// (1) Mark all the entry points
		gen entry_dt_ext = .
		
		// No questions asked bc first obs
		// Enforce less than or equal to dschrg_dt
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = reentry_dt ///
				if inlist(year, 2008, 2009) ///
				& stay_starts == 1 /// 
				& missing(entry_dt_ext) ///
				& reentry_dt <= dschrg_dt ///
				& _n == 1
				
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = entry_dt ///
				if stay_starts == 1 /// 
				& missing(entry_dt_ext) ///
				& entry_dt <= dschrg_dt ///
				& _n == 1
				
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = trgt_dt ///
				if stay_starts == 1 /// 
				& missing(entry_dt_ext) ///
				& trgt_dt <= dschrg_dt ///
				& _n == 1
		
		
		// 2008 2009 Specific 
		// Enforce that the date needs to be at least last discharge
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = reentry_dt ///
				if inlist(year, 2008, 2009) ///
				& missing(entry_dt_ext) ///
				& stay_starts == 1 ///
				& reentry_dt >= dschrg_dt[_n-1] ///
				& _n > 1
			
		// Use target date or entry date depending on distance from last discharge
			bys bene_id fac_int_id (order): ///
				replace entry_dt_ext = entry_dt ///
					if inlist(year, 2008, 2009) ///
					& stay_starts == 1 ///
					& assmnt_gap < 180 ///
					& missing(entry_dt_ext) ///
					& entry_dt >= dschrg_dt[_n-1] ///
					& _n > 1
					
			bys bene_id fac_int_id (order): ///
				replace entry_dt_ext = trgt_dt ///
					if inlist(year, 2008, 2009) ///
					& stay_starts == 1 ///
					& missing(entry_dt_ext) ///
					& assmnt_gap < 180 ///
					& trgt_dt >= dschrg_dt[_n-1] ///
					& _n > 1
					
			// Revisit when using entry_dt, use trgt_dt if closer to last dschrg_dt
			bys bene_id fac_int_id (order): ///
				replace entry_dt_ext = trgt_dt ///
						if inlist(year, 2008, 2009) ///
						& stay_starts == 1 ///
						& (entry_dt_ext == entry_dt) ///
						& assmnt_gap < 180 ///
						& trgt_dt < entry_dt ///
						& trgt_dt >= dschrg_dt_ext[_n-1] ///
						& _n > 1
						
			bys bene_id fac_int_id (order): ///
				replace entry_dt_ext = trgt_dt ///
					if inlist(year, 2008, 2009) ///
					& stay_starts == 1 ///
					& missing(entry_dt_ext) ///
					& assmnt_gap >= 180 ///
					& _n > 1
			
						
		// Post 2009
		// Use entry_dt for usual entries
		// Manual split at 180 should use trgt_dt
		// Enforce that the date needs to be at least last discharge
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = entry_dt ///
					if year >= 2010 ///
					& stay_starts == 1 ///
					& missing(entry_dt_ext) ///
					& assmnt_gap < 180 ///
					& entry_dt >= dschrg_dt[_n-1] ///
					& _n > 1
			
				
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = trgt_dt ///
					if year >= 2010 ///
					& stay_starts == 1 ///
					& missing(entry_dt_ext) ///
					& assmnt_gap >= 180 ///
					& trgt_dt >= dschrg_dt[_n-1] ///
					& _n > 1
				
				
		// Default to trgt_dt if entry_dt is empty
		replace entry_dt_ext = trgt_dt ///
				if year >= 2010 ///
				& stay_starts == 1 ///
				& missing(entry_dt_ext)
				
		format entry_dt_ext %td
		
		// (2) Expand until row of next study start
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = entry_dt_ext[_n-1] ///
				if missing(entry_dt_ext) ///
				& stay_starts != 1 ///
				& _n > 1
		
	}
	
	
	// These records make no difference 
	// since they're included in the last visit. 
	bys bene_id fac_int_id (order): ///
		gen useless = 1 ///
			if entry_dt_ext == dschrg_dt_ext ///
			& entry_dt_ext == dschrg_dt_ext[_n-1] ///
			& _n > 1
	bys bene_id fac_int_id (order): ///
		replace useless = 1 ///
			if entry_dt_ext == dschrg_dt_ext ///
			& dschrg_dt_ext == entry_dt_ext[_n+1] ///
			& _n < _N

	// seems like some same days are left in second run
	drop if useless == 1
	drop useless
	
// 	drop order assmnt_gap stay_starts stay_ends dschrg_dt_ext entry_dt_ext

	
	
		
********************************************************************************
*** Checks *********************************************************************
********************************************************************************
	
	
	/* Missing values */
        qui ds dschrg_cd entry_dt dschrg_dt reentry_dt ///
			   assmnt_gap dschrg_dt_ext stay_ends stay_starts, not
        foreach V in `r(varlist)' {
            qui count if missing(`V')
            local n = r(N)
            cap assert `n' == 0
            if _rc {
                dis as error "`n' unauthorized missing values in `V'"
				error 9
            }
        }
	
	
	/* Missing is as intended */ {
	/* > dschrg_cd: only 2008 and 2009 have missing dschrg_cd, non discharge days
	   > entry_dt: only 2008 2009 have missing entry_dt, should have either
		       reentry_dt or dschrg_dt instead. Sometimes just plain 
		       missing, usually within assmnt_gap<180 bc still within 
		       same visit
	   > dschrg_dt: not discharge dates (no discharge code)
	   > reentry_dt: only 2008 and 2009 uses reentry_dt, either discharge
			 date or first entry so has entry_dt Sometimes just 
			 plain missing, usually within assmnt_gap<180 bc still
			 within same visit
	   > assmnt_gap: first visit
	   > dschrg_dt_ext: hasn't checked out yet but should all be in 2017*/
		
		
		// dschrg_cd
		local V dschrg_cd
		qui count if missing(dschrg_cd)
		local n1 = r(N)
		qui count if missing(dschrg_cd) ///
					 & inlist(year, 2008, 2009) ///
					 & missing(dschrg_dt)
		local n2 = r(N)
		local diff = `n1' - `n2'
		cap assert `diff' == 0 
        if _rc {
            dis as error "`diff' unauthorized missing values in `V'"
            error 9
        }
	
        // entry_dt
        local V entry_dt
        qui count if missing(entry_dt)
        local n1 = r(N)
        // Either 'reentry' or 'discharge' date
        qui count if missing(entry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (!missing(reentry_dt) | !missing(dschrg_dt))
        local n2 = r(N)
        // Neither reentry nor discharge date found so used
        // first trgt_date or entry_dt as entry
        qui count if missing(entry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (missing(reentry_dt) & missing(dschrg_dt)) ///
                 & (entry_dt_ext == trgt_dt | entry_dt_ext == entry_dt) 
        local n3 = r(N)
        // Sometimes non entry or discharge assements have missing entry_dt
        // but still within same visit 
        qui count if missing(entry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (missing(reentry_dt) & missing(dschrg_dt)) ///
                 & (entry_dt_ext != trgt_dt & entry_dt_ext != entry_dt) ///
                 & assmnt_gap < 180
        local n4 = r(N)
        local diff = `n1' - `n2' - `n3' - `n4'
        cap assert `diff' == 0 
        if _rc {
            dis as error "`diff' unauthorized missing values in `V'"
            error 9
        }

		
        // dschrg_dt
        local V dschrg_dt
        qui count if missing(dschrg_dt)
        local n1 = r(N)
        qui count if missing(dschrg_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & missing(dschrg_cd)
        local n2 = r(N)
        qui count if missing(dschrg_dt) ///
                 & !inlist(year, 2008, 2009) ///
                 & !inlist(dschrg_cd, "10", "11", "12")
        local n3 = r(N)
        local diff = `n1' - `n2' - `n3'
        cap assert `diff' == 0 
        if _rc {
            dis as error "`diff' unauthorized missing values in `V'"
            error 9
        }
      
      
        // reentry_dt
        local V reentry_dt
        qui count if missing(reentry_dt)
        local n1 = r(N)
        // 2010-2017
        qui count if missing(reentry_dt) ///
                 & !inlist(year, 2008, 2009)
        local n2 = r(N)
        // Either first 'entry' or 'discharge' date
        qui count if missing(reentry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (!missing(entry_dt) | !missing(dschrg_dt))
        local n3 = r(N)
        // Neither reentry nor discharge date found so used
        // first trgt_date or entry_dt as entry
        qui count if missing(reentry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (missing(entry_dt) & missing(dschrg_dt)) ///
                 & (entry_dt_ext == trgt_dt | entry_dt_ext == entry_dt)  
        local n4 = r(N)		
        // Sometimes non entry or discharge assements have missing entry_dt
        // but still within same visit 
        qui count if missing(reentry_dt) ///
                 & inlist(year, 2008, 2009) ///
                 & (missing(entry_dt) & missing(dschrg_dt)) ///
                 & (entry_dt_ext != trgt_dt & entry_dt_ext != entry_dt) ///
                 & assmnt_gap < 180
        local n5 = r(N)
        local diff = `n1' - `n2' - `n3' - `n4' - `n5'
        cap assert `diff' == 0 
        if _rc {
            dis as error "`diff' unauthorized missing values in `V'"
            error 9
        }
		
	
    // assmnt_gap
        local V assmnt_gap
        bys bene_id fac_int_id (order): ///
            assert _n == 1 if missing(assmnt_gap)
        if _rc {
            dis as error "Unauthorized missing values in `V'"
            error 9
        }
		
      
	// dschrg_dt_ext: ppl who haven't checked out yet but should all be in 2017
        local V dschrg_dt_ext
        bys bene_id fac_int_id (order): ///
			egen latest = max(trgt_dt)
		cap bys bene_id fac_int_id (order): ///
            assert (latest - td(30jun2017) >= 0) if missing(dschrg_dt_ext) 
        if _rc {
            dis as error "Unauthorized missing values in `V'"
            error 9
        }
		drop latest
	
	}
	
	
	/* Logic tests */
		
	// 2008 2009 entry date use reentry as preferred
	cap bys bene_id fac_int_id (order): ///
		assert entry_dt_ext == reentry_dt ///
		if !missing(reentry_dt) ///
		& inlist(year, 2008, 2009) ///
		& missing(reentry_dt[_n+1]) ///
		& order == 1 
	if _rc {		
		dis as error "'reentry_dt' column is not prioritized in 2008-09"
		error 9
	}
	
		
    // If entry_dt_ext changes, dschrg_dt_ext should also change
	cap bys bene_id fac_int_id (order): ///
		assert dschrg_dt_ext != dschrg_dt_ext[_n-1] ///
		if entry_dt_ext != entry_dt_ext[_n-1] ///
		& entry_dt_ext != dschrg_dt_ext ///
		& _n > 1
	if _rc {
		dis as error "discharge date is not changing with entry date"
		error 9
	}
	// vice versa
	cap bys bene_id fac_int_id (order): ///
		assert entry_dt_ext != entry_dt_ext[_n-1] ///
		if dschrg_dt_ext != dschrg_dt_ext[_n-1] ///
		& entry_dt_ext != dschrg_dt_ext ///
		& _n > 1
	if _rc {
		bys bene_id fac_int_id (order): ///
		gen flag = 1 ///
		if entry_dt_ext == entry_dt_ext[_n-1] ///
		& dschrg_dt_ext != dschrg_dt_ext[_n-1] ///
		& entry_dt_ext != dschrg_dt_ext ///
		& _n > 1
		dis as error "entry date is not changing with discharge date"
		error 9
	}		
	
	// Entry and discharge dates only increase
	foreach V in dschrg_dt_ext entry_dt_ext {
		cap bys bene_id fac_int_id (order): ///
			assert `V'[_n] >= `V'[_n-1] ///
			if _n > 1
		if _rc {			
			dis as error "`V' is not always increasing with time"
			error 9
		}
	}
	
	// Discharge is always equal or after entry
	cap assert dschrg_dt_ext >= entry_dt_ext
	if _rc {
		dis as error "entry occurs after discharge"
		error 9
	}
	
	save "${cleaned_mds}", replace


********************************************************************************
*** Collapse to Stay-level and Export ******************************************
********************************************************************************


/* Collaspe to Stay-level */
contract bene_id entry_dt_ext dschrg_dt_ext
drop _freq

// bys bene_id (entry_dt_ext): ///
// 	gen visit = _n
//	
// reshape wide entry_dt_ext dschrg_dt_ext, i(bene_id) j(visit)


// Export
save "${cleaned_stays}", replace


// take 1% random sample
preserve
contract bene_id
sample 1
keep bene_id
save "random_bene_ids.dta", replace
restore
merge m:1 bene_id using "random_bene_ids.dta", keep(3) nogen


// Export
save "${cleaned_stays_1p}", replace
erase "random_bene_ids.dta"






/* Archive 

	// Having a dschrg_dt post 2009 means discharge
	// Discharge date is always equal to target date
	
		
	// Cleaned column (copy over all the existing discharge dates)
	gen dschrg_dt_ext = dschrg_dt 
	
	
	// Manually split if last assessment is over 6 months ago
	bys bene_id fac_int_id (order): ///
		replace dschrg_dt_ext = trgt_dt ///
			if assmnt_gap[_n+1] >= 180 ///
			& !missing(assmnt_gap[_n+1] ) ///
			& missing(dschrg_dt_ext) ///
			& _n < _N
	
    // Manually add a discharge date if it's the last one 
    // and it's not in Jun-Dec 2017
    bysort bene_id fac_int_id (order): ///
        replace dschrg_dt_ext = trgt_dt ///
			if _n == _N ///
			& (trgt_dt[_n] - td(30jun2017) < 0) ///
			& missing(dschrg_dt_ext[_n])
    
	// Manually add missing discharge date when entry_dt changes 
	// but no discharge record
	bys bene_id fac_int_id (order): ///
		replace dschrg_dt_ext = trgt_dt ///
			if inlist(year, 2008, 2009) ///
			& missing(dschrg_dt_ext) ///
 			& entry_dt[_n] != entry_dt[_n+1] ///
			& !missing(entry_dt[_n]) ///
			& !missing(entry_dt[_n+1]) ///
			& missing(dschrg_dt_ext[_n+1]) ///
			& _n < _N
	
	
	// if multiple discharges lined up, take latest 
	// (assume false discharge records)
	gsort bene_id fac_int_id -order 
	by bene_id fac_int_id: ///
		replace dschrg_dt_ext = dschrg_dt_ext[_n-1] ///
		if !missing(dschrg_dt) /// 
		& !missing(dschrg_dt[_n-1]) ///
		& missing(entry_dt) ///
		& missing(reentry_dt) ///
		& _n > 1 
		
		
	
	
	// 2008 2009 Portion
	
		replace entry_dt_ext = reentry_dt ///
			if inlist(year, 2008, 2009)
		
		bys bene_id fac_int_id (order): ///
			replace entry_dt_ext = trgt_dt ///
				if inlist(year, 2008, 2009) ///
				& trgt_dt > reentry_dt ///
				& !missing(dschrg_dt[_n-1])
		

		// First ever stays
		
			// Grab entry date for cases of first time in SNF
			// entry_dt identifies 1st time stays
			// Should be first observation for each bene_id fac_int_id group
			bysort bene_id fac_int_id (order): ///
				replace entry_dt_ext = entry_dt ///
				if inlist(year, 2008, 2009) ///
				& missing(entry_dt_ext) ///
				& _n == 1 
				
			// Use target date if entry_date is empty
			bysort bene_id fac_int_id (order): ///
				replace entry_dt_ext = trgt_dt ///
				if inlist(year, 2008, 2009) ///
				& missing(entry_dt_ext) ///
				& missing(entry_dt) ///
				& _n == 1 
				
				 
	// 2010 - 2017 Portion
			
		// Use entry_dt if is first
		bysort bene_id fac_int_id (order): ///
			replace entry_dt_ext = entry_dt ///
			if year >= 2010 ///
			& _n == 1

		
	// Not first stays (consistent for both time periods)
	
	// Use either entry_dt or trgt_dt, whichiver is closest to last dschrg_dt
	bysort bene_id fac_int_id (order): ///
		replace entry_dt_ext = entry_dt ///
		if missing(entry_dt_ext) ///
		& !missing(dschrg_dt[_n-1]) ///
		& !missing(entry_dt[_n]) ///
		& entry_dt[_n] > dschrg_dt[_n-1] ///
		& _n != 1
	
	bysort bene_id fac_int_id (order): ///
		replace entry_dt_ext = trgt_dt ///
		if missing(entry_dt_ext) ///
		& !missing(dschrg_dt[_n-1]) ///
		& _n != 1 ///
		& ///
			((!missing(entry_dt[_n]) ///
			 & entry_dt[_n] > dschrg_dt[_n-1] ///
			 & trgt_dt[_n] > dschrg_dt[_n-1] ///
			 & trgt_dt[_n] < entry_dt[_n]) ///
		  | (missing(entry_dt[_n]) ///
			 & trgt_dt[_n] > dschrg_dt[_n-1] ///
			 & trgt_dt[_n] < entry_dt[_n]))
		
		
	// Manual split at 180
	bysort bene_id fac_int_id (order): ///
		replace entry_dt_ext = trgt_dt ///
		if missing(entry_dt_ext) ///
		& assmnt_gap >= 180 ///
		& !missing(assmnt_gap)
		
	// Multiple reentries in a row with no change in dschrg_dt
	// use latest entry date to overwrit
	// idk why 2008 2009 has a lot of weird submissions
	// make sure largest reentry_dt is at the bottom then backfill
	bys bene_id fac_int_id (order): ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
			if inlist(year, 2008, 2009) /// 
			& !missing(reentry_dt[_n]) ///
			& !missing(reentry_dt[_n-1]) ///
			& reentry_dt[_n-1] >= reentry_dt[_n] ///
			& _n > 1
			
	gsort bene_id fac_int_id -order
	bys bene_id fac_int_id: ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
			if inlist(year, 2008, 2009) /// 
			& !missing(reentry_dt[_n]) ///
			& !missing(reentry_dt[_n-1]) ///
			& _n > 1
			
			
			

			
// (2) Create continuum using entry points	// ISSUE with 2008/9 since reentry sometimes shows up not in the first row mmmmmmDDXsXUmXW 04jun2008
	bysort bene_id fac_int_id (order): ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
		if missing(entry_dt_ext) ///
		& missing(dschrg_dt[_n-1]) ///
		& _n > 1
	
	gsort bene_id fac_int_id -order
	bysort bene_id fac_int_id: ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
		if missing(entry_dt_ext) ///
		& missing(dschrg_dt[_n-1]) ///
		& _n > 1
		
	
	// Multiple discharges with no change in entry_dt
	// take earliest entry_dt_ext
	bys bene_id fac_int_id (order): ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
			if !missing(dschrg_dt[_n]) ///
			& !missing(dschrg_dt[_n-1]) ///
			& _n > 1
			
			
	// entry_dt suddenly changes with no previous dschrg
	// keep previous entry_dt
	bys bene_id fac_int_id (order): ///
		replace entry_dt_ext = entry_dt_ext[_n-1] ///
			if entry_dt_ext[_n] != entry_dt_ext[_n-1] ///
			& dschrg_dt_ext[_n] == dschrg_dt_ext[_n-1] ///
			& !missing(entry_dt_ext[_n]) ///
			& !missing(entry_dt_ext[_n-1]) ///
			& !missing(dschrg_dt_ext[_n]) ///
			& !missing(dschrg_dt_ext[_n-1]) ///
			& _n > 1
	
	*/
