# QSE on Windows Auto Log collector

The `autoLogCollector.ps1` script can automate the process of collecting logs from Qlik Sense Enterprise on Windows and uploading them to Qlik Support. This can streamline recurring (daily) log uploads for complex investigations and ensure that new logs are provided to Qlik Support in a timely manner.  

The log collection is triggered in the same way as when it is run manually from [QMC > Log collector](https://help.qlik.com/en-US/sense-admin/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Managing_QSEoW/log-collector.htm), through the Qlik Sense Repository service (QRS) on the node where the script is executed.  
The extracted log file ZIP archive is automatically uploaded to the Qlik Support file share path referred to in the related support case. 

By scheduling the script execution through Windows Task Scheduler new logs can be provided to Qlik support at a regular interval. Please agree with Qlik Support on the time period of running automatic log collection, 

## Prerequisites 
### Server
- Qlik Sense Enterprise on Windows must be installed.
- Qlik Sense Repository service must be running at the time of script execution.
- Powershell running as Administrator
### Support Case
- You have an open and active ticket with Qlik Support
- Qlik support has advised that you use automatic log upload

## Command Arguments
```
autoLogCollector.ps1 -UrlUploadDestination "FILE_CLOUD_URL" `
                     -CaseNumber "CASE_NUMBER" `
                    [-TimeRangeInHours HOURS] `
                    [-LocalTempContentPath "FOLDER_PATH"] `
                    [-Options "LOG_OPTIONS"] `
```

| Attribute                | Required   | Details                                          |
| :---                     | :---       | :---
| `UrlUploadDestination`   | Mandatory  | Upload (FileCloud) URL as provided by Qlik Support on an open support case.  |
| `CaseNumber`             | Mandatory  | Case number which has been communicated by support or which you find in the case portal in Salesforce. Value cannot be empty. |
| `TimeRangeInHours`       | Optional   | Time range for which QRS will fetch logs. For example, if "25" is passed in as an argument, QRS will fetch the logs between now and 25 hours ago. <BR/> This argument should be in accordance with the time interval to which you schedule this script to run in order to avoid unwanted results. <BR/> <BR/>For example, if you schedule this script to run every 48 hours, then TimeRangeInHours should be 49 (48 hours + 1 to bridge any gap). <BR/> <BR/> If you set the script to run every 48 hours and do not provide an argument of 49 hours, then it will default to 25, which means every time the script executes, you'll be missing 24 hours worth of logs. <BR/> The default value is `25` hours. |
| `LocalTempContentPath`   | Optional   | Folder path to local QRS log output after collecting them. <BR/> Default value is `C:\ProgramData\Qlik\Sense\Repository\TempContent\` |
| `Options`                | Optional   | Additional folders to gather upon log collection. <BR/> Must be a comma-separated value of options:<BR/>`eventlog` to include Windows event logs.<BR/>`systeminfo` to include system information. <BR/>`scriptlogs` to include script log files. Only use if requested by Support.  <BR/>`allfolders` to ignore log-folder filter and export all. <BR/> See Qlik Help [QMC > Log collector](https://help.qlik.com/en-US/sense-admin/Subsystems/DeployAdministerQSE/Content/Sense_DeployAdminister/QSEoW/Administer_QSEoW/Managing_QSEoW/log-collector.htm) for more details. |

## Examples

```
.\autoLogCollector.ps1 -UrlUploadDestination "https://files.qlik.com/url/qahacjvapgdfwuw6" `
                       -CaseNumber "00168341"
```

Collect standard Qlik Sense logs for support case `00168341` from the past 25 hours. 
The collected log ZIP archive is uploaded to `https://files.qlik.com/url/qahacjvapgdfwuw6`.

```
.\autoLogCollector.ps1 -UrlUploadDestination "https://files.qlik.com/url/qahacjvapgdfwuw6" `
                       -CaseNumber "00168341" `
                       -Options "eventlog,systeminfo,allfolders"
```

Collect extensive logs for support case `00168341` from the past 25 hours. 
The collected log ZIP archive will contain Qlik Sense logs from all services, Windows Event logs, server system info.
The ZIP archive is uploaded to `https://files.qlik.com/url/qahacjvapgdfwuw6`.

## Confirguration

### Install script

1. Download [autoLogCollector.ps1](https://raw.githubusercontent.com/qlik-product-success/qseow-auto-log-collector/main/autoLogCollector.ps1) and to Qlik Sense central node. 
2. Save `autoLogCollector.ps1` in a folder that is accessible to the system when running a scheduled task. For example under `c:\qseow-auto-log\`.
3. Get the upload URL and case number from the Qlik Support portal. <BR/> IMPORTANT: you must use the correct URL and matching support case number for the upload to be successful and correctly routed on the Qlik Support side.
4. Manually test that the script can execute successfully before continuing to automation
   a. Run PowerShell prompt As Adminstrator
   b. Navigate to the folder where you saved `autoLogCollector.ps1`
      ```
      PS> cd c:\qseow-auto-log\
      ```

### Schedule execution

the Script to run once a day (or your desired frequency) using the Windows Task Scheduler.
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

# License
This project is provided "AS IS", without any warranty, under the MIT License - see the [LICENSE](./LICENSE) file for details
