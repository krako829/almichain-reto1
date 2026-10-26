# Almi-Chain · ALMI-GERENTE: usuario Gerente y carpeta privada (guía 2.4)
# Ejecutar con almiadmin en PowerShell como administrador:
#   Set-ExecutionPolicy -Scope Process Bypass; .\1-usuarios-gerente.ps1
$ErrorActionPreference = "Stop"

$p = Read-Host -AsSecureString "Contraseña para Gerente (mínimo 12 caracteres)"
if (-not (Get-LocalUser -Name "Gerente" -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name "Gerente" -Password $p -FullName "Gerente Almi-Chain" -Description "Despacho del gerente"
}
Add-LocalGroupMember -Group "Usuarios" -Member "Gerente" -ErrorAction SilentlyContinue

# Carpeta privada: solo Administradores, SYSTEM y Gerente
New-Item -ItemType Directory -Path C:\Gerencia -Force | Out-Null
icacls C:\Gerencia /inheritance:r /grant:r "Administradores:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Gerente:(OI)(CI)M" | Out-Null
icacls C:\Gerencia

Get-LocalUser | Format-Table Name, Enabled, Description
Get-LocalGroupMember -Group "Administradores"
