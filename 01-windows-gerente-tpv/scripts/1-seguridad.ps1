#Requires -RunAsAdministrator
# Almi-Chain · Seguridad general de los dos Windows (guía 2.4 y 2.5)
# Ejecutar con almiadmin en PowerShell como administrador, en ALMI-GERENTE y en ALMI-TPV,
# ANTES de crear los usuarios (2-usuarios-*.ps1): Windows comprueba la directiva de
# contraseñas al crear o cambiar una contraseña, no después.
#   Set-ExecutionPolicy -Scope Process Bypass; .\1-seguridad.ps1
# Los grupos y cuentas se buscan por su SID: funciona igual con Windows en español o en inglés.
$ErrorActionPreference = "Stop"

# Invitado desactivado (la cuenta integrada de invitado siempre acaba en -501)
Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-21-*-501' } | Disable-LocalUser

# Contraseñas: 12 caracteres, caducan a los 90 días; bloqueo de 15 minutos tras 5 fallos
net accounts /minpwlen:12 /maxpwage:90 /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15
if ($LASTEXITCODE -ne 0) { throw "net accounts ha fallado" }

# Complejidad de contraseñas (equivale a secpol.msc → Directiva de contraseñas)
$inf = Join-Path $env:TEMP 'almichain-sec.inf'
secedit /export /cfg $inf /areas SECURITYPOLICY | Out-Null
if ($LASTEXITCODE -ne 0) { throw "secedit /export ha fallado" }
(Get-Content $inf) -replace 'PasswordComplexity = 0', 'PasswordComplexity = 1' | Set-Content $inf -Encoding Unicode
secedit /configure /db $env:windir\security\local.sdb /cfg $inf /areas SECURITYPOLICY | Out-Null
if ($LASTEXITCODE -ne 0) { throw "secedit /configure ha fallado" }
Remove-Item $inf

# UAC al máximo: "Notificarme siempre" y pedir credenciales a los usuarios estándar
$uac = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty $uac -Name ConsentPromptBehaviorAdmin -Value 2
Set-ItemProperty $uac -Name ConsentPromptBehaviorUser -Value 1
Set-ItemProperty $uac -Name PromptOnSecureDesktop -Value 1

# Antivirus y cortafuegos activos
Set-MpPreference -DisableRealtimeMonitoring $false
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True

# Sin SMBv1 y sin Escritorio remoto
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart | Out-Null
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1

# Sin reproducción automática en ninguna unidad (la clave se crea solo si no existe, para no borrar lo que tenga)
$exp = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
if (-not (Test-Path $exp)) { New-Item $exp | Out-Null }
Set-ItemProperty $exp -Name NoDriveTypeAutoRun -Value 255 -Type DWord

# Solo en el equipo del gerente: bloqueo de pantalla a los 5 minutos
if ($env:COMPUTERNAME -eq "ALMI-GERENTE") {
    Set-ItemProperty $uac -Name InactivityTimeoutSecs -Value 300 -Type DWord
}

gpupdate /force | Out-Null

# Comprobación (captura de esta salida para la documentación)
net accounts
secedit /export /cfg $inf /areas SECURITYPOLICY | Out-Null
Select-String -Path $inf -Pattern 'PasswordComplexity'
Remove-Item $inf
Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-21-*-501' } | Format-Table Name, Enabled
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated
Get-NetFirewallProfile | Format-Table Name, Enabled
Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select-Object FeatureName, State
