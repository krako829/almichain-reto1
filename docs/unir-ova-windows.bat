@echo off
setlocal enabledelayedexpansion
rem Almi-Chain: une los trozos de las .ova. Doble clic en la carpeta donde estan los trozos.
for %%N in (ALMI-ARCADE ALMI-BD ALMI-ODOO) do (
  if exist %%N.ova.parte1 (
    echo Uniendo %%N.ova ...
    set LISTA=%%N.ova.parte1
    for %%I in (2 3 4 5 6 7 8) do (
      if exist %%N.ova.parte%%I set LISTA=!LISTA!+%%N.ova.parte%%I
    )
    copy /b !LISTA! %%N.ova >nul
    echo Huella calculada:
    certutil -hashfile %%N.ova SHA256 | findstr /v ":"
    echo Huella esperada:
    type %%N.ova.sha256
    echo.
  )
)
echo Si las dos huellas de cada archivo coinciden, ya puedes importar la .ova en VirtualBox
echo y borrar los archivos .parte
pause
