# Almi-Chain · Confiar en el certificado HTTPS de Odoo (guía 6.4, paso 4)
# Ejecutar con almiadmin en PowerShell como administrador, en ALMI-GERENTE y en ALMI-TPV
$cert = "$env:USERPROFILE\Desktop\odoo.crt"
scp almiadmin@192.168.10.30:/etc/ssl/almichain/odoo.crt $cert
Import-Certificate -FilePath $cert -CertStoreLocation Cert:\LocalMachine\Root
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like "*Almi-Chain*" | Format-List Subject, NotAfter, Thumbprint
