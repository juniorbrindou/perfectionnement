@echo off
rem Capture d'ecran du telephone dans build\captures.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\telephone.ps1" capture %*

