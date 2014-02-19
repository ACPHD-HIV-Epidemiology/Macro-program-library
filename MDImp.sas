%macro MDImp(date_var_char);
/* length &date_var_char._num_MDImp 4.;*/

	if not missing(&date_var_char.) and &date_var_char. NE '........' then do;
		IF substr(&date_var_char.,5,2)=".." 
			then &date_var_char._num_MDImp=mdy(	1,
												1,
												input(substr(&date_var_char.,1,4),4.));
		ELSE IF substr(&date_var_char.,7,2)=".." 
			then &date_var_char._num_MDImp=mdy(INPUT(substr(&date_var_char.,5,2),2.),
										1,
										INPUT(substr(&date_var_char.,1,4),4.));
		ELSE &date_var_char._num_MDImp=mdy(INPUT(substr(&date_var_char.,5,2),2.),
									INPUT(substr(&date_var_char.,7,2),2.),
									INPUT(substr(&date_var_char.,1,4),4.));
	end;
	else &date_var_char._num_MDImp=.;

	format &date_var_char._num_MDImp date9.;
%mend;