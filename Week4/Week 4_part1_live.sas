%let dirdata=/folders/myshortcuts/SAS_part/week 4/;
libname perm "&dirdata";
PROC FORMAT;
	value cut 
     1 = "Fair"       2 = "Good" 
     3 = "Very Good"  4 = "Premium"    5 = "Ideal";
	value color 
     1 = "D"   2 = "E"  3 = "F"  4 = "G" 
     5 = "H"   6 = "I"  7 = "J" ;
	value clarity 
     1 = "I1"   2 = "SI2"   3 = "SI1"   4 = "VS2" 
     5 = "VS1"  6 = "VVS2"  7 = "VVS1"  8 = "IF" ;
run;
title 'dmid';
proc print data=perm.dmid (obs=5);run;
proc contents data=perm.dmid;run;

title 'dmid_formats';
proc print data=perm.dmid_formats (obs=5);run;
proc contents data=perm.dmid_formats;run;
title;
/* The formatted version will be much more useful to us, because
	it will preserve that natural order of cut and clarity */

* We will start with the sgplot function;
title "Middle-size data: N=10,000";
proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price;
run;
data dmid2; 
	set perm.dmid_formats;
	log_carat=log10(carat);
	log_price=log10(price);
	label log_carat="log(carat)" log_price="log(price)";
run;
title "Using logs";
footnote  justify=left color=red height=10pt "(Note axis names)";
proc sgplot data=dmid2;
	scatter x=log_carat y=log_price;
run;
footnote;

title "Using log scales";
proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price;
	xaxis type=log ;
	yaxis type=log;
run;
title "Custom axis label: works partially on original scale";
proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price;
	*yaxis values=(500 1000 2000 5000 10000 15000 20000); * or (num1 TO num2 BY increment);
	yaxis values = (500 TO 20000 BY 5000);
run;

title "Custom axis label (works in SAS 9.4, not 9.3).";
proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price;
	xaxis type=log; 
	yaxis type=log values=(500 1000 2000 5000 10000 15000 20000);
run;
title;
************************************;
* Next, use PROC SGSCATTER to make *panels* of plots;
proc sgscatter data=dmid2;
	plot price*carat log_price*log_carat;
run;
**************************************;
* Based on the first graph, it seems reasonable to look
*	at the distribution of carats for a bit;

proc sgplot data=dmid2;
	histogram carat;
run;
ODS HTML5 path="&dirdata" file="myplot.html"
          style=default;
proc sgplot data=dmid2;
histogram carat;
run;
ods html5 close;
/* ODS example using macro path variable dirdata with harvest style*/
ods html5 path="&dirdata" file="myplot_harvest.html" style=harvest ; 
proc sgplot data=dmid2;
histogram carat;
run;
ods html5 close;
ods html5 path="&dirdata" file="myplot_harvest.html"  style=journal; 
proc sgplot data=dmid2;
histogram carat;
run;
ods html5 close;
/* Getting more control in a graph. 
	Determining the splits, and more. An example. */
	
proc sgplot data=dmid2;
	histogram carat/
		BINSTART= 0.1   /* start and width define the breaks */
		BINWIDTH= 0.1
		BOUNDARY= LOWER 
		nofill
		scale=count; 
run;

proc sgscatter data=perm.dmid_formats;
	matrix price carat clarity color/ 
		diagonal=(histogram kernel);
run;
***********************************;
proc freq data=dmid2 noprint;
	tables carat/nocum nopercent 
		out=caratTable1 (rename=(carat=Carat COUNT=Count));
run;
* (I made an attempt here to rename some variables to get a nicer look, 
	but this did not work. Basically, the names are not case-sensitive ...);

proc print data=caratTable1 (obs=5);
run;

proc sgplot data=caratTable1;
	needle x=carat y=count;
run;

* Let's do a bit more playing around to get a nicer graph, 
*	before we do some other work:

* cut off highest values (not interesting here) to 
*	get better resolution:;

proc sgplot data=caratTable1;
	needle x=carat y=count;
	xaxis min=0.2 max=2.2;
run;
***************************************;

* 1. sort to prepare for the next step;
proc sort data=caratTable1 out=carat20;
	by descending count;
run;
proc print data=_last_ (obs=5);run;

* 2. select the top 20 counts and create a character
	variable to hold the carat values;
data carat20;
	set carat20;
	if _n_=21 then stop;
	length caratc20 $4;
	caratc20=put(carat,4.2);
run;
proc print data=_last_ (obs=5);run;

* 3. sort by carat for the merge step. Also print out;
proc sort; by carat;run;
proc print; run;


* 4. merge this with the earlier data. This will 
	be used to create the labels. Note that 
	caratc20 = the carat value for the top 20 and is "" otherwise;
data caratTable2;
	merge caratTable1 carat20;
	by carat;
run;
proc print data=_last_ (obs=35);run; * print out a subset;
* redraw the graph with these labels;
title "Distribution of carats (up to 2.2 carats)";
title2 "with some key carat values highlighted.";
proc sgplot data=caratTable2;
	needle x=carat y=count/datalabel=caratc20 datalabelattrs=(color=red);
	xaxis min=0.2 max=2.2;
run;
********************************************;
* For discrete variables, we can use vbar (vertical bar chart)
	or hbar (horizontal bar chart);

title 'Frequency counts for clarity';
proc sgplot data=dmid2;
	vbar clarity;
run;

title 'Mean price for each clarity level';
proc sgplot data=dmid2;
	vbar clarity/response=price stat=mean; * options are freq, mean, sum;
	format price dollar6.0;
run;

* Boxplots of price, vs. cut and clarity. (The diamond represents the mean.);

title;
proc sgplot data=dmid2;
	vbox price/category=cut;
	format price dollar6.0;
run;
proc sgplot data=dmid2;
	vbox price/category=clarity;
	format price dollar6.0;
run;
*******************************;
* For the third dimension, I will add carat back in. Because
*	carat and price are continuous, but clarity is discrete,
*	I will naturally use clarity for the color:

* However, I am going to use the existing styles (I will
	not try to recreate the gray scale by creating a new style);

title "First try at grouping:clarity by color";
proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price/group=clarity;
	xaxis type=log ;
	yaxis type=log;
run;

title "Second try at grouping:clarity by color";

proc sgplot data=perm.dmid_formats;
	scatter x=carat y=price/group=clarity grouporder= ascending;
	xaxis type=log ;
	yaxis type=log;
run; 
******************************;
title;
proc sgscatter data=dmid2;
	plot price*table (price table x)*carat;
run;
*****************************************************;
data balances;
	infile "&dirdata.balances.csv" dsd firstobs=2;
	input customer $ checking savings mortgage credit_card;
run;
proc print data=balances;run;
/* Example 1. A simple transpose */

/* NOTE: We will *not* start with "melting" the SAS data set.
	We simply reshape it from its current state to another state */

/*	\ we want the rows to be columns and we
	want the columns to be rows */

/*	1. Which variable in the input data set contains (after formatting!)
		the variable names (columns) of the output data set?

		This variable is specified in the ID statement. 


	2. Which variable(s) (columns) in the input data set contain the 
		values to be transposed?

		These variables are declared in the VAR statement */


* Question: For this problem, what is the ID var? The VAR var(s)?;
proc transpose data=balances out=balances2;
	id customer;
	var checking--credit_card;
run;
proc print;run;

proc transpose data=balances out=balances2 name=account;
	id customer;
	var checking--credit_card;
run;
proc print;run;
/*
So, we want 
	1. *customer* to remain as a column
	2. A new column that contains checking, ..., credit_card
		as values
	3. A new column that contain the numeric values

	The SAS way to think about this:
	a. Look at the Smith row of data. We really want to 
		transpose the rest of this row (from 1x4 to 4x1). Yes?
	b. We want to transpose the Jones row in the same way.
	c. That is, we want to transpose "BY customer" */

* Question: What is the ID var now? What is the VAR var(s) now?;
proc print data=balances;run; * a reminder;

proc sort data=balances out=temp1; 
	* out=temp1 to preserve the original data set for our exercises;
	by customer;
run;

proc transpose data=temp1 out=balances_melt name=account;
	var checking--credit_card;
	by customer;
run;
proc print data=balances_melt;run;


data balances_melt2;
	retain customer type;
	set balances_melt;
	length type $11;
	if account in ("checking" "savings") then
		type="assets"; else type="liabilities";
run;
proc print data=balances_melt2;run;
/* Using this SAS data wet we want to:
	Transpose the data set, keeping type and variable as the way it is, but the values of customer
	variable (John and Smith) will now becomes columns.

* Question: 
		What is the ID var now?
		What is the VAR var(s) now?
		What is the BY var(s) now?
*/

proc sort data=balances_melt2 out=temp2;
	by type account;
run;

proc transpose data=temp2 out=temp2a;
	id customer;
	by type account;
run;
proc print data=temp2a;run;
***********************************;

proc sort data=balances_melt2 out=temp3;
	by customer account;
run;
proc print data=temp3; run;

proc transpose data=temp3 out=temp3a;
	id type;
	by customer account;
run;
proc print data=temp3a;run;

/* Let's see what happens if the the combination of the var's 
	in the ID and BY statements do *not* uniquely identify a row.
	Customer stays as a column, but only specify that the value of type (assets and liabilities) to be become columns.
 */

/* No need for PROC sort--temp3 is "BY customer" */
proc transpose data=temp3 out=temp3b;
	id type;
	by customer;
run;

/* Example 4. Getting summary data, then reshaping
	First get the summary of data (sum, number counts or you can get mean median...)
	Output a separate table of the summary of data. 
	Transpose this summary table into a wide format data set. 
	Then combine (merge) with the result of previous step. 
	We have a new data set and has extra columns of summary data. 
*/

proc print data=balances_melt2;run;

* First, find the sum and N of accounts for each customer and type
	(easier in the melted form: yes? And easier to extend to more 
	complex problems?) ;
proc means data=balances_melt2 noprint;
	by customer type; * in correct order...;
	var col1;
	output out=temp4 (drop=_type_ _freq_) sum=sum n=n;
run;
data temp4;
	set temp4;
	sum=round(sum);
run;
proc print data=temp4;run;
proc transpose data=temp4 out=temp4a (rename=(col1=value)) name=variable;
	by customer type;
	var sum n;
run;
proc print data=temp4a;run;
/* We'd like to change *two*
	columns from going "down" to going "across", and
	such a change is what the ID var does.

	It turns out we can do this, but to make
	the var names look nice, we should include
	a delimiter. Here's how: */

* For Jones, we want the 4x1 set of numbers to become 1x4,
	and the same is true for Smith. So, customer is our BY var
	(See? We want to transpose, by customer, from 4x1
	to 1x4) ;
proc transpose data=temp4a out=temp4b delimiter=_;
	by customer;
	id type variable;
	var value;
run;
proc print data=temp4b;run;
*****************************************************;
/* Second data set: the Pew study*/

proc contents data=perm.pew_table order=varnum; run;
proc print data=perm.pew_table;
run;

*Note: I changed the var names to be acceptable to SAS.;



*The usual questions: how? ID var? VAR var(s)? BY var(s)?

*Well, I hope by now you are realizing that when we put 
	all of the numeric data into one column that there 
	is no ID var (If there were, and that ID var
	had m distinct values--then this would
	put the numeric data into m columns. Not what we want.);

*Also (in this example) we want the data for each religion, 
	which is currently 1x10, to be transposed to 10x1.
	So, we want to transpose BY religion;

proc transpose data=perm.pew_table out=pew_melt (rename=(col1=freq)) name=income;
	by religion; * already sorted...;
	var S10k--DKR;
run;
proc print data=pew_melt(obs=12);run;


/* (Note how SAS also saves labeling information.) */

/*	This is how we could "cast" the data back to its 
		original form, including labels: */
proc transpose data=pew_melt out=temp5 (drop=_NAME_);
	by religion;
	id income;
	idlabel _LABEL_;
run;
proc print;run;
proc print label;run;
proc contents order=varnum;run;

/* 
	To begin, let's find the distribution of religions in the study:*/

* First, find the total freq for each religion.;

* (Question, for you to figure out: 
	easier to do this in the melted form or the original form?);

proc means data=pew_melt noprint;
	by religion;
	var freq;
	output out=pew_religions (drop=_type_ _freq_) sum=sum;
run;

* Second, find the grand total;
proc means data=pew_religions noprint;
	var sum;
	output out=pew_total (drop=_type_ _freq_) sum=gr_sum;
run;

* Third, combine these to get the percents;
data pew_religions;
	drop gr_sum;
	if _n_=1 then set pew_total;
	set pew_religions;
	pct=sum/gr_sum;
	format pct percent7.1; *does not look good with 5.1 or 6.1--try it;
run;
proc print data=pew_religions (obs=12);run;

** Redo for income...;
proc sort data=pew_melt out=pew_melt_IncOrd;
	by income;
run;

proc means data=pew_melt_IncOrd noprint;
	by income;
	var freq;
	output out=pew_incomes (drop=_type_ _freq_) sum=sum;
run;

data pew_incomes;
	drop gr_sum;
	if _n_=1 then set pew_total;
	set pew_incomes;
	pct=sum/gr_sum;
	format pct percent7.1; 
run;
proc print data=pew_incomes (obs=12);run;

* But note that the data is now arranged incorrectly--
	not good for presenting;

* You may want to think about:
	1. How SAS does have this problem.
	2. Whether this problem can be corrected in SAS;

* Questions?;


*   *********** Stop 7a ***********;





/* let's say we want to find the income  
	distribution for each religion. One objective is
	to see what the percent of "Don't know/refused" to tell
	their income are for each religion. If it varies widely,
	that is another source of concern. */

/* Well, we can do this as follows 
	(and as you should know by now!) */

data pew_melt2;
	merge pew_melt pew_religions (keep=religion sum);
	by religion;
	pctIncByRel=freq/sum;
	format pctIncByRel percent7.1;
run;
proc print data=_last_ (obs=12);run;

* let's just list out the Don't know pct for each religion;
proc print data=pew_melt2;
	where income="DKR";
	var religion income pctIncByRel;
run;

* Aside: this result could also be obtained directly in
	PROC TABULATE, and the results could be saved;
proc tabulate data=pew_melt out=pew_tableA;
	var freq;
	class religion income;
	table religion,(income all)*freq*rowpctsum*f=7.1;
run;

* However, you can see (if you haven't already) that SAS gave an
	(unwanted) label to *income* and the income levels are in
	alphabetical order (which is meaningless);
proc print data=pew_tableA (obs=12);run;
proc print data=pew_tableA (firstobs=175 obs=198);run;
	* data from PROC TABULATE is in a "melted" form. But it has some
		unwanted vars and--because of the "all" in PROC TABULATE
		--has some unwanted rows as well;
* End of Aside;



* Questions?;


*   *********** Stop 7b ***********;
