/*** HELP START ***//*
### Macro:
    %validate_end

### Purpose:
    Finalize the HTML validation report after all validation
    cases have been executed.

### Parameters:
- None.

### Notes:
- Call once after completing all %validate_case executions.
- Adds the final report footer.
- Closes the HTML reporting destination.
- Restores the SAS LISTING destination.
- Clears existing titles and footnotes.
- Completes the report initialized by %validate_init.

### Sample code:
~~~sas
%validate_end();
~~~

### URL:
https://github.com/manivannan-mathiazhagan/validation_utils

---
Author: Manivannan Mathialagan
Latest update Date: 2026-10-25
---
*//*** HELP END ***/

%macro validate_end();
    ods text="^S={font_size=6pt} ";
    ods text="^S={font_size=8pt color=cx667085 just=center}&_vld_footer";
    ods html5 close;
    ods listing;
    title;
    footnote;
    %put NOTE: Validation HTML report requested: &_vld_output;
%mend validate_end;