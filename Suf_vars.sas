%macro suf_vars(indat /**the data set that contains all the variables**/,
				suffix /**the characters used for the prefix**/,
				outdat /**the new data set that contains the new, prefixed variable names**/);
	 %let dsid=%sysfunc(open(&indat.));
	 %let num=%sysfunc(attrn(&dsid.,nvars));
	  data &outdat.;
	   set &indat.(rename=(
	    %do i = 1 %to &num.;
	     %let var=%sysfunc(varname(&dsid.,&i.));
	       &var.=&var.&suffix. 
	    %end;));
	 %let rc=%sysfunc(close(&dsid.));
	  run;
%mend suf_vars;