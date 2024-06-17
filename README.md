# QSE on Windows Auto Log collector

The `autoLogCollector.ps1` script can be used to automate the process of collecting logs from Qlik Sense Enterprise on Windows and uploading them to Qlik Support. This can be useful to streamline reoccurring (daily) log uploads for complex investigations. 

The log collection is triggered in the same way as when it is run manually from [QMC > Log collector](https://help.qlik.com/en-US/sense-admin/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Managing_QSEoW/log-collector.htm), through the Qlik Sense Repository service on the node where the script is executed.  
The extracted log file ZIP archive is automatically uploaded to the Qlik Support file share path referred to in the related support case. 

This script enables scheduled log collection and automatic upload of Qlik Sense Enterprise logs to Qlik Support.

## Prerequisites to use this script
- Qlik Sense Enterprise on Windows must be installed.
- qlik Sense Repository service must be running (this tool uses the repository service to gather the logs). 

## Command Arguments
```
autoLogCollector.ps1 -UrlUploadDestination "FILE_CLOUD_URL" `
                     -CaseNumber "CASE_NUMBER" `
                    [-TimeRangeInHours HOURS] `
                    [-LocalTempContentPath "FOLDER_PATH"] `
                    [-Options "LOG_OPTIONS"] `
```

| Attribute                | Details                                          |
|---                       | ----       |
| `UrlUploadDestination`   | Filecloud location to which logs will be uploaded. Must be a valid Filecloud url. |
| `CaseNumber`             | Case number which has been communicated by support or which you find in the case portal in Salesforce. Value cannot be empty. |
| `TimeRangeInHours`       | Time range for which QRS will fetch logs. For example, if "25" is passed in as an argument, QRS will fetch the logs between now and 25 hours ago. <BR/> This argument should be in accordance to the time interval to which you schedule this script to run in order to avoid unwanted results. <BR/> For example, if you schedule this script to run every 48 hours, then TimeRangeInHours should be 49 (48 hours + 1 to bridge any gap). <BR/> If you set the script to run every 48 hours, and do not provide an argument of 49 hours, then it will default to 25, which means every time the script executes, you'll be missing 24 hours worth of logs. The default value for this is 25 hours. |
| `LocalTempContentPath`   | The path to which QRS outputs the logs after collecting them. Default value is `C:\ProgramData\Qlik\Sense\Repository\TempContent\` |
| `Options`                | Additional folders to gather upon log collection. Must be a comma-separated value of options:<BR/>`eventlog` to include Windows event logs.<BR/>`systeminfo` to include system information. <BR/>`scriptlogs` to include script log files from Qlik folders. <BR/>`allfolders` to ignore log-folder filter and export all. <BR/> See Qlik Help [QMC > Log collector](https://help.qlik.com/en-US/sense-admin/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Managing_QSEoW/log-collector.htm) for more details. |

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


## Additional Configuration Steps
- In the "General" tab, select "Run whether the user is logged on or not"
- ![General Properties](/images/8.png "General Properties")
- In the "Triggers" tab, select the trigger and edit it.
    - Select "Stop task if it runs longer than 3 days" (or set a different number of days if your configuration is different)
    - Set the expiration date to **30 days** after the initial date of setup. This means that after 30 days, the task will expire and will no longer continue running. This stop date must be set in order to avoid collecting an undersired amount of logs. Stop date can be set to any desired value, but use caution when setting it.
    -  ![Edit Trigger](/images/9.png "Edit Trigger")
    -  ![Set Expiration](/images/10.png "Set Expiration")
- The "Actions" tab does not need to be modified, unless you wish to provide additional parameters as arguments.
    -  ![Edit Trigger](/images/11.png "Edit Trigger")
- The "Conditions" tab may need to be modified, depending on your settings.
    -  ![Conditions Tab](/images/12.png "Conditions Tab")
- In the "Settings" tab, select "If the task fails, allow to restart every 5 minutes". 5 minutes is an arbitrary value and can be changed. Allow for a maximum of 3 retries to avoid being stuck in a "Retry" state if it fails.
    -  ![Settings Tab](/images/13.png "Settings Tab")
- Select "OK" to save all the changes. 

### It is important to verify that the script runs as intended, so select "Run" on the right hand side under the "Selected Item" actions to run the script manually. You should see PowerShell start up and the logging from the script show a successful run.
![Run](/images/14.png "Run")
