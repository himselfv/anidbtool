@echo off
chcp 65001
"%~dp0anidb" mylistadd /s /state hdd %*
pause >nul