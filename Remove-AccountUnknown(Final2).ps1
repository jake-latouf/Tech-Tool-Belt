##Check domain join status##
##Script run safety check##
Write-Host
Write-Host
Write-Host "Starting powershell script to remove unknown accounts... press any key to continue..."
Read-Host

#Error message for catch block
$errormessage1 = Write-Host "Computer not bound to domain properly... please perform a soft rebind and try again" -BackgroundColor Black -ForegroundColor Red

try {
    #test the computer's domain join status and throw a terminating exception if secure channel returns false. triggering catch block at the end of the script
    Test-ComputerSecureChannel -ErrorAction Stop

    #variable for system accounts (which should never be deleted)
    $systemaccounts = @('administrator', 'Public', 'default', 'DOMAIN\administrator', 'NetworkService', 'LocalService', 'systemprofile') 

    #variable for user profiles (excluding any system profiles)
    $onharddrive = Get-CimInstance win32_userprofile | Where-Object { $_.LocalPath.split('\')[-1] -notin $systemaccounts } -ErrorAction SilentlyContinue

    #empty arrays to add the objects that will be created later
    $knownAccounts = @()
    $unknownAccounts = @()

    #Run the command stored in $onharddrive and send each object down the pipeline through the scriptblock
    $onharddrive | ForEach-Object {
        
        ##Within the loop save profile to a variable called p##
        $p = $_

        try {
            #create a new object for SID and set error action preference to stop so that the catch block is triggered
            $pSID = New-Object System.Security.Principal.SecurityIdentifier($p.SID) -ErrorAction Stop

            ##Translate the SID we just created for each profile to NTAccountName
            $pSID.Translate([System.Security.Principal.NTAccount]) 

            ##create a PSCustom Object called user with attributes of AccountName, Path, and Localpath
            $knownuser = [PSCustomObject]@{
                AccountName = $ntAccount.Value
                Path        = $p.LocalPath
                SID         = $p.SID
            }
            ##Save each object to the array we created earlier
            $knownAccounts += $knownuser
        }
        ##if the account returns unknown, catch block is triggered##
        catch {
            $unknownuser = [PSCustomObject]@{
                AccountName = "Unknown"
                Path        = $p.LocalPath
                SID         = $p.SID
            }
            ##Save these results to a variable called UnknownAccounts##
            $unknownAccounts += $unknownuser
        }
    } | Select-Object $unknownAccounts.Path | Export-Csv -path C:\Users\Administrator\Desktop\UnknownAccounts.csv -NoTypeInformation


    ##display the last component of the LocalPath property for each unknown account and prompt for user input
    $unknownAccounts 
    Write-Warning "WARNING the accounts above will be permanently removed from the workstation..."
    $userinput = Read-Host "Do you wish to CONTINUE (y\n)" -BackgroundColor Black -ForegroundColor Yellow

    #if user selects yes, continue script, else exit script
    if($userinput.ToUpper() -eq "Y"){
        #Get all CIM instances associated with unknown accounts
        $Deletethese = $onharddrive | Where-Object {$_.SID -in $unknownAccounts.SID}

        #Delete and display progress bar
        for ($i = 0; $i -lt $Deletethese.Count; $i++) {
            try {
                $Percentage = ($i + 1) / $Deletethese.Count * 100
                Write-Progress -Activity "Deleting User Profiles..." -Status "Deleting Profile #$($i+1)/$($Deletethese.Count)" -PercentComplete $Percentage
                $Deletethese[$i] | Remove-CimInstance -Verbose -ErrorAction -Stop
                Write-Progress -Activity "Deleting Profiles" -Completed
            }

            catch {
                $_.Exception.Message
            }
        }
    }

    else {
        exit
    }

    ## ask user if they would like to restart the machine
    $uInput = Read-Host "Script completed... Do you wish to restart the device?(y/n)" -BackgroundColor Black -ForegroundColor Green

    if($uInput.ToUpper() -eq 'Y') {
        Write-Host "Restarting Device in 10 Seconds"
        Start-Sleep -Seconds 10 
        Restart-Computer -Force
    } 
    else {
        #display amount of disk space free in gigabytes
        $diskspacefree = Get-PSDrive C | Select Free
        Write-Host "Successfully removed all Unknown Accounts... The amount of space free is now "$diskspacefree.Free"" -BackgroundColor Black -ForegroundColor Green
        Start-Sleep -Seconds 30 
        exit
    }
   
}
catch {
    $errormessage1
    Write-Host "Stopping script in 30 seconds" -BackgroundColor Black -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    exit
}

