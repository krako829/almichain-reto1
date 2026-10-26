# Almi-Chain · Seguridad general de los dos Windows (guía 2.4 y 2.5)
# Ejecutar con almiadmin en PowerShell como administrador, en ALMI-GERENTE y en ALMI-TPV
$ErrorActionPreference = "Continue"

# Invitado desactivado
Disable-LocalUser -Name "Invitado" -ErrorAction SilentlyContinue

# Contraseñas: 12 caracteres, caducan a los 90 días; bloqueo de 15 minutos tras 5 fallos
net accounts /minpwlen:12 /maxpwage:90 /lockoutthreshold:5 /lockoutduration:15 /lockoutwindow:15

# Complejidad de contraseñas (equivale a secpol.msc → Directiva de contraseñas)
secedit /export /cfg $env:TEMP\sec.inf /areas SECURITYPOLICY | Out-Null
(Get-Content $env:TEMP\sec.inf) -replace 'PasswordComplexity = 0', 'PasswordComplexity = 1' | Set-Content $env:TEMP\sec.inf
secedit /configure /db $env:windir\security\local.sdb /cfg $env:TEMP\sec.inf /areas SECURITYPOLICY | Out-Null

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

# Sin reproducción automática en ninguna unidad
$exp = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
New-Item $exp -Force | Out-Null
Set-ItemProperty $exp -Name NoDriveTypeAutoRun -Value 255 -Type DWord

# Solo en el equipo del gerente: bloqueo de pantalla a los 5 minutos
if ($env:COMPUTERNAME -eq "ALMI-GERENTE") {
    Set-ItemProperty $uac -Name InactivityTimeoutSecs -Value 300 -Type DWord
}

gpupdate /force | Out-Null

# Comprobación (captura de esta salida para la documentación)
net accounts
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureLastUpdated
Get-NetFirewallProfile | Format-Table Name, Enabled
Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol | Select-Object FeatureName, State
