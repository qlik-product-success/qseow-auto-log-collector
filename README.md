# qseow-auto-log-collector
Auto Log Collector script for Qlik Sense Enterprise on Windows

## Prerequisites to use this script:
- Qlik Sense Enterprise on Windows must be installed.
- Repository service must be running (this tool uses the repository service to gather the logs).


## Command Arguments:
- **UrlUploadDestination** - Filecloud location to which logs will be uploaded. Must be a valid Filecloud url.
- **CaseNumber** - Case number which has been communicated by support or which you find in the case portal in Salesforce. Value cannot be empty. 
- **TimeRangeInHours** - Time range for which QRS will fetch logs. For example, if "25" is passed in as an argument, QRS will fetch the logs between now and 25 hours ago.
    This argument should be in accordance to the time interval to which you schedule this script to run in order to avoid unwanted results.
    For example, if you schedule this script to run every 48 hours, then TimeRangeInHours should be 49 (48 hours + 1 to bridge any gap).
    If you set the script to run every 48 hours, and do not provide an argument of 49 hours, then it will default to 25, which means every time the script executes,
    you'll be missing 24 hours worth of logs. 
    The default value for this is 25 hours.
- **LocalTempContentPath** - The path to which QRS outputs the logs after collecting them. Default value is "C:\ProgramData\Qlik\Sense\Repository\TempContent\".
- **Options** - Additional Folders to gather upon log collection. Must be a comma separated value ie.options: eventlog,systeminfo,scriptlogs,allfolders
    To include Windows event logs: eventlog
    To include system information: systeminfo
    To include scriptlog files from Qlik folders: scriptlogs
    To ignore log-folder filter and export all: allfolders
    https://help.qlik.com/en-US/sense-admin/May2024/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Managing_QSEoW/log-collector.htm

## Command to Run the script:
```
.\autoLogCollector.ps1 -UrlUploadDestination "https://files.qlik.com/url/qahacjvapgdfwuw6" -CaseNumber "00168341"
```
```
.\autoLogCollector.ps1 -UrlUploadDestination "https://files.qlik.com/url/qahacjvapgdfwuw6" -CaseNumber "00168341" -Options "eventlog,systeminfo,scriptlogs,allfolders"
```

## Schedule the Script to run once a day (or your desired frequency) using the Windows Task Scheduler.
Steps:
- Open Task Scheduler. Click on Start and type “Task scheduler” to open it. Or select it in the Start Menu under Windows Administrative Tools (or Windows Tools when using Win 11)
  ![Open Task Scheduler](/images/1.png "Open Task Scheduler")
- Create a Basic Task.
![Create a Basic Task](/images/2.png "Create a Basic Task")
- Select how often to trigger. Select the frequency you want the task to run. Recommended is 1 Day. Remember to update the TimeRangeInHours param supplied to script if choosing a different time interval.

  ![Select how often to trigger](/images/3.png "Select how often to trigger")
- Select the time of day you'd like the script to run. Here is where you can modify the schedule to select other options like "run every 2 days.
  ![Select time of day](/images/4.png "Select time of day to run")
- Set the Action you want the scheduler to perform. Select "Start A Program"
  ![Set the action](/images/5.png "Set the action")
- Set the arguments on "Start a Program"
    - Program/Script: powershell.exe
    - Arguments example: -File "[YOUR PATH TO THE SCRIPT]\autoLogCollector.ps1" -UrlUploadDestination "https://files.qlik.com/url/qahacjvapgdfwuw6" -CaseNumber "00168341" [and any additional params you want to set]
    - Start In: [add path to the same location the script is in]. Any output files will be placed in this location.
![Set arguments](/images/6.png "Set the action")

- Select "Next" and select the "Open properties dialog for this task" checkbox for additional configuration. Select "Finish".
![Finish](/images/7.png "Finish")


