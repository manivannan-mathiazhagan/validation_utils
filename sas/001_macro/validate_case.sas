
/*** HELP START ***//*
### Macro:
    %validate_case

### Purpose:
    Execute and document an individual SAS macro validation case.
    Capture execution messages and generate structured HTML output
    containing the input dataset, macro call, execution log,
    and output dataset.

### Parameters:
- id (required): Unique validation case identifier, e.g. T01 or N01.
- description (required): Description of the validation scenario.
- input: Input SAS dataset to display in the report.
- output: Expected output SAS dataset to display in the report.
- call (required): SAS macro invocation to execute.

### Notes:
- The supplied macro invocation is executed once per validation case.
- Use %nrstr() to prevent premature execution of the supplied macro.
- Captures NOTE, WARNING, and ERROR messages from the SAS log.
- Displays the actual input and output datasets.
- Reports when the expected output dataset is not created.
- Supports both positive and negative validation scenarios.
- Requires an HTML report initialized by %validate_init.
- Does not require separate start or end calls for individual cases.
- Temporary log files are managed using a SAS TEMP fileref.
- The validation report uses the HTML destination initialized by %validate_init.

### Sample code:
~~~sas
%validate_case(
    id=T01,
    description=Complete datetime retained,
    input=work.in_T01,
    output=work.out_T01,
    call=%nrstr(
        %derive_vars_dtm(
            dataset=work.in_T01,
            outdata=work.out_T01,
            new_vars_prefix=AST,
            dtc=DTC
        )
    )
);
~~~

### URL:
https://github.com/manivannan-mathiazhagan/validation_utils

---
Author: Manivannan Mathialagan
Latest update Date: 2026-10-25
---
*//*** HELP END ***/

%macro validate_case(id=,description=,input=,output=,call=);

    %local _oldsource _oldsource2 _oldmprint _oldmlogic _oldsymbolgen _nlog _probe _vld_call;

    /* Preserve the supplied macro invocation for reporting */
    %let _vld_call=%superq(call);

    /* Save current SAS logging options */
    %let _oldsource=%sysfunc(getoption(source));
    %let _oldsource2=%sysfunc(getoption(source2));
    %let _oldmprint=%sysfunc(getoption(mprint));
    %let _oldmlogic=%sysfunc(getoption(mlogic));
    %let _oldsymbolgen=%sysfunc(getoption(symbolgen));

    /* Capture the target macro execution log */
    filename _vldlog temp;
    options notes nosource nosource2 nomprint nomlogic nosymbolgen;
    proc printto log=_vldlog new; run;

    %put NOTE: VALIDATE_CAPTURE_PROBE &id;

    /* Execute the supplied macro invocation exactly once */
    %unquote(%superq(call));

    /* Restore SAS logging */
    proc printto; run;
    options &_oldsource &_oldsource2 &_oldmprint &_oldmlogic &_oldsymbolgen;

    /* Extract NOTE, WARNING and ERROR messages */
    data work._validate_log;
        length message $2000 raw $32767;
        infile _vldlog truncover lrecl=32767;
        input raw $char32767.;
        raw=strip(raw);
        if prxmatch('/^(ERROR|WARNING|NOTE):/i',raw) then do;
            message=substr(raw,1,2000);
            output;
        end;
        keep message;
    run;

    /* Count captured messages and verify log redirection */
    proc sql noprint;
        select count(*), coalesce(sum(index(message,'VALIDATE_CAPTURE_PROBE')>0),0)
        into :_nlog trimmed, :_probe trimmed
        from work._validate_log;
    quit;

    /* Validation case heading */
    ods text="^S={font_size=5pt} ";
    ods text="^S={font_weight=bold font_size=13pt color=cx174EA6 just=center}&id - &description";

    /* 1. Input Dataset */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Input Dataset: &input";

    %if %length(%superq(input)) and %sysfunc(exist(&input)) %then %do;
        proc print data=&input noobs label
            style(table)=[width=100%]
            style(header)=[just=center font_size=10pt cellpadding=6pt]
            style(data)=[font_size=10pt cellpadding=6pt];
        run;
    %end;
    %else %do;
        ods text="Input dataset not available.";
    %end;

    /* 2. Macro Call */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Macro Call";

    data work._validate_call;
        length macro_call $32767;
        macro_call=symget('_vld_call');
    run;

    proc report data=work._validate_call nowd noheader
        style(report)=[outputwidth=100%]
        style(column)=[font_face="Courier New" font_size=8pt just=left];
        columns macro_call;
        define macro_call / display;
    run;

    /* 3. Execution Log */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Execution Log (NOTE / WARNING / ERROR)";

    %if &_nlog > 0 %then %do;
        proc report data=work._validate_log nowd noheader
            style(report)=[outputwidth=100%]
            style(column)=[font_face="Courier New" font_size=8pt just=left];
            columns message;
            define message / display style(column)=[cellwidth=100%];
        run;
    %end;
    %else %do;
        ods text="^S={color=cxB42318 just=center}No NOTE, WARNING or ERROR messages were captured.";
    %end;

    %if &_probe=0 %then %do;
        ods text="^S={font_weight=bold color=cxB42318 just=center}CAPTURE WARNING: Probe missing from log. Verify PROC PRINTTO.";
    %end;

    /* 4. Output Dataset */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Output Dataset: &output";

    %if %length(%superq(output)) and %sysfunc(exist(&output)) %then %do;
        proc print data=&output noobs label
            style(table)=[width=100%]
            style(header)=[just=center font_size=10pt cellpadding=6pt]
            style(data)=[font_size=10pt cellpadding=6pt];
        run;
    %end;
    %else %do;
        ods text="Output dataset not created.";
    %end;

    /* Release temporary log */
    filename _vldlog clear;

%mend validate_case;
