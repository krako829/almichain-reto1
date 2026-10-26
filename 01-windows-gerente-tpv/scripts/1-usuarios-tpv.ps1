# Almi-Chain · ALMI-TPV: usuarios TPV1 y TPV2 (guía 2.4)
# Ejecutar con almiadmin en PowerShell como administrador
$ErrorActionPreference = "Stop"
foreach ($u in @("TPV1", "TPV2")) {
    if (-not (Get-LocalUser -Name $u -ErrorAction SilentlyContinue)) {
        $p = Read-Host -AsSecureString "Contraseña para $u (mínimo 12 caracteres)"
        $n = $u.Substring(3)
        New-LocalUser -Name $u -Password $p -FullName "TPV Barra $n" -Description "Equipo de barra $n" `
            -UserMayNotChangePassword -PasswordNeverExpires
    }
    Add-LocalGroupMember -Group "Usuarios" -Member $u -ErrorAction SilentlyContinue
}
Get-LocalUser | Format-Table Name, Enabled, Description
Get-LocalGroupMember -Group "Administradores"
