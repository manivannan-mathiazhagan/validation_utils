/* Build Validation_Utils SPF Package */

%let repopath=D:\Work\MyGithub\validation_utils;
%let pkgsource=&repopath.\sas;
%let pkgoutput=&repopath.;

/* Initialize SPF directly from GitHub */
filename spfinit url "https://raw.githubusercontent.com/yabwon/SAS_PACKAGES/main/SPF/SPFinit.sas";
%include spfinit;

/* Generate package and documentation */
%generatePackage(filesLocation=&pkgsource., buildLocation=&pkgoutput., markdownDoc=1);

filename spfinit clear;