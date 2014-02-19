/*%let filter=all_PLWHA_filter;*/
/*%let vars=race_eth birth_sex;*/
/*%let dataset=;*/
/*%let subset=;*/
/*%let stat=pct_row;*/
/*%let totals=row;*/

%macro crosstab(filter /*name of a dicothomous (0/1) indicator variable identifying the sub-population of interest*/,
				vars /*two variables, separated by a space*/,
				dataset /*OPTIONAL: name of a dataset (if left blank, defaults to the latest annual DUA)*/,
				subset /*OPTIONAL: logical criterion(a) additionally subsetting the dataset*/,
				stat /*OPTIONAL: either pct_row, pct_col, or percent (if left blank, defaults to freq)*/,
				totals /*OPTIONAL: either col, row, or both (if left blank, defaults to none)*/);
	
	%if %length(&dataset.)=0 %then %let data=Q&latest_annual_DUA_qtr._&latest_annual_DUA_yr..AlCo_Q&latest_annual_DUA_qtr._&latest_annual_DUA_yr.;
	%else %let data=&dataset.;

	%if %length(&subset.)=0 %then %do;
		%let and_subset=;
		%let where_subset=;
	%end;
	%else %do;
		%let and_subset=and &subset.;
		%let where_subset=where &subset.;
	%end;

	%if %length(&stat.)=0 %then %let stat_out=freq;
	%else %let stat_out=&stat.;

	proc freq data=&data. noprint;
		where &filter.=1 &and_subset.;
		table %scan(&vars.,1)*%scan(&vars.,2) / out=freq_out outpct;
	run;

	data freq_out2;
		set freq_out;
		keep &vars. &stat.;
	run;
/*%macro test;*/
	data cleaned;
		set freq_out2;

		if missing(&stat.) then &stat.=0;
		else &stat.=&stat./100;

		%if %length(&stat.) NE 0 %then %do;
			format &stat. percent7.1;
		%end;
	run;
/*%mend; %test; run;*/
	proc transpose 
		data=cleaned
		out=transposed1;
		by %scan(&vars.,1);
		id %scan(&vars.,2);
	run;

	data transposed;
		set transposed1;
		drop _NAME_ _LABEL_;
	run;

	%if &totals.=row or &totals.=both %then %do;
		proc freq data=&data. noprint;
			where &filter.=1 &and_subset.;
			table %scan(&vars.,1) / out=%scan(&vars.,1)_freqs;
		run;

		proc sort data=transposed; 
			by %scan(&vars.,1); 
		run;
		proc sort data=%scan(&vars.,1)_freqs; 
			by %scan(&vars.,1); 
		run;
		data transposed (drop=percent);
			merge 	transposed (rename=(%scan(&vars.,1)=%scan(&vars.,1)_in))
					%scan(&vars.,1)_freqs (rename=(	count=%scan(&vars.,1)_freq
													%scan(&vars.,1)=%scan(&vars.,1)_in));
			by %scan(&vars.,1)_in;

			length %scan(&vars.,1) $50;
			%scan(&vars.,1)=cats(vvalue(%scan(&vars.,1)_in),"_(N=",%scan(&vars.,1)_freq,")");

			length total 5;
			total=%scan(&vars.,1)_freq;

			drop %scan(&vars.,1)_in %scan(&vars.,1)_freq;
		run;
	%end;

/*	%if &totals.=col or &totals.=both %then %do;*/
/*		proc freq data=&data.;*/
/*			where &filter.=1 &and_subset.;*/
/*			table %scan(&vars.,2) / out=%scan(&vars.,2)_freqs;*/
/*		run;*/
/**/
/*		data rename;*/
/*			set %scan(&vars.,2)_freqs;*/
/**/
/*			length rename $100;*/
/*			rename=cats('',%scan(&vars.,2),"=%scan(&vars.,2)_N_",count,"_CP_");*/
/*		run;*/
/**/
/*		proc sql;*/
/*			select rename into :rename separated by ' '*/
/*			from rename;*/
/**/
/*		data cleaned;*/
/*			set cleaned;*/
/*			*/
/*			rename &rename;*/
/*		run;*/
/*	%end;*/

	proc sql;
		title "&filter. &where_subset. by %scan(&vars.,1) and %scan(&vars.,2) (&stat_out.)";
		select %scan(&vars.,1), *
		from transposed;
%mend;
