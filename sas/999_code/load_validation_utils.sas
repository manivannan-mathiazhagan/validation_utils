/* Initialize SPF */
filename spfinit url
"https://raw.githubusercontent.com/yabwon/SAS_PACKAGES/main/SPF/SPFinit.sas";

%include spfinit;

/* Writable package location */
filename packages "%sysfunc(pathname(work))";

/* Install from GitHub release */
%installPackage(
    validation_utils,
    sourcePath=https://github.com/manivannan-mathiazhagan/validation_utils/releases/download/v0.1.0/
);

/* Check installed packages */
%listPackages();

/* Load specific version */
%loadPackage(
    validation_utils,
    requiredVersion=0.1.0
);

/* Verify macros */
%put NOTE: VALIDATE_INIT=%sysmacexist(validate_init);
%put NOTE: VALIDATE_CASE=%sysmacexist(validate_case);
%put NOTE: VALIDATE_END=%sysmacexist(validate_end);