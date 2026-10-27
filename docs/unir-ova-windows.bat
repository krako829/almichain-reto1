@echo off
setlocal enabledelayedexpansion
rem Almi-Chain: une los trozos de las .ova (si vienen partidas) y comprueba la huella de TODAS.
rem Doble clic en la carpeta donde estan los trozos y los .sha256.
set MAL=0
for %%N in (ALMI-ARCADE ALMI-BD ALMI-ODOO) do (
  if exist %%N.ova.sha256 (
    if exist %%N.ova.parte1 (
      echo Uniendo %%N.ova ...
      set LISTA=%%N.ova.parte1
      for %%I in (2 3 4 5 6 7 8 9) do (
        if exist %%N.ova.parte%%I set LISTA=!LISTA!+%%N.ova.parte%%I
      )
      copy /b !LISTA! %%N.ova >nul
    )
    if exist %%N.ova (
      powershell -NoProfile -Command "$e=((Get-Content '%%N.ova.sha256') -split '\s+')[0]; $h=(Get-FileHash '%%N.ova' -Algorithm SHA256).Hash; if ($h -ieq $e) { Write-Host '%%N.ova: OK' } else { Write-Host '%%N.ova: HUELLA DISTINTA, vuelve a descargarla'; exit 1 }"
      if errorlevel 1 set MAL=1
    ) else (
      echo FALTA %%N.ova
      set MAL=1
    )
  )
)
echo.
if "%MAL%"=="0" (
  echo Todo correcto: ya puedes importar las .ova en VirtualBox y borrar los archivos .parte
) else (
  echo Hay algun archivo mal: no lo importes.
)
pause
