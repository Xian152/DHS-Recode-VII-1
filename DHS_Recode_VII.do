////////////////////////////////////////////////////////////////////////////////////////////////////
*** DHS MONITORING
////////////////////////////////////////////////////////////////////////////////////////////////////

version 14.0
clear all
set matsize 3956, permanent
set more off, permanent
set maxvar 32767, permanent
capture log close
sca drop _all
matrix drop _all
macro drop _all

******************************
*** Define main root paths ***
******************************

//NOTE FOR WINDOWS USERS : use "/" instead of "\" in your paths

//global root "C:\Users\wb500886\WBG\Sven Neelsen - World Bank\MEASURE UHC DATA"
global root "C:\Users\Guan\OneDrive\DHS\MEASURE UHC DATA"

* Define path for data sources
global SOURCE "${root}/RAW DATA/Recode VII"

* Define path for output data
global OUT "${root}/STATA/DATA/SC/FINAL"

* Define path for INTERMEDIATE
global INTER "${root}/STATA/DATA/SC/INTER"

* Define path for do-files
global DO "${root}/STATA/DO/SC/DHS/Recode VII/Git-DHS-Recode-VII"

* Define the country names (in globals) in by Recode
    
	do "${DO}/0_GLOBAL.do"
	
// global DHScountries_Recode_VII "Jordan2017"  //run with Afghanistan2015 as test.$DHScountries_Recode_VII

foreach name in $DHScountries_Recode_VII {	
clear
tempfile birth ind men hm hiv hh iso

******************************
*****domains using birth data*
******************************
use "${SOURCE}/DHS-`name'/DHS-`name'birth.dta", clear	
    gen hm_age_mon = (v008 - b3)           //hm_age_mon Age in months (children only)
    gen name = "`name'"
	
    do "${DO}/1_antenatal_care"
    do "${DO}/2_delivery_care"
    do "${DO}/3_postnatal_care"
    do "${DO}/7_child_vaccination"
    do "${DO}/8_child_illness"
    do "${DO}/10_child_mortality"
    do "${DO}/11_child_other"

*housekeeping for birthdata
   //generate the demographics for child who are dead or no longer living in the hh. 
   
    *hm_live Alive (1/0)
    recode b5 (1=0)(0=1) , ge(hm_live)   
	label var hm_live "died" 
	label define yesno 0 "No" 1 "Yes"
	label values hm_live yesno 

    *hm_dob	date of birth (cmc)
    gen hm_dob = b3  

    *hm_age_yrs	Age in years       
    gen hm_age_yrs = b8        

    *hm_male Male (1/0)         
    recode b4 (2 = 0),gen(hm_male)  
	
    *hm_doi	date of interview (cmc)
    gen hm_doi = v008
	
rename (v001 v002 b16) (hv001 hv002 hvidx)
keep hv001 hv002 hvidx bidx c_* mor_* w_* hm_*
save `birth'

******************************
*****domains using ind data***
******************************
use "${SOURCE}/DHS-`name'/DHS-`name'ind.dta", clear	
gen name = "`name'"

    do "${DO}/4_sexual_health"
    do "${DO}/5_woman_anthropometrics"
    do "${DO}/16_woman_cancer"
	//do "${DO}/17_woman_cancer_age_ref.do"
*housekeeping for ind data

    *hm_dob	date of birth (cmc)
    gen hm_dob = v011  
	
	
keep v001 v002 v003 w_* hm_*
rename (v001 v002 v003) (hv001 hv002 hvidx)
save `ind' 
/*
******************************
*****domains using men data***
******************************
use "${SOURCE}/DHS-`name'/DHS-`name'men.dta", clear
gen name = "`name'"

    *hm_dob	date of birth (cmc)
    gen hm_dob = mv011  

keep mv001 mv002 mv003 hm_*
rename (mv001 mv002 mv003) (hv001 hv002 hvidx)
save `men'
*/

************************************
*****domains using hm level data****
************************************
use "${SOURCE}/DHS-`name'/DHS-`name'hm.dta", clear
gen name = "`name'"

    do "${DO}/9_child_anthropometrics"  
	do "${DO}/13_adult"
    do "${DO}/14_demographics"
	
keep hv001 hv002 hvidx hc70 hc71 ///
c_* ant_* a_* hm_* ln
save `hm'

capture confirm file "${SOURCE}/DHS-`name'/DHS-`name'hiv.dta"
 if _rc==0 {
    use "${SOURCE}/DHS-`name'/DHS-`name'hiv.dta", clear
    do "${DO}/12_hiv"
 }
 if _rc!= 0 {
    gen a_hiv = . 
    gen a_hiv_sampleweight = .
  }   
    save `hiv'

use `hm',clear
merge 1:1 hv001 hv002 hvidx using `hiv'
drop _merge
save `hm',replace

************************************
*****domains using hh level data****
************************************
use "${SOURCE}/DHS-`name'/DHS-`name'hm.dta", clear
    rename (hv001 hv002 hvidx) (v001 v002 v003)

    merge 1:m v001 v002 v003 using "${SOURCE}/DHS-`name'/DHS-`name'birth.dta"
    rename (v001 v002 v003) (hv001 hv002 hvidx) 
    drop _merge

    do "${DO}/15_household"

keep hv001 hv002 hv003 hh_* ind_*
save `hh' 

************************************
*****merge to microdata*************
************************************

***match with external iso data
use "${SOURCE}/external/iso", clear 
keep country iso2c iso3c	
replace country = "Tanzania"  if country == "Tanzania, United Republic of"
replace country = "PapuaNewGuinea" if country == "Papua New Guinea"

save `iso'

***merge all subset of microdata
use `hm',clear

    merge 1:m hv001 hv002 hvidx using `birth',update      //missing update is zero, non missing conflict for all matched.(hvidx different) 
	bysort hv001 hv002: egen min = min(w_sampleweight)
	replace w_sampleweight = min if w_sampleweight ==.
    replace hm_headrel = 99 if _merge == 2
	label define hm_headrel_lab 99 "dead/no longer in the household"
	label values hm_headrel hm_headrel_lab
	replace hm_live = 0 if _merge == 2 | inlist(hm_headrel,.,12,98)
	drop _merge
    merge m:m hv001 hv002 hvidx using `ind',nogen update
//	merge m:m hv001 hv002 hvidx using `men',nogen update
	merge m:m hv001 hv002       using `hh',nogen update

    tab hh_urban,mi  //check whether all hh member + dead child + child lives outside hh assinged hh info

***survey level data
    gen survey = "DHS-`name'"
	gen year = real(substr("`name'",-4,.))
	tostring(year),replace
    gen country = regexs(0) if regexm("`name'","([a-zA-Z]+)")
	replace country = "South Africa" if country == "SouthAfrica"
	replace country = "Timor-Leste" if country == "Timor"
	
    merge m:1 country using `iso',force
    drop if _merge == 2
	drop _merge

*** Quality Control: Validate with DHS official data
    gen surveyid = iso2c+year+"DHS"

	preserve 
	do "${DO}/Quality_control"
	save "${INTER}/quality_control-`name'.dta",replace
	cd "${INTER}"
	do "${DO}/Quality_control_result"
	save "${OUT}/quality_control",replace 
    restore

*** Specify sample size to HEFPI
	
    ***for variables generated from 1_antenatal_care 2_delivery_care 3_postnatal_care
	foreach var of var c_anc	c_anc_any	c_anc_bp	c_anc_bp_q	c_anc_bs	c_anc_bs_q ///
	c_anc_ear	c_anc_ear_q	c_anc_eff	c_anc_eff_q	c_anc_eff2	c_anc_eff2_q ///
	c_anc_eff3	c_anc_eff3_q	c_anc_ir	c_anc_ir_q	c_anc_ski	c_anc_ski_q ///
	c_anc_tet	c_anc_tet_q	c_anc_ur	c_anc_ur_q	c_caesarean	c_earlybreast ///
	c_facdel	c_hospdel	c_sba	c_sba_eff1	c_sba_eff1_q	c_sba_eff2 ///
	c_sba_eff2_q	c_sba_q	c_skin2skin	c_pnc_any	c_pnc_eff	c_pnc_eff_q c_pnc_eff2	c_pnc_eff2_q {
    replace `var' = . if !(inrange(hm_age_mon,0,23)& bidx ==1)
    }
	
	***for variables generated from 4_sexual_health 5_woman_anthropometrics
	foreach var of var w_CPR w_unmet_fp	w_need_fp w_metany_fp	w_metmod_fp w_metany_fp_q  w_bmi_1549 w_height_1549 w_obese_1549 w_overweight_1549 {
	replace `var'=. if hm_age_yrs<15 | (hm_age_yrs>49 & hm_age_yrs!=.)
	}
	
	***for variables generated from 7_child_vaccination
	foreach var of var c_bcg c_dpt1 c_dpt2 c_dpt3 c_fullimm c_measles ///
	c_polio1 c_polio2 c_polio3{
    replace `var' = . if !inrange(hm_age_mon,15,23)
    }
	
	***for variables generated from 8_child_illness	
	foreach var of var c_ari c_ari2	c_diarrhea 	c_diarrhea_hmf	c_diarrhea_medfor	c_diarrhea_mof	c_diarrhea_pro	c_diarrheaact ///
	c_diarrheaact_q	c_fever	c_fevertreat	c_illness c_illness2 c_illtreat	c_illtreat2 c_sevdiarrhea	c_sevdiarrheatreat ///
	c_sevdiarrheatreat_q	c_treatARI	c_treatARI2 c_treatdiarrhea	c_diarrhea_med {
    replace `var' = . if !inrange(hm_age_mon,0,59)
    }
	
	***for variables generated from 9_child_anthropometrics
	foreach var of var c_underweight c_stunted	hc70 hc71 ant_sampleweight{
    replace `var' = . if !inrange(hm_age_mon,0,59)
    }
	
	***for hive indicators from 12_hiv
    foreach var of var a_hiv*{
    replace `var'=. if hm_age_yrs<15 | (hm_age_yrs>49 & hm_age_yrs!=.)
    }
              
	***for hive indicators from 13_adult
    foreach var of var a_diab_treat  a_inpatient_1y a_bp_treat a_bp_sys a_bp_dial a_hi_bp140_or_on_med a_bp_meas{
	replace `var'=. if hm_age_yrs<18
	}
*** Label variables
    drop bidx surveyid
    do "${DO}/Label_var"
	
save "${OUT}/DHS-`name'.dta", replace  
}





