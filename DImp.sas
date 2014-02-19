%macro DImp(date_var_char);
/*			length &date_var_char._num_DImp 4.;*/

	if not missing(&date_var_char.) and &date_var_char. NE '........' and substr(&date_var_char.,5,2) NE ".." then do;
		IF substr(&date_var_char.,7,2)=".." 
			then &date_var_char._num_DImp=mdy(	INPUT(substr(&date_var_char.,5,2),2.),
										1,
										INPUT(substr(&date_var_char.,1,4),4.));
		ELSE &date_var_char._num_DImp=mdy(	INPUT(substr(&date_var_char.,5,2),2.),
									INPUT(substr(&date_var_char.,7,2),2.),
									INPUT(substr(&date_var_char.,1,4),4.));
	end;
	else &date_var_char._num_DImp=.;

	format &date_var_char._num_DImp date9.;
%mend;