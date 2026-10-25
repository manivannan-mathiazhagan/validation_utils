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
- Displays output once as a comparison view; new variables are green.
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

    /* 1. Macro call: one HTML PRE block, no table row lines. */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91}Macro Call";

    data work._validate_call;
        length source $32767 token $32767 ch $1 quotechar $1
               line $32767 escaped $32767 html $32767;
        source=strip(symget('_vld_call'));
        depth=0; argdepth=.; quotechar=' '; token=''; html='';
        do pos=1 to lengthn(source);
            ch=substr(source,pos,1);
            if quotechar ne ' ' then do;
                token=cats(token,ch);
                if ch=quotechar then do;
                    if pos<lengthn(source) and substr(source,pos+1,1)=quotechar then do;
                        pos+1;
                        token=cats(token,quotechar);
                    end;
                    else quotechar=' ';
                end;
            end;
            else if ch in ('"',"'") then do;
                quotechar=ch;
                token=cats(token,ch);
            end;
            else if ch='(' then do;
                depth+1;
                token=cats(token,ch);
                if missing(argdepth) then do;
                    argdepth=depth;
                    link appendline;
                    token='';
                end;
            end;
            else if ch=')' then do;
                if depth=argdepth then do;
                    if not missing(strip(token)) then do;
                        token=cats('    ',strip(token));
                        link appendline;
                    end;
                    token=')';
                    link appendline;
                    token='';
                end;
                else token=cats(token,ch);
                depth=max(0,depth-1);
            end;
            else if ch=',' and depth=argdepth then do;
                token=cats('    ',strip(token),',');
                link appendline;
                token='';
            end;
            else token=cats(token,ch);
        end;
        if not missing(strip(token)) then link appendline;
        html=cats('<pre style="margin:0;font-family:Consolas,monospace;',
                  'white-space:pre-wrap;overflow-wrap:anywhere;">',html,'</pre>');
        output;
        keep html;
        return;

    appendline:
        line=strip(token);
        /* Space around parameter = (only the first equals sign). */
        eq=index(line,'=');
        if eq>0 then
            line=cats(substr(line,1,eq-1),' = ',substr(line,eq+1));
        escaped=trim(line);
        escaped=tranwrd(escaped,'&','&amp;');
        escaped=tranwrd(escaped,'<','&lt;');
        escaped=tranwrd(escaped,'>','&gt;');
        escaped=tranwrd(escaped,'"','&quot;');
        html=cats(html,escaped,'&#10;');
        return;
    run;

    proc report data=work._validate_call nowd noheader
        style(report)=[outputwidth=100% frame=void rules=none borderwidth=0]
        style(column)=[asis=on borderwidth=0 cellpadding=8];
        columns html;
        define html / display style(column)=[cellwidth=100%];
    run;

    /* 2. Execution log: one continuous PRE block, not one row per NOTE. */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91}Execution Log (NOTE / WARNING / ERROR)";

    data work._validate_logdisplay;
        length html $32767 escaped $8000;
        retain html '' used 0 omitted 0;
        set work._validate_log end=last;
        escaped=strip(message);
        escaped=tranwrd(escaped,'&','&amp;');
        escaped=tranwrd(escaped,'<','&lt;');
        escaped=tranwrd(escaped,'>','&gt;');
        escaped=tranwrd(escaped,'"','&quot;');
        if used+lengthn(escaped)+6<30000 then do;
            html=cats(html,escaped,'&#10;');
            used=used+lengthn(escaped)+6;
        end;
        else omitted+1;
        if last then do;
            if omitted then
                html=cats(html,'[Additional log messages omitted: ',strip(put(omitted,best.)),']');
            html=cats('<pre style="margin:0;font-family:Consolas,monospace;',
                      'font-size:12px;line-height:1.5;white-space:pre-wrap;',
                      'overflow-wrap:anywhere;background:#f7f8fa;padding:10px;">',
                      html,'</pre>');
            output;
        end;
        keep html;
    run;

    %if &_nlog > 0 %then %do;
        proc report data=work._validate_logdisplay nowd noheader
            style(report)=[outputwidth=100% frame=void rules=none borderwidth=0]
            style(column)=[asis=on borderwidth=0 cellpadding=0];
            columns html;
            define html / display style(column)=[cellwidth=100%];
        run;
    %end;
    %else %do;
        ods text="No NOTE, WARNING or ERROR messages were captured.";
    %end;
    %if &_probe=0 %then %do;
        ods text="^S={color=cxB42318}CAPTURE WARNING: Probe missing from log. Verify PROC PRINTTO.";
    %end;

    /* 3. Compare input metadata with output; display output once. */
    ods text="^S={font_weight=bold font_size=10pt color=cx245C91 just=center}Input vs. Output Comparison: &input -> &output";
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

        /* Output contains retained input values plus highlighted new columns. */
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
