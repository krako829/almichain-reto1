#Requires -RunAsAdministrator
# Almi-Chain · Confiar en el certificado HTTPS de Odoo (guía 6.4, paso 4)
# Ejecutar con almiadmin en PowerShell como administrador, en ALMI-GERENTE y en ALMI-TPV.
#
# Descarga SOLO la parte pública del certificado (nginx la publica en http://192.168.10.30/almichain-odoo.crt),
# comprueba su huella SHA-256 con la que se apuntó en el servidor y, si coincide, la instala.
# No hace falta SSH ni la contraseña de almiadmin del servidor (desde la VLAN de los TPV el 22 está cerrado).
#
# Huella en el servidor:  sudo openssl x509 -in /etc/ssl/almichain/odoo.crt -noout -fingerprint -sha256
$ErrorActionPreference = 'Stop'
$url  = 'http://192.168.10.30/almichain-odoo.crt'
$file = Join-Path $env:TEMP 'almichain-odoo.crt'

Invoke-WebRequest -Uri $url -OutFile $file -UseBasicParsing
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList $file

# Huella SHA-256 del certificado (la misma que da openssl -fingerprint -sha256)
$sha    = [System.Security.Cryptography.SHA256]::Create()
$huella = ($sha.ComputeHash($cert.RawData) | ForEach-Object { $_.ToString('X2') }) -join ''

Write-Host "Certificado descargado: $($cert.Subject)"
Write-Host "Válido hasta:           $($cert.NotAfter)"
Write-Host "Huella SHA-256:         $huella"
$esperada = (Read-Host 'Escribe la huella SHA-256 que se ve en el servidor (con o sin los dos puntos)') -replace '[^0-9A-Fa-f]', ''

if ($esperada.ToUpper() -ne $huella) {
    Remove-Item $file
    throw 'La huella NO coincide: el certificado no se instala. Comprueba que estás en la red del restaurante y repite.'
}

# Que sea un certificado de servidor y no de autoridad (CA:FALSE): así solo vale para Odoo
$bc = $cert.Extensions | Where-Object { $_ -is [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension] }
if ($bc -and $bc.CertificateAuthority) {
    Remove-Item $file
    throw 'El certificado es de autoridad (CA:TRUE). No se instala: genera en el servidor uno de servidor (README de Odoo, apartado 3).'
}

Import-Certificate -FilePath $file -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
Remove-Item $file
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like '*Almi-Chain*' | Format-List Subject, NotAfter, Thumbprint
Write-Host 'Instalado. Abre https://192.168.10.30 en Edge: tiene que salir el candado sin avisos.'
