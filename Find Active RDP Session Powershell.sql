# Account getting lock out when password changed? Run below script to find out where you are logged in
# Import the Active Directory module for the Get-ADComputer CmdLet
#Import-Module ActiveDirectory
#net group sqldba /domain
# Get today's date for the report
$today = Get-Date

# Setup email parameters
$subject = "ACTIVE SERVER SESSIONS REPORT - " + $today
$priority = "Normal"
$smtpServer = "smtp.domain.com"
$emailFrom = "ActiveSession@report.com"
$emailTo = "DistributionList@company.com"

# Create a fresh variable to collect the results. You can use this to output as desired
$SessionList = "ACTIVE SERVER SESSIONS REPORT - " + $today + "`n`n"

# Query Active Directory for computers running a Server operating system
# Copy all server node names here 

<#
--SQL Script to get node names.
IF SERVERPROPERTY('IsClustered') = 1
    BEGIN
        SELECT @@SERVERNAME SQLName,
               'Yes' [Cluster?],
               NodeName
        FROM sys.dm_os_cluster_nodes;
END;
    ELSE
    BEGIN
        SELECT @@SERVERNAME SQLName,
               'No' [Cluster?],
               SERVERPROPERTY('ComputerNamePhysicalNetBIOS') NodeName;
END;
#>
$Servers = Get-Content 'd:\Nimit\PName.txt'

# Loop through the list to query each server for login sessions
ForEach ($Server in $Servers) {
$server
$explorerprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ComputerName $Server -ErrorAction SilentlyContinue)
if ($explorerprocesses.Count -eq 0)
{
	  "No explorer process found / Nobody interactively logged in on " + $Server
} else {
    foreach ($i in $explorerprocesses)
			{
			$name = $i.csname
			$Username = $i.GetOwner().User
			$Domain = $i.GetOwner().Domain
      
      #I am filtering for just my ID, if you don't want to filter you can comment out if section below.
            if ($username -match "parikhn" -or $username -match "parikhni")
            {

			$SessionList = $SessionList + "`n`n" + $name + " " + $Domain + "\" + $Username + " logged on since: " + ($i.ConvertToDateTime($i.CreationDate)) 
			}
      }
		}
}


# Send the report email
Send-MailMessage -To $emailTo -Subject $subject -Body $SessionList -SmtpServer $smtpServer -From $emailFrom -Priority $priority

# When running interactively, uncomment the Write-Host line below to see the full list on screen
$SessionList
