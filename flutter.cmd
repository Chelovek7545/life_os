@echo off
setlocal
set "PUB_CACHE=%~dp0.tools\pub-cache"
call "%~dp0.tools\flutter\bin\flutter.bat" %*
exit /b %errorlevel%
