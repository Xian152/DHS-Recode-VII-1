
******************************
*****
******************************
*****Household Level Info*****
******************************

*hh_id	ID (generated)
    gen hh_id = hhid

*hh_headed	Head's highest educational attainment (1 = none, 2 = primary, 3 = lower sec or higher)
    recode hv106 (0 = 1) (1 = 2) (2/3 = 3) (8=.) if hv101 == 1,gen(hh_headed)

*hh_region_num	Region of residence numerical (hv024)
    clonevar hh_region_num = hv024

*hh_region_lab	Region of residence label (v024)
    decode hv024,gen(hh_region_lab)

*hh_size # of members
    clonevar hh_size = hv009

*hh_urban Resides in urban area (1/0)
    recode hv025 (2=0),gen(hh_urban)

*hh_sampleweight Sample weight (v005/1000000)
    gen hh_sampleweight = hv005/10e6

*ind_sampleweight Sample weight (v005/1000000)
    gen ind_sampleweight = hh_size*hh_sampleweight

*hh_wealth_quintile	Wealth quintile
    clonevar hh_wealth_quintile = hv270

*hh_wealthscore	Wealth index score
    clonevar hh_wealthscore = hv271

*gl_adm0_code GAUL country code
    gen gl_adm0_code = . //? where to find?

*gl_adm1_code GAUL level one code
    gen gl_adm1_code = . //?

*hv001 Sampling cluster number (original)
*hv002 Household number (original)
*hv003 Respondent's line number in household roster (original)

duplicates drop hv001 hv002,force
