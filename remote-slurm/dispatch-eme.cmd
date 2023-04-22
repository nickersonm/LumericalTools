@echo off
REM Dispatch file to slurm, intended to report progress

SET plink=plink
SET pscp=pscp
SET login=user@slurm-host
SET slurmDIR=~/lumerical/tmp
SET slurmRUN=~/lumerical/Qrun_eme.sh


%pscp% -C -batch -q %1 %login%:"%slurmDIR%/%~nx1"
%plink% -batch %login% %slurmRUN% "%slurmDIR%/%~nx1"
%pscp% -C -batch -q %login%:"%slurmDIR%/%~nx1" %1
%plink% -batch %login% rm "%slurmDIR%/%~n1.*"
