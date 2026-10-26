# Almi-Chain · Comprobaciones de ALMI-TPV (guía 2.9 y 6.14)
Get-LocalGroupMember -Group "Administradores"
Get-Printer | Format-Table Name, DriverName, PortName
Test-NetConnection 192.168.10.30 -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded
Test-NetConnection 192.168.10.30 -Port 8069 | Select-Object ComputerName, RemotePort, TcpTestSucceeded
