/*******************************************************************************
* Title: Inflation
* Created by: Alex Hoagland
* Created on: 7/21/2020
* Last modified on: 
* Last modified by: 
* Purpose: This file adjusts spending variables in marketscan for inflation, 
	and drops those with negative outcomes. 
		   
* Notes: 
		
* Key edits: 
   -  
*******************************************************************************/

foreach v of varlist `1' { 
	replace `v' = `v' * 1.2788 if year == 2006
	replace `v' = `v' * 1.2449 if year == 2007
	replace `v' = `v' * 1.1988 if year == 2008
	replace `v' = `v' * 1.2031 if year == 2009
	replace `v' = `v' * 1.1837 if year == 2010
	replace `v' = `v' * 1.1475 if year == 2011
	replace `v' = `v' * 1.1242 if year == 2012
	replace `v' = `v' * 1.1080 if year == 2013
	replace `v' = `v' * 1.0903 if year == 2014
	replace `v' = `v' * 1.0890 if year == 2015
	replace `v' = `v' * 1.0754 if year == 2016
	replace `v' = `v' * 1.0530 if year == 2017
	replace `v' = `v' * 1.0261 if year == 2018
	drop if `v' < 0 & !missing(`v')
}
