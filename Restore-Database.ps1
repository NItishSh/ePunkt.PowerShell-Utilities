[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null 
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended') | out-null

function Restore-Database {
    param($servername, $backupFile, $newDatabaseName)

    Write-Host "Connecting to server ..."
    $connection = New-Object("Microsoft.SqlServer.Management.Common.ServerConnection") $servername
    $connection.StatementTimeout = 0 
    $server = New-Object("Microsoft.SqlServer.Management.Smo.Server") $connection 
    $dbRestore = New-Object("Microsoft.SqlServer.Management.Smo.Restore")

    Write-Host "Preparing the restore ..."

    #settings for the restore 
    $dbRestore.Action = "Database" 
    $dbRestore.NoRecovery = $false; 
    $dbRestore.ReplaceDatabase = $true; 
    $dbRestorePercentCompleteNotification = 5; 
    $dbRestore.Devices.AddDevice($backupFile, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

    $dbRestore.Database = $newDatabaseName

    Write-Host "Configuring logical files..."

    $data_files = $dbRestore.ReadFileList($server)
    ForEach ($data_row in $data_files) {
        $logical_name = $data_row.LogicalName

        $restore_data = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
        $restore_data.LogicalFileName = $logical_name

        if ($data_row.Type -eq "D") {
            $restore_data.PhysicalFileName = $server.Information.MasterDBPath + "\" + $dbRestore.Database + ".mdf"
        }
        else {
            $restore_data.PhysicalFileName = $server.Information.MasterDBLogPath + "\" + $dbRestore.Database + ".ldf"
        }

        [Void]$dbRestore.RelocateFiles.Add($restore_data)
    }

    #execute the restore! 
    Write-Host "Restoring to $newDatabaseName ..."
    try {
        $dbRestore.SqlRestore($server) 
        Write-Host "Restore suceeded."
    }
    catch {
        Write-Host "Restore failed:"$_.Exception.ToString()
    }
}

function Get-Latest-BackupFile-From-Directory {
    param($directory)

    return gci $directory | sort LastWriteTime | select -last 1
}

function Add-WindowsUser-To-Database {
    param($serverName, $databaseName, $userName)

    $server = New-Object ("Microsoft.SqlServer.Management.SMO.Server") $serverName
    $database = $server.Databases[$databaseName]
    $user = $database.Users[$userName]

    if (!($user)) {
        Write-Host "Creating the user ..."
        $user = New-Object ("Microsoft.SqlServer.Management.SMO.User") ($database, $userName)
        $user.Login = $userName
        $user.Create()
    }

    Write-Host "Granting the user db_owner rights ..."
    $role = $database.Roles["db_owner"]
    $role.AddMember($userName)
}