%macro trend(dataset, start_year, end_year);
	%do year=&start_year. %to &end_year.; /*for each year...*/
		proc freq data=&dataset. noprint;
			table newly_diag_&year._filter / missing out=CY&year.;/*...output a dataset with the case count (+/- 1 yr)*/
		run;

		data CY&year.;
			set CY&year.;
			where newly_diag_&year._filter=1;
			year="&year.";
			keep year count;
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

	Proc sql; /*generate year-specific denominators*/
		create table denominators as
		select put(year,4.) as year, denom
		from denoms.denoms2
		where &start_year. <= year <= &end_year. 
				and place="00"
				and birth_sex="T"
				and race_eth="T"
				and agegrp="T"
		order by year;

	data rate_calc; /*merge numerators and denominators, calculate rates and 95% CIs*/
		merge concat denominators;
		by year;
		rate=round((count/3)/denom*100000,.1);
		SE=rate/sqrt(count/3);
		lcl=round(rate-1.96*SE,.1);
		ucl=round(rate+1.96*SE,.1);
	run;

	proc print data=rate_calc; run;
%mend; run;