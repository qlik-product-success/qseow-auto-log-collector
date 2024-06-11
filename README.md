# qseow-auto-log-collector
Auto Log Collector script for Qlik Sense Enterprise on Windows

## Prerequisites to use this script:
- Qlik Sense Enterprise on Windows must be installed.
- Repository service must be running (this tool uses the repository service to gather the logs).


## Command Arguments:
- **UrlUploadDestination** - Filecloud location to which logs will be uploaded. Must be a valid Filecloud url.
- **CaseNumber** - The case number found in Salesforce. Value cannot be empty.
- **TimeRangeInHours** - Time range for which QRS will fetch logs. For example, if "25" is passed in as an argument, QRS will fetch the logs between now and 25 hours ago.
    This argument should be in accordance to the time interval to which you schedule this script to run in order to avoid unwanted results.
    For example, if you schedule this script to run every 48 hours, then TimeRangeInHours should be 49 (48 hours + 1 to bridge any gap).
    If you set the script to run every 48 hours, and do not provide an argument of 49 hours, then it will default to 25, which means every time the script executes,
    you'll be missing 24 hours worth of logs. 
    The default value for this is 25 hours.
- **LocalTempContentPath** - The path to which QRS outputs the logs after collecting them. Default value is "C:\ProgramData\Qlik\Sense\Repository\TempContent\".
    

## Command to Run the script:
```
.\autoLogCollector.ps1 -UrlUploadDestination "
https://files.qlik.com/ui/core/index.html?mode=upload#/SHARED/%21UBQFBx7wFdQ2OoMnV/javEIJYoP6KL35Tt"
-CaseNumber "00168341"
```