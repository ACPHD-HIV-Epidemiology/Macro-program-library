/*Macro variable definitions for piecewise testing of parts of the below macro program*/
/*%let data=Q2_2013.AlCo_Q2_2013;*/
/*%let filter=newly_diag_filter;*/
/*%let dat_var1=hiv_agegrp2;*/
/*%let dat_var2=race_eth;*/
/*%let dat_var3=birth_sex;*/
/*%let show=hiv_agegrp2 in ("G2" "G3");*//*"13-19 yrs","20-29 yrs"*/
/*%let year=2012; run;*/

%macro rates(data /*name of the dataset to use for the calculation (incl. libname; i.e., Q2_2013.AlCo_Q2_2013)*/,
			filter /*name of a binary (numeric: 1,0) filter variable which selects the subset of interest*/,
			show /*optional criteria on the table variable(s) specifying sub-groups to be shown in the final output*/,	
			dat_var1 /*name of the demographic variable by which rates are desired (i.e., birth_sex, race_eth,*_agegrp2)*/,
			dat_var2 /*OPTIONAL: name of another demographic variable by which rates are desired (i.e., birth_sex, race_eth,*_agegrp2)*/,
			dat_var3 /*OPTIONAL: name of a third demographic variable by which rates are desired (i.e., birth_sex, race_eth,*_agegrp2)*/,
			denom_year /*year for which denominator data should be used*/);

	/********************************************************************************************************************************************************/
	/*Define intermediate variables from inout variables*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	%if %index(&filter.,newly_diag) NE 0 %then %let years=3;
		%else %let years=1; run; /*number of years being averaged over for rate calculation (3 for newly_diag_filter, 1 for all others)*/
	%if %length(&show.)=0 %then %let where=; %else %let where=where &show.; run;

	/*Identify variables to query from the denom*/
	%let denoms_dat=denoms.denoms1;/*Specify denoms1 as the denominator dataset by default*/

	%do i=1 %to 3;
		%if %index(&&dat_var&i.,sex) NE 0 %then %let denom_var&i.=birth_sex;
		%else %if %index(&&dat_var&i.,race) NE 0 %then %let denom_var&i.=race_eth; 
		%else %if %index(&&dat_var&i.,agegrp1) NE 0 %then %let denom_var&i.=agegrp;
		%else %if %index(&&dat_var&i.,agegrp2) NE 0 %then %do;
			%let denom_var&i.=agegrp;
			%let denoms_dat=denoms.denoms2;
		%end;
		%else %if %index(&&dat_var&i.,place) NE 0 
					or %index(%lowcase(&&dat_var&i.),city) NE 0 
					or %index(%lowcase(&&dat_var&i.),region) NE 0 %then %let denom_var&i.=place;
		%else %if %index(&&dat_var&i.,year) NE 0 
					or %index(&&dat_var&i.,yr) NE 0 %then %let denom_var&i.=year;
	%end;

	/*Define lists of variable names with different separators (for different purposes)*/
	%if &dat_var2= %then %do;
		%let num_var=1;
		%let dat_var=&dat_var1.; /*for variable specifications in data steps and procs*/
		%let dat_var_cross=&dat_var1.; /*for cross-tabulations*/
		%let dat_var_comma=&dat_var1.; /*for select statements*/
		%let denom_var=&denom_var1.; /*used to select the appropriate rows from the denominators dataset*/
		%let denom_as_dat_var=&denom_var1 as &dat_var1;	/*used to rename columns in the denominators dataset so they match the column names in the frequencies output dataset*/ 
	%end;
	%else %if &dat_var3= %then %do;
		%let num_var=2;
		%let dat_var=&dat_var1. &dat_var2.;
		%let dat_var_cross=&dat_var1.*&dat_var2.;
		%let dat_var_comma=&dat_var1., &dat_var2.;
		%let denom_var=&denom_var1. &denom_var2.;
		%let denom_as_dat_var=&denom_var1 as &dat_var1%quote(, )&denom_var2 as &dat_var2;
	%end;
	%else %do;
		%let num_var=3;
		%let dat_var=&dat_var1. &dat_var2. &dat_var3.; run;
		%let dat_var_cross=&dat_var1.*&dat_var2.*&dat_var3.; run;
		%let dat_var_comma=&dat_var1., &dat_var2., &dat_var3.;
		%let denom_var=&denom_var1. &denom_var2. &denom_var3.; run;
		%let denom_as_dat_var=&denom_var1 as &dat_var1%quote(, )&denom_var2 as &dat_var2%quote(, )&denom_var3 as &dat_var3;
	%end;

	/********************************************************************************************************************************************************/ 
	/*Calculate frequencies and proportions (among values specified for inclusion in the final putput dataset)*/data _null_;
	/********************************************************************************************************************************************************/ run;

	proc freq data=&data.;
		where &filter.=1;
		table &dat_var_cross. / nocum nopercent noprint out=out_dat;
	run;

	proc sql; create table out_dat_show1 as
		select &dat_var_comma., count
		from out_dat
		&where.;
	quit;

	proc sql; create table out_dat_show2 as
		select &dat_var_comma., count, round(count/sum(count)*100,.1) as percent
		from out_dat_show1
		order by &dat_var_comma.;
	quit;

	/********************************************************************************************************************************************************/
	/*Merge rows/strata with 0 counts back into table*/ data _null_;
	/********************************************************************************************************************************************************/ run;
	%do i=1 %to &num_var.;
		proc freq data=&data.;
			table &&dat_var&i. / nocum noprint out=dat&i._out;
		run;
		proc sql; create table dat&i._vals as
			select &&dat_var&i.
			from dat&i._out
			where not missing(&&dat_var&i.);
	%end;

	%if &num_var.=1 %then %do; 
		proc sql; create table crossed as 
			select * 
			from dat1_vals
			&where.
			order by &dat_var1.;		
	%end;
	%else %if &num_var.=2 %then %do; 
		proc sql; create table crossed as 
			select * 
			from dat1_vals cross join dat2_vals
			&where.
			order by &dat_var1., &dat_var2.;
	%end;
	%else %do; 
		proc sql; create table crossed as 
			select * 
			from dat1_vals cross join dat2_vals cross join dat3_vals
			&where.
			order by &dat_var1., &dat_var2., &dat_var3.;
	%end;

	data out_dat_show; 
		merge crossed(in=A) out_dat_show2(in=B);
		by groupformat &dat_var.;
		if missing(count) then count=0;
		if missing(percent) then percent=0;
	run;

	/********************************************************************************************************************************************************/
	/*Query out relevant rows of the pertinent denominator dataset*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	%if &denom_var.=birth_sex %then %let where_tot= and race_eth='T' and agegrp='T';
	%else %if &denom_var.=race_eth %then %let where_tot= and birth_sex='T' and agegrp='T';
	%else %if &denom_var.=agegrp %then %let where_tot= and birth_sex='T' and race_eth='T';
	%else %if &denom_var.=birth_sex race_eth or &denom_var.=race_eth birth_sex %then %let where_tot= and agegrp='T';
	%else %if &denom_var.=birth_sex agegrp or &denom_var.=agegrp birth_sex %then %let where_tot= and race_eth='T';
	%else %if &denom_var.=race_eth agegrp or &denom_var.=agegrp race_eth %then %let where_tot= and birth_sex='T';
	%else %let where_tot=;

	%if %index(&denom_var.,place) %then %do;
		%let where_place=;
		%if &denom_var.=place %then %let where_tot=and birth_sex='T' and race_eth='T' and agegrp='T';
	%end;
	%else %let where_place=and place="00";

	proc sql; create table denoms as
		select &denom_as_dat_var., denom
		from &denoms_dat.
		where year=&denom_year. &where_tot. &where_place.
		order by &dat_var_comma.;
	run;

	/********************************************************************************************************************************************************/
	/*Merge the frequency table (numerators) with the relevant subset of the denominator dataset*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	proc sort data=out_dat_show; by &dat_var.; run;

	data out_dat_denom; 
		merge out_dat_show(IN=A) denoms(IN=B); 
		by groupformat &dat_var.;
		if A;
	run;

	/********************************************************************************************************************************************************/
	/*Calculate total, subtotal, and sub-subtotal rows as needed, depending on the number of stratification variables*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	%if &num_var.=3 %then %do;

		/*generates grand totals*/
		proc sql; create table grand_totals as
			select "T" as &dat_var1.,
					"T" as &dat_var2.,
					"T" as &dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom;
			quit;

		/*generate subtotals by the first var*/
		proc sql; create table subtotals_1 as
			select &dat_var1., 
					"T" as &dat_var2.,
					"T" as &dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var1;
			quit;

		/*generate subtotals by the second var*/
		proc sql; create table subtotals_2 as
			select "T" as &dat_var1.,
					&dat_var2.,
					"T" as &dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var2;
			quit;

		/*generate subtotals by the third var*/
		proc sql; create table subtotals_3 as
			select "T" as &dat_var1.,
					"T" as &dat_var2.,
					&dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var3;
			quit;

		/*generate SUBsubtotals*/
		proc sql; create table subtotals_12 as
			select &dat_var1., 
					&dat_var2.,
					"T" as &dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var1., &dat_var2.;
			quit;

		proc sql; create table subtotals_13 as
			select &dat_var1., 
					"T" as &dat_var2.,
					&dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var1., &dat_var3.;
			quit;

		proc sql; create table subtotals_23 as
			select "T" as &dat_var1., 
					&dat_var2.,
					&dat_var3.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var2., &dat_var3.;
			quit;

		/*concatenate*/
		data out_dat_tot; set out_dat_denom  subtotals_1 subtotals_12 subtotals_13 subtotals_23
												subtotals_2 subtotals_3 grand_totals; run;
	%end;
	%else %if &num_var.=2 %then %do;
		/*generate subtotals by one var*/
		proc sql; create table subtotals_1 as
			select &dat_var1., 
					"T" as &dat_var2.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var1;
			quit;

		/*generate subtotals by other var*/
		proc sql; create table subtotals_2 as
			select "T" as &dat_var1.,
					&dat_var2.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom
			group by &dat_var2;
			quit;

		/*generates grand totals*/
		proc sql; create table grand_totals as
			select "T" as &dat_var1.,
					"T" as &dat_var2.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom;
			quit;

		/*concatenate*/
		data out_dat_tot; set out_dat_denom subtotals_1 subtotals_2 grand_totals; run;
	%end;
	%else %do;
		/*generates totals row*/
		proc sql; create table totals as
			select "T" as &dat_var1.,
					sum(count) as COUNT, 
					sum(percent) as PERCENT,
					sum(denom) as DENOM
			from out_dat_denom;
			quit;

		/*concatenate*/
		data out_dat_tot; set out_dat_denom totals; run;
	%end;

	/********************************************************************************************************************************************************/
	/*Merge in factors for calculating standard errors of rates with numerators less than 100*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	proc sort data=out_dat_tot; by count; run;
	proc sort data=denoms.poisson_CI_factors; by count; run;

	data rates_CIs;
		merge denoms.poisson_CI_factors(IN=B) out_dat_tot(IN=A);
		by count;
		if A;

		percent=round(percent,.1);

		rate=round((count/&years.)/denom * 100000,.1);

		if count NE 0 and missing(lcl_factor) then do;
			SE=rate/sqrt(count/&years.);
			lcl=round(rate-1.96*SE,.1);
			ucl=round(rate+1.96*SE,.1);
			lc_SE=SE;
			uc_SE=SE;
		end;
		if not missing(lcl_factor) then do;
			lcl=round(rate*lcl_factor,.1);
			ucl=round(rate*ucl_factor,.1);
			lc_SE=rate-lcl;
			uc_SE=ucl-rate;
		end;

		format count best.;

		drop SE lcl_factor ucl_factor;
	run;

	/********************************************************************************************************************************************************/
	/*Reformat values for aesthetics*/ data _null_;
	/********************************************************************************************************************************************************/ run;

	data rates_CIs2; set rates_CIs; 
		if &dat_var1.="T" then &dat_var1.="#";
		%if &num_var=2 %then %do;
			if &dat_var2.="T" then &dat_var2.="#";	
		%end;
		%else %if &num_var=3 %then %do;
			if &dat_var2.="T" then &dat_var2.="#";	
			if &dat_var3.="T" then &dat_var3.="#";
		%end;
	run;

	proc sql; create table rates_CIs3 as
		select &dat_var_comma., count, percent, denom, rate, lc_SE, uc_SE, lcl, ucl
		from rates_CIs2;

	%if %index(&dat_var.,race_eth) NE 0 %then %do; /*Recode race_eth so values sort as desired*/
		data rates_CIs3; set rates_CIs3;
			race_eth=put(race_eth, $race_eth2_order_Fs.);
			format race_eth $race_eth2_order_Fl.;
		run;
	%end;

	data table_data1; set rates_CIs3;

		if count<6 then do;
			count=.;
			percent=.;
			rate=.;
			lcl=.;
			ucl=.;
			lc_SE=.;
			uc_SE=.;
		end;

		length count_percent $ 35;
		label count_percent="N (%)";
		if count NE . then do;
			count_percent=cat(count," (",percent,"%)");
		end;
		else count_percent='*';

		length rate_CI $ 35;
		label rate_CI="Rate (95% CI)";
		if count NE . then do;
			rate_CI=cat(rate," (",lcl,", ",ucl,")");
		end;
		else rate_CI='*';

		if count<10 then do;
			rate_CI="**";
		end;

		drop count percent rate denom lcl ucl lc_SE uc_SE;
	run;

	data chart_data; set rates_CIs3;
/*		%do i=1 %to &num_var.;*/
/*			if &&dat_var&i.="#" then delete;*/
/*		%end;*/
	run;

	proc sort data=table_data1; by &dat_var; run;

	data table_data; set table_data1;
		%if &num_var.=2 %then %do;
			if &dat_var2. NE "#" then &dat_var1.="";
		%end;
	run;

	proc sort data=chart_data; by &dat_var; run;

	proc print data=table_data noobs label; 
		title "&filter. cases &where. &show. by &dat_var_cross.";
		footnote1 "*Data are suppressed where the count is < 6";
		footnote2 "**Rates not calculated where the count is < 10";
		footnote3 "NOTE: # indicates a total across the levels shown for that variable (some levels may not be of interest and so have been suppressed)";
	run;

	proc print data=chart_data noobs label; 
		title "&filter. cases &where. &show. by &dat_var_cross.";
		footnote1 "*Data are suppressed where the count is < 5 ";
		footnote2 "**Rates not calculated where the count is < 10";
		footnote3 "NOTE: # indicates a total across the levels shown for that variable (some levels may not be of interest and so have been suppressed)";
	run;

	title;
	footnote1;
	footnote2;

	/********************************************************************************************************************************************************/
	/*Clean up the SAS environment*/ data _null_;
	/********************************************************************************************************************************************************/ run;

		proc datasets nolist nodetails; delete 	out_dat	
												out_dat_show1
												out_dat_show2
												out_dat_show
												dat1_out
												dat1_vals
												crossed	
												denoms
												out_dat_denom
												totals
												out_dat_tot		
												rates_cis
												rates_cis2	
												rates_cis3
												table_data1; run;

		%if &num_var. GE 2 %then %do;
			proc datasets nolist nodetails; delete 	dat2_out
													dat2_vals
													grand_totals
													subtotals_1	
													subtotals_2; run;
		%end;

		%if &num_var.=3 %then %do;
			proc datasets nolist nodetails; delete 	dat3_out
													dat3_vals
													subtotals_3
													subtotals_12
													subtotals_13
													subtotals_23; run;
		%end;

%mend rates; run;

/*%rates( data=Q2_2013.AlCo_Q2_2013,*/
/*		filter=newly_diag_2011_filter,*/
/*		show=,*/
/*		dat_var1=race_eth,*/
/*		dat_var2=birth_sex,*/
/*		dat_var3=hiv_agegrp2,*/
/*		denom_year=2011); run;*/