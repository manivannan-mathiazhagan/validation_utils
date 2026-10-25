/* Initialize SPF directly from GitHub */
filename spfinit url "https://raw.githubusercontent.com/yabwon/SAS_PACKAGES/main/SPF/SPFinit.sas";
%include spfinit;

/* Set package installation directory */
filename packages "%sysfunc(pathname(work))";

/* Install validation_utils v0.1.0 from GitHub */
%installPackage(
    validation_utils,
    sourcePath=https://github.com/manivannan-mathiazhagan/validation_utils/releases/download/v0.1.0/
);

/* Load the installed package */
%loadPackage(validation_utils, requiredVersion=0.1.0);

/* Verify macros */
%put NOTE: validate_init = %sysmacexist(validate_init);
%put NOTE: validate_case = %sysmacexist(validate_case);
%put NOTE: validate_end  = %sysmacexist(validate_end);