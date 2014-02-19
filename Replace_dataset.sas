/*%let lib=Q4_2010;*/
/*%let dataset=berk_Q4_2010;*/
/*%let old_label=;*/
/*%let new_label=;*/

%macro replace_dataset(lib /*library in which the replacee resides*/,
						dataset /*the dataset to be archived and replaced*/,
						old_label /*label for the replacee (ideally, should document how it differs from its successor*/,
						new_label /*label for the replacer (ideally, should document how it differs from its predecessor*/);

	/*Create a copy of the replacee in the "*_archive" sub-directory of the directory in which it resides, 
		appending the date it was archived/replaced to the end of its name*/
		data archives.&dataset._replaced_&sysdate. (label="&old_label.");
			set &lib..&dataset.;
		run;

	/*Replace the original dataset*/
	options replace;
	data &lib..&dataset. (label="&new_label.");
		set work.&dataset.;
	run;
	options noreplace;
%mend;