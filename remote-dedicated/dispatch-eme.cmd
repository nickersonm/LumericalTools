@echo off
REM Dispatch file to local server, intended to report progress

SET plink=plink
SET pscp=pscp
SET login=user@lumerical
SET remoteDIR=~/lumerical/tmp
SET remoteRUN=~/lumerical/run_eme.sh


%pscp% -C -batch -q %1 %login%:"%remoteDIR%/%~nx1"
%plink% -batch %login% %remoteRUN% "%remoteDIR%/%~nx1"
%pscp% -C -batch -q %login%:"%remoteDIR%/%~nx1" %1
%plink% -batch %login% rm "%remoteDIR%/%~n1.*"
