/*Output dataset named merged_transpose"*/

%macro multi_transpose(data /*dataset to transpose*/,
						vars /*columns whose values should be tranposed*/,
						by /*variable, values within which columns should be tranposed*/,
						id /*variable identifying unique values of the tranposed column (used for column names of output dataset)*/);
	%do i=1 %to %sysfunc(countw(&vars.));
		%let var=%scan(&vars.,&i.); 
		proc transpose 
			data=&data.
			out=&var.(drop=_NAME_)
			prefix=&var.;
			by &by.;
			id &id.;
			var &var.;
		run;
	%end;

	data merged_transpose;
		merge &vars.;
		by stateno;
	run;

	%do i=1 %to %sysfunc(countw(&vars.));
		%if &i.=1 %then %let vars_comma="%scan(&vars.,&i.)";
		%else %let vars_comma=&vars_comma., "%scan(&vars.,&i.)";
	%end;

	%do i=1 %to %sysfunc(countw(&by.));
		%if &i.=1 %then %let by_comma=%scan(&by.,&i.);
		%else %let by_comma=&by_comma., %scan(&by.,&i.);
	%end;

	proc sql noprint;
		select name into :ordered_columns separated by ', '
		from dictionary.columns
		where libname="WORK" 
				and memname="MERGED_TRANSPOSE" 
				and indexc(name,&vars_comma.)
	order by substr(name,length(name),1);

	proc sql;
		create table merged_transpose as
			select &by_comma., &ordered_columns.
			from merged_transpose;

	proc datasets library=WORK; 
		delete &vars.; 
	run;
%mend;