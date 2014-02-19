%macro trends(data, start_year, end_year, strat_var);
	%if %index(&strat_var.,agegrp) NE 0 %then %let strat_var_denom=agegrp;
	%else %if %index(&strat_var.,region) NE 0 %then %let strat_var_denom=place;
	%else %let strat_var_denom=&strat_var.;

	%do year=&start_year. %to &end_year.; /*for each year...*/
		proc freq data=&data. noprint;
			table newly_diag_&year._filter*&strat_var. / norow nocol nocum nopercent out=CY&year.;/*...output a dataset with the case count (+/- 1 yr)*/
		run;

		data CY&year.(rename=(&strat_var.=&strat_var_denom.));
			set CY&year.;
			where newly_diag_&year._filter=1;
			year="&year.";
/*			%if &strat_var_denom.=place %then %do;*/
/*				&strat_var.=put(&strat_var., NewCityFl.);*/
/*			%end;*/
			keep &strat_var. year count;
		run;
	%end;

	Proc sql noprint; /*list year-specific datasets to concatenate*/
		select memname into :years_datasets separated by " " 
		from dictionary.tables
		where libname="WORK" and upcase(substr(memname,1,2))="CY"
		order by memname;

	data concat; /*concatenate year-specific datasets*/
		set &years_datasets.;
	run;

	%if %index(&strat_var.,region) NE 0 %then %let place=; %else %let place=and put(place,$NewCityFl.)="ALAMEDA COUNTY";
	%if &strat_var.=birth_sex %then %let birth_sex=; %else %let birth_sex=and birth_sex="T";
	%if &strat_var.=race_eth %then %let race_eth=; %else %let race_eth=and race_eth="T";
	%if %index(&strat_var.,age) NE 0 %then %do;
		%let agegrp=;
		%if %index(&strat_var.,agegrp1) %then %let denoms_dataset=denoms1; 
		%else %let denoms_dataset=denoms2;
	%end;
	%else %do;
		%let agegrp=and agegrp="T";
		%let denoms_dataset=denoms2;
	%end;

	Proc sql; /*generate year-specific denominators*/
		create table denominators as
		select put(year,4.) as year, &strat_var_denom., denom
		from denoms.&denoms_dataset.
		where &start_year. <= year <= &end_year. 
				&place.
				&birth_sex.
				&race_eth.
				&agegrp.
		order by year, &strat_var_denom.;

	proc sort data=concat; by year &strat_var_denom.; run;
	data rate_calc; /*merge numerators and denominators, calculate rates and 95% CIs*/
		merge concat(in=A) denominators(in=B);
		by year &strat_var_denom.;
		if A;
		rate=round((count/3)/denom*100000,.1);
		SE=rate/sqrt(count/3);
		lcl=round(rate-1.96*SE,.1);
		ucl=round(rate+1.96*SE,.1);
	run;

	proc sort data=rate_calc; by &strat_var_denom.; run;

	proc transpose data=rate_calc 
		out=transpose
		name=rate;
		by &strat_var_denom.;
		id year;
		var rate;
	run;

	proc sort data=rate_calc; by year; run;
	proc print data=rate_calc; run;

	proc print data=transpose; 
		title "Rate trend by &strat_var., &start_year.-&end_year.";
	run;
%mend; run;