#Requires -RunAsAdministrator
# Almi-Chain · ALMI-GERENTE: usuario Gerente y carpeta privada (guía 2.4)
# Ejecutar con almiadmin en PowerShell como administrador, DESPUÉS de 1-seguridad.ps1:
#   Set-ExecutionPolicy -Scope Process Bypass; .\2-usuarios-gerente.ps1
# Grupos por SID: S-1-5-32-545 = Usuarios, S-1-5-32-544 = Administradores, S-1-5-18 = SYSTEM
$ErrorActionPreference = "Stop"

if (-not (Get-LocalUser -Name "Gerente" -ErrorAction SilentlyContinue)) {
    do {
        $p = Read-Host -AsSecureString "Contraseña para Gerente (mínimo 12 caracteres)"
        if ($p.Length -lt 12) { Write-Host "Demasiado corta." }
    } until ($p.Length -ge 12)
    # Si no cumple la complejidad de Windows, New-LocalUser da error y el script se para
    New-LocalUser -Name "Gerente" -Password $p -FullName "Gerente Almi-Chain" -Description "Despacho del gerente"
}
if (-not (Get-LocalGroupMember -SID "S-1-5-32-545" | Where-Object { $_.Name -like "*\Gerente" })) {
    Add-LocalGroupMember -SID "S-1-5-32-545" -Member "Gerente"
}

# Carpeta privada: solo Administradores, SYSTEM y Gerente
New-Item -ItemType Directory -Path C:\Gerencia -Force | Out-Null
icacls C:\Gerencia /inheritance:r /grant:r "*S-1-5-32-544:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" "Gerente:(OI)(CI)M" | Out-Null
if ($LASTEXITCODE -ne 0) { throw "icacls ha fallado" }
icacls C:\Gerencia

Get-LocalUser | Format-Table Name, Enabled, Description
Get-LocalGroupMember -SID "S-1-5-32-544"
