@echo off
rem Affiche le journal du jeu en direct (Ctrl+C pour arreter).
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\telephone.ps1" logs %*

