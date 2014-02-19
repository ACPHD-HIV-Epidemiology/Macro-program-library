%macro data_dic(libname,memname);

	%do i=1 %to 2; /*for each var type...*/
		%if &i.=1 %then %do;
			%let type=char;
			%let types='char';
			%let format=$"||trim(left(put(length,1.)))||".;
		%end;
		%else %if &i.=2 %then %do;
			%let type=num;
			%let types='num';
			%let format="||trim(left(put(length,1.)))||".;
		%end;

		Proc sql;
			create table &type._vars as
			select name, type, length, format
			from dictionary.columns
			where libname="%upcase(&libname.)"
					and memname="%upcase(&memname.)"
					and type in (&types.)
			order by name;

		data _null_;
			set work.&type._vars; /*then for each var...*/
			call execute /*query out the var name, the unformatted (internal/stored) values, 
				and the formatted values*/
				("
				Proc sql;
					create table "||trim(left(name))||"_vals as
						select distinct '"||trim(left(name))||"' as name,
							"||trim(left(name))||" format=&format. as uvals,
							"||trim(left(name))||" as fvals
						from &libname..&memname.;

				data merged_"||trim(left(name))||";
					merge &type._vars(in=A) 
					"||trim(left(name))||"_vals(in=B);
					by name;
					if B and A and _N_<=25;
				run;
				");
		run;
		
		proc sql; /*generate a list of the merged datasets (var metadata + formatted and unformatted values of the var)*/
			select memname into :merged_&type. separated by " "
			from dictionary.tables
			where libname="WORK" 
				and substr(memname,1,7)="MERGED_" 
				and upcase(substr(memname,8,length(memname))) in (select upcase(name) from &type._vars);

		data &type._data_dic; /*concatenate all merged datasets to create a data dictionary*/
			set &&merged_&type..;
		run;
	%end;

	Proc sql;
			create table all_vars as
			select name, type, length, format
			from dictionary.columns
			where libname="%upcase(&libname.)"
					and memname="%upcase(&memname.)"
			order by name;

	ods _all_ close;
		ods TAGSETS.EXCELXP 
			file="&Output_path.\&today_date. &memname. Data Dictionary.xls" 
			style=statistical
			options(
				/*contents='yes' */
				embedded_titles='yes' 
				embedded_footnotes='yes'
				EMBED_TITLES_ONCE='yes'
				EMBED_FOOTERS_ONCE='yes'
				sheet_interval="none"
				AUTOFILTER='ALL'
				);

	ods tagsets.ExcelXP options (sheet_interval="none" sheet_name="ALL");
	proc print data=all_vars; run;

	ods tagsets.ExcelXP options (sheet_interval="none" sheet_name="CHAR");
	proc print data=char_data_dic; run;

	ods tagsets.ExcelXP options (sheet_interval="none" sheet_name="NUM");
	proc print data=num_data_dic; run;

	ods _all_ close;
	ods listing;

%mend;