#Requires -RunAsAdministrator
# Almi-Chain · ALMI-TPV: usuarios TPV1 y TPV2 (guía 2.4)
# Ejecutar con almiadmin en PowerShell como administrador, DESPUÉS de 1-seguridad.ps1.
# TPV1 y TPV2 son cuentas de quiosco: no pueden cambiar su contraseña y no caduca
# (si caducara, la barra se quedaría bloqueada en mitad del servicio). La cambia almiadmin.
$ErrorActionPreference = "Stop"
foreach ($u in @("TPV1", "TPV2")) {
    if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) {
        do {
            $p = Read-Host -AsSecureString "Contraseña para $u (mínimo 12 caracteres)"
            if ($p.Length -lt 12) { Write-Host "Demasiado corta." }
        } until ($p.Length -ge 12)
        $n = $u.Substring(3)
        New-LocalUser -Name $u -Password $p -FullName "TPV Barra $n" -Description "Equipo de barra $n" `
            -UserMayNotChangePassword -PasswordNeverExpires
    }
    if (-not (Get-LocalGroupMember -SID "S-1-5-32-545" | Where-Object { $_.Name -like "*\$u" })) {
        Add-LocalGroupMember -SID "S-1-5-32-545" -Member $u
    }
}
Get-LocalUser | Format-Table Name, Enabled, Description, PasswordExpires
Get-LocalGroupMember -SID "S-1-5-32-544"
