$server = "cyber-rangers-sql-w3oco5ybgchjc.database.windows.net"

For ($i=0; $i -le 20000; $i++) {
    sqlcmd.exe -S $server -U sa -P $(Get-Random) -d sqldb
    }