/*** HELP START ***//*
### Macro:
    %validate_case

### Purpose:
    Execute one validation case and document its input, formatted macro call,
    execution messages, and output. Highlight variables newly added to output.

### Parameters:
- id: Validation case ID.
- description: Scenario description.
- input: Input dataset.
- output: Output dataset.
- call: Macro invocation protected with %nrstr().

### Notes:
- Executes the target macro exactly once.
- New variables are detected by comparing input and output variable names.
- Existing variables remain uncolored; new output columns are green.
- Input/output tables are separate; row-level matching is not assumed.
- Formats the call with one parameter per line when commas separate
  top-level arguments (commas inside quotes or nested parentheses are kept).
- Requires %validate_init to have opened the HTML ODS destination.

### URL:
https://github.com/manivannan-mathiazhagan/validation_utils

---
Author: Manivannan Mathialagan
Latest update Date: 2026-10-25
---
*//*** HELP END ***/

%macro validate_case(id=,description=,input=,output=,call=);
    %local _oldsource _oldsource2 _oldmprint _oldmlogic _oldsymbolgen
           _nlog _probe _vld_call _in_exists _out_exists
           _newvars _outvars _nnew;

    %let _vld_call=%superq(call);
    %let _oldsource=%sysfunc(getoption(source));
    %let _oldsource2=%sysfunc(getoption(source2));
    %let _oldmprint=%sysfunc(getoption(mprint));
    %let _oldmlogic=%sysfunc(getoption(mlogic));
    %let _oldsymbolgen=%sysfunc(getoption(symbolgen));

    %let _in_exists=0;
    %let _out_exists=0;
    %if %length(%superq(input)) %then %let _in_exists=%sysfunc(exist(&input));

    /* Capture the target macro log and execute the call exactly once. */
    filename _vldlog temp;
    options notes nosource nosource2 nomprint nomlogic nosymbolgen;
    proc printto log=_vldlog new; run;
    %put NOTE: VALIDATE_CAPTURE_PROBE &id;
    %unquote(%superq(call));
    proc printto; run;
    options &_oldsource &_oldsource2 &_oldmprint &_oldmlogic &_oldsymbolgen;

    %if %length(%superq(output)) %then %let _out_exists=%sysfunc(exist(&output));

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

    proc sql noprint;
        select count(*), coalesce(sum(index(message,'VALIDATE_CAPTURE_PROBE')>0),0)
          into :_nlog trimmed, :_probe trimmed
        from work._validate_log;
    quit;

    ods text="^S={font_size=5pt} ";
    ods text="^S={font_weight=bold font_size=13pt color=cx174EA6 just=center}&id - &description";

    /* 1. Input */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Input Dataset: &input";
    %if &_in_exists %then %do;
        proc print data=&input noobs label
            style(table)=[width=100%]
            style(header)=[just=center font_size=10pt cellpadding=6pt]
            style(data)=[font_size=10pt cellpadding=6pt];
        run;
    %end;
    %else %do;
        ods text="Input dataset not available.";
    %end;

    /* 2. Pretty-print macro call. Split only at top-level argument commas. */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Macro Call";
    data work._validate_call;
        length source $32767 line $32767 token $32767 ch $1
               quote $1 prefix $256;
        source=strip(symget('_vld_call'));
        depth=0; quote=' '; token=''; lineno=0; argdepth=.;
        do pos=1 to lengthn(source);
            ch=substr(source,pos,1);
            if quote ne ' ' then do;
                token=cats(token,ch);
                if ch=quote then do;
                    if pos<lengthn(source) and substr(source,pos+1,1)=quote then do;
                        pos=pos+1;
                        token=cats(token,quote);
                    end;
                    else quote=' ';
                end;
            end;
            else if ch='"' or ch="'" then do;
                quote=ch;
                token=cats(token,ch);
            end;
            else if ch='(' then do;
                depth=depth+1;
                token=cats(token,ch);
                if missing(argdepth) then do;
                    /* First parenthesis begins the macro parameter list. */
                    argdepth=depth;
                    line=strip(token);
                    lineno+1; output;
                    token='';
                end;
            end;
            else if ch=')' then do;
                if depth=argdepth then do;
                    if not missing(strip(token)) then do;
                        line=cats('    ',strip(token));
                        lineno+1; output;
                        token='';
                    end;
                    line=repeat(' ',0)||')';
                    lineno+1; output;
                end;
                else token=cats(token,ch);
                depth=max(0,depth-1);
            end;
            else if ch=',' and depth=argdepth then do;
                line=cats('    ',strip(token),',');
                lineno+1; output;
                token='';
            end;
            else token=cats(token,ch);
        end;
        if not missing(strip(token)) then do;
            line=strip(token);
            lineno+1; output;
        end;
        keep lineno line;
    run;

    proc report data=work._validate_call nowd noheader
        style(report)=[outputwidth=100%]
        style(column)=[font_face="Courier New" font_size=8pt just=left asis=on];
        columns line;
        define line / display style(column)=[cellwidth=100%];
    run;

    /* 3. Execution log */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Execution Log (NOTE / WARNING / ERROR)";
    %if &_nlog > 0 %then %do;
        /* Render a continuous, borderless SAS-style log rather than
           one PROC REPORT table row per message. HTML entities are escaped. */
        data _null_;
            set work._validate_log end=last;
            length escaped $8000 html $12000 statement $16000;
            retain html '' lines 0;
            escaped=strip(message);
            escaped=tranwrd(escaped,'&','&amp;');
            escaped=tranwrd(escaped,'<','&lt;');
            escaped=tranwrd(escaped,'>','&gt;');
            escaped=tranwrd(escaped,'"','&quot;');
            escaped=tranwrd(escaped,"'",'&#39;');
            if lines=0 then
                html='<pre style="font-family:Consolas,monospace;font-size:12px;'
                    ||'line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere;'
                    ||'background:#f7f8fa;padding:12px;border:1px solid #e1e4e8;'
                    ||'border-radius:4px;margin:4px 0 10px 0">';
            /* Flush periodically so long logs do not exceed SAS string limits. */
            if lengthn(html)+lengthn(escaped)+8 > 10000 then do;
                statement=cats('ods html text=',quote(trim(html)||'</pre>'),';');
                call execute(statement);
                html='<pre style="font-family:Consolas,monospace;font-size:12px;'
                    ||'line-height:1.5;white-space:pre-wrap;overflow-wrap:anywhere;'
                    ||'background:#f7f8fa;padding:12px;border:1px solid #e1e4e8;'
                    ||'border-radius:4px;margin:4px 0 10px 0">';
                lines=0;
            end;
            html=cats(html,escaped,'&#10;');
            lines+1;
            if last then do;
                statement=cats('ods html text=',quote(trim(html)||'</pre>'),';');
                call execute(statement);
            end;
        run;
    %end;
    %else %do;
        ods text="^S={color=cxB42318 just=center}No NOTE, WARNING or ERROR messages were captured.";
    %end;
    %if &_probe=0 %then %do;
        ods text="^S={font_weight=bold color=cxB42318 just=center}CAPTURE WARNING: Probe missing from log. Verify PROC PRINTTO.";
    %end;

    /* 4. Output metadata comparison: only names absent from input are new. */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Output Dataset: &output";
    %if &_out_exists %then %do;
        proc contents data=&output out=work._validate_outmeta(keep=name varnum) noprint;
        run;
        %if &_in_exists %then %do;
            proc contents data=&input out=work._validate_inmeta(keep=name) noprint;
            run;
        %end;
        %else %do;
            data work._validate_inmeta;
                length name $32;
                stop;
            run;
        %end;

        proc sql noprint;
            create table work._validate_varmeta as
            select a.name, a.varnum,
                   case when b.name is null and &_in_exists=1 then 1 else 0 end as is_new
            from work._validate_outmeta as a
            left join work._validate_inmeta as b
              on upcase(a.name)=upcase(b.name)
            order by a.varnum;
            select name into :_outvars separated by ' '
              from work._validate_varmeta order by varnum;
            select count(*) into :_nnew trimmed
              from work._validate_varmeta where is_new=1;
            select name into :_newvars separated by ', '
              from work._validate_varmeta where is_new=1 order by varnum;
        quit;

        %if &_in_exists %then %do;
            %if &_nnew > 0 %then %do;
                ods text="^S={font_weight=bold color=cx137333}New variables (green): &_newvars";
            %end;
            %else %do;
                ods text="^S={color=cx5F6368}No new variables detected (based on variable names).";
            %end;
        %end;
        %else %do;
            ods text="^S={color=cx5F6368}New-variable comparison unavailable: input dataset missing.";
        %end;

        /* Generated DEFINE statements preserve original output variable order. */
        data _null_;
            set work._validate_varmeta end=last;
            length statement $1024;
            if _n_=1 then do;
                call execute('proc report data=&output nowd missing');
                call execute(' style(report)=[outputwidth=100%]');
                call execute(' style(header)=[just=center font_size=10pt cellpadding=6pt]');
                call execute(' style(column)=[font_size=10pt cellpadding=6pt];');
                call execute(' columns &_outvars;');
            end;
            if is_new then
                statement=cats('define ',name,
                    ' / display style(header)=[background=cxDDF5E3 foreground=cx137333 font_weight=bold]',
                    ' style(column)=[background=cxEBF8EF foreground=cx137333];');
            else statement=cats('define ',name,' / display;');
            call execute(statement);
            if last then call execute('run;');
        run;
    %end;
    %else %do;
        ods text="Output dataset not created.";
    %end;

    filename _vldlog clear;
%mend validate_case;
