@echo off
chcp 65001
"%~dp0anidb" mylistadd /s /state hdd /-usecachedhashes /-ignoreunchangedfiles %*
pause >nul