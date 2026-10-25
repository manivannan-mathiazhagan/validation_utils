/*** HELP START ***/
/*
### Macro:
    %validate_init

### Purpose:
    Initialize a single HTML validation report for SAS macro testing.
    Configure the report title, output destination, and reporting style.

### Parameters:
- macro: Name of the SAS macro being validated.
- title: Main HTML report title
    (default: SAS Macro Validation Report).
- subtitle: Optional subtitle displayed below the macro name.
- footer: Report footer text
    (default: Validation evidence).
- output (required): Full path and filename of the HTML report.

### Notes:
- Call once before executing any validation cases.
- Creates the HTML reporting environment using the HTMLBlue style.
- Generates the report title and introductory information only once.
- Subsequent validation cases are added using %validate_case.
- Finalize the report using %validate_end.
- The output directory must already exist.
- The footer text is stored for use by %validate_end.
- An error is reported if the OUTPUT parameter is missing.

### Sample code:
~~~sas
%validate_init(
    macro=derive_vars_dtm,
    title=SAS Macro Validation Report,
    subtitle=Positive and Negative Validation Scenarios,
    footer=Run by Manivannan Mathialagan on 25Oct2026,
    output=D:\Validation\test_derive_vars_dtm.html
);
~~~

### URL:
https://github.com/manivannan-mathiazhagan/validation_utils

---
Author: Manivannan Mathialagan
Latest update Date: 2026-10-25
---
*//*** HELP END ***/

%macro validate_init(
                    macro=,
                    title=SAS Macro Validation Report,
                    subtitle=,
                    footer=Validation evidence,
                    output=
                    );

    %global _vld_macro _vld_title _vld_subtitle _vld_footer _vld_output;

    /* Store report configuration */
    %let _vld_macro=%superq(macro);
    %let _vld_title=%superq(title);
    %let _vld_subtitle=%superq(subtitle);
    %let _vld_footer=%superq(footer);
    %let _vld_output=%superq(output);

    /* Validate required output parameter */
    %if %length(%superq(_vld_output)) = 0 %then %do;
        %put ERROR: [validate_init] OUTPUT parameter is required.;
        %return;
    %end;

    /* Configure reporting environment */
    options nodate nonumber;

    ods escapechar='^';
    ods listing close;

    title;
    footnote;

    /* Initialize HTML report */
    ods html5 file="&_vld_output" style=HTMLBlue options(bitmap_mode="inline");

    /* Report title */
    ods text= "^S={font_weight=bold font_size=17pt color=cx174EA6 just=center}&_vld_title";

    /* Macro name */
    ods text= "^S={font_weight=bold font_size=11pt just=center}Macro: &_vld_macro";

    /* Optional subtitle */
    %if %length(%superq(_vld_subtitle)) %then %do;
        ods text= "^S={font_size=10pt just=center}&_vld_subtitle";
    %end;

%mend validate_init;