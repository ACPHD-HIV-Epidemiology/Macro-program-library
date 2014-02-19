%let dataset=Q2_2013.AlCo_Q2_2013;
%let filter=all_PLWHA_filter;
%let vars=race_eth cur_agegrp2 birth_sex;
%let subset=;

*%macro rates(dataset /*dataset to use for the analysis*/
			filter /*dichotomous (0/1) variable identifying the sub-population of interest (i.e., Newly_diag, PLWH,...)*/,
			vars /*space delimited list of variables by which to stratify the analysis*/,
			subset /*logical criterion (i.e., place='OAKLAND') by which to subset the output tables*/);

	/*######################################################################################################################################################*/
	/*obtain counts within each stratum by cross-tabulating the sub-pop. of interest by all the stratification variables*/
	/*######################################################################################################################################################*/
		proc freq data=&dataset.;
			where &filter.=1;
			table %sysfunc(tranwrd(&vars.,%quote( ),*)) / missing out=&filter._freq_out;
		run;

	/*######################################################################################################################################################*/
	/*identify ALL combinations of possible values of the stratification variables in the FULL dataset 
			(so that values happening not to appear in the sub-population of interest nonetheless appear in the output table)*/	
	/*######################################################################################################################################################*/

		%do i=1 %to %sysfunc(countw(&vars.));
			proc freq data=&dataset.;
				table %scan(&vars.,&i.) / missing out=%scan(&vars.,&i.)_freq_out;
			run;

			data %scan(&vars.,&i.)_values;
				set %scan(&vars.,&i.)_freq_out;
				where not missing(%scan(&vars.,&i.));
				drop count percent;
			run;
		%end;

		proc sql;
			create table full_freq_out as
				select *
				from %sysfunc(tranwrd(&vars.,%quote( ),%quote(_values cross join )))_values;

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*merge the counts with the full_freq_out dataset (keeping all rows from the latter) so that the table contains all combinations of possible values of the stratification variables*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			proc sort data=&filter._freq_out; by &vars.; run;
			proc sort data=full_freq_out; by &vars.; run;
			data counts;
				merge 	full_freq_out
						&filter._freq_out;
				by &vars.;

				if missing(count) then count=0;
				if missing(percent) then percent=0;
			run;

	/*######################################################################################################################################################*/
	/*obtain the grand total*/
	/*######################################################################################################################################################*/
		proc sql;
			select sum(count) into :grand_total separated by ''
				from counts;
			select sum(percent) into :grand_percent separated by ''
				from counts;

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*generate a grand total row that can later be concatenated with the counts and subtotal datasets 
				(i.e., it should have the same variables with the same attributes [types, lengths, etc.])*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			data grand_total;
				set counts;

				if _N_=1 then do; /*replace values of the variables in the first row with 'T ', which is the unformatted value representing totals in the denominator datasets*/
					array var &vars.;
					do over var;
						var='T ';
					end;
					count=&grand_total.;
					percent=&grand_percent.;
				end;
				else do; /*delete all other rows*/
					delete;
				end;
			run;

	/*######################################################################################################################################################*/
	/*obtain subtotals by cross-tabulating the sub-pop. of interest by all distinct combinations of subsets of the stratifiction variables*/
		/*create a dataset with a single column and 1 more row than the number of stratification variables, with each variable name in its own row
			and a blank string in the last*/
	/*######################################################################################################################################################*/
		data vars;
			set null_dataset;

			%do i=1 %to %sysfunc(countw(&vars.));
				if _N_=&i. then do;
					variable="%scan(&vars.,&i.)";
				end;
			%end;
			if _N_=%sysevalF(%sysfunc(countw(&vars.))+1) then do;
				variable='';
			end;
			if _N_>%sysevalF(%sysfunc(countw(&vars.))+1) then do;
				delete;
			end;
		run;

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*cross join the dataset created above with itself as many times as there are stratification variables 
			to obtain a dataset whose rows contain every possible 100% sampling (with replacement) of the stratification variables*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			proc sql;
					create table vars_crossed as
						select 	A.variable as variable1, 
								B.variable as variable2
						from vars as A cross join vars as B;

			%if %sysfunc(countw(&vars.))>3 %then %do;
				%do i=3 %to %sysevalf(%sysfunc(countw(&vars.));
						create table vars_crossed as
							select 	A.*,
									B.variable as variable&i.
							from vars_crossed as A cross join vars as B;
				%end;
			%end;

			proc sql;
				select name into :variables separated by ' '
				from dictionary.columns
				where libname='WORK'
					and memname='VARS_CROSSED';

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*create an additional variable in this dataset for each of the stratification variables and populate them with 
		the number of times the corresponding stratification variable appears in that row*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			%macro test;
			data vars_perms;
				set vars_crossed;

				%do i=1 %to %sysfunc(countw(&vars.));
					length %scan(&vars.,&i.) 3;
					%scan(&vars.,&i.)=0;
				%end;

				array var &variables.;
				%do i=1 %to %sysfunc(countw(&vars.));
					do over var;
						if var="%scan(&vars.,&i.)" then %scan(&vars.,&i.)=%scan(&vars.,&i.)+1;	
					end;
				%end;

				sum=sum(%scan(&vars.,1)-%scan(&vars.,%sysfunc(countw(&vars.))));
				null_count=cmiss(variable:);
				/*if a variable appears 2 or more times in the row, delete it 
				(this will leave you with all permutations of the stratification variables)*/	
/*					%do i=1 %to %sysfunc(countw(&vars.));*/
/*						if %scan(&vars.,&i.)>1 or sum(%scan(&vars.,1)-%scan(&vars.,%sysfunc(countw(&vars.))))=0 then do;*/
/*							delete;*/
/*						end;*/
/*					%end;*/
			run;	
%mend; %test; run;
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*sort the dataset on the counter variables and keep only rows with distinct combinations of them 
		(and hence distinct combinations of the variable names)*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/

			proc sort 
				data=vars_perms 
				out=vars_combs 
				nodupkey; 
				by &vars.; 
			run;

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*run proc freq for each distinct combination of the stratifiction variables*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			data _null_;
				set vars_combs;
				call execute("
							proc freq data=&dataset.;
								table "||catx('*',variable0-variable%sysevalF(%sysnfunc(countw(&vars.))-1)||" / missing out=subtotals"||_N_||";
							run;
							");
			run;

	/*######################################################################################################################################################*/
	/*concatenate the counts, grand total, and subtotal rows*/
	/*######################################################################################################################################################*/

		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
		/*generate a string listing all subbtotal datasets to be concatenated with the counts and grand total datasets*/
		/*><=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<=>=<*/
			proc sql;
				select memname into :subtotals separated by ' '
				from dictionary.tables
				where libname='WORK' 
					and substr(memname,1,10)='SUBTOTALS_';

		data concat;
			set counts
				grand total
				&subtotals.;
		run;

	/*######################################################################################################################################################*/
	/*merge with the appropriate denominator dataset*/
	/*######################################################################################################################################################*/
		%if %index(&vars.,agegrp1) NE 0 then %let denoms_dataset=denoms1;
		%else %let denoms_dataset=denoms2;

		proc sort data=concat; by &vars.; run;
		proc sort data=denoms.&denoms_dataset.; by &vars.; run;
		data merged_denoms;
			merge 	concat(in=concat)
					&denoms_dataset.;
			by &vars.;
			if concat;
		run;

	/*######################################################################################################################################################*/
	/*merge with the dataset containing multipliers for calclating poisson 95% confidence intervals*/
	/*######################################################################################################################################################*/
		proc sort data=merged_denoms; by count; run;
		proc sort data=denoms.poisson_CI_factors; by count; run;
		data merged_factors;
			merge 	merged_denoms(in=merged_denoms)
					denoms.poisson_CI_factors;
			by count;
			if merged_denoms;
		run;

	/*######################################################################################################################################################*/
	/*calculate rates, confidence limits, and SEs*/
	/*######################################################################################################################################################*/
		data raw_output;
			set merged_factors;

			...;
		run;

	/*######################################################################################################################################################*/
	/*print the raw dataset*/
	/*######################################################################################################################################################*/
		proc print data=raw_output; 
		run;

	/*######################################################################################################################################################*/
	/*suppress counts (<6) and rates (where count<10) as appropriate, format the table, and print with a draft title and footnotes*/
	/*######################################################################################################################################################*/
		data final_output;
			set raw_output;

			...;
		run;

		proc print data=final_output;
			title "&filter. by &vars.";
			footnote1 'Source: eHARS';
			footnote2 '*Cells with counts of five or less are suppressed in order to protect patient confidentiality';
			footnote3 '**Rates are not calculated where counts are less than 10 due to a lack of statistical stability';
			%if %index(&vars.,race_eth) NE 0 %then %do;
				footnote4 'API=Asian and Pacific Islander';
			%end;
			%if %index(&vars.,agegrp) NE 0 %then %do;
				%if %index(&filter., PLWH) NE 0 %then %do;
					footnote5 "Age refers to age as of December 31, &last_annual_DUA_yr.";
				%end;
				%else %if %index(&filter., newly_diag) NE 0 %then %do;
					footnote5 "Age refers to age at diagnosis";
				%end;
			%end;
		run;

	/*######################################################################################################################################################*/
	/*Clean up the SAS environment, restoring titles and footnotes and deleting intermediary datasets*/
	/*######################################################################################################################################################*/
		title;
		footnote;

		proc datasets library=work;
			delete ...;
		run;
%mend;
