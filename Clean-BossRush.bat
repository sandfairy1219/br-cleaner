@echo off
chcp 65001 >nul
title Boss Rush practice cleanup
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Clean-BossRush.ps1" %*
pause
