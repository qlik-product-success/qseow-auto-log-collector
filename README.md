# qseow-auto-log-collector
Auto Log Collector script for Qlik Sense Enterprise on Windows

## Prerequisites to use this script:
- Qlik Sense Enterprise on Windows must be installed.
- Repository service must be running (this tool uses the repository service to gather the logs).



## Command Arguments:
- UrlUploadDestination - Value cannot be null. This is the Filecloud upload url.
- CaseNumber - Value cannot be null.
- TimeIntervalInHours - Default value is 25 hours.
- LocalTempContentPath - The path where the Repository service puts the log files temporarily. The default location is:
 "C:\ProgramData\Qlik\Sense\Repository\TempContent\".


## Command to Run the script:
```
.\autoLogCollector.ps1 -UrlUploadDestination "
https://files.qlik.com/ui/core/index.html?mode=upload#/SHARED/%21UBQFBx7wFdQ2OoMnV/javEIJYoP6KL35Tt"
-CaseNumber "00168341"
```