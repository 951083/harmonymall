@echo off
chcp 65001 >nul
title HarmonyMall 模拟器联调 - 端口转发
echo ====================================================
echo   HarmonyMall 模拟器联调：建立端口反向转发
echo ====================================================
echo.
"D:\devecostudio-windows-6.1.1.290\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe" rport tcp:8080 tcp:8080
echo.
echo [完成] 模拟器里的应用现在可以通过 http://127.0.0.1:8080 访问电脑上的后端。
echo [注意] 每次模拟器重启后，需要重新双击运行本脚本一次。
echo.
pause
