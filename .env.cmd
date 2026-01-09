@echo off
rem ---- snapshot (only if not already active) ----
if not defined _AUTO_VENV_ROOT (
  set "_AUTO_VENV_OLD_PATH=%PATH%"
  set "_AUTO_VENV_OLD_PROMPT=%PROMPT%"
)

rem ---- mark the directory where venv should remain active ----
set "_AUTO_VENV_ROOT=%CD%"

rem ---- "activate" (minimal + deterministic) ----
set "VIRTUAL_ENV=%CD%\.venv"
set "PATH=%VIRTUAL_ENV%\Scripts;%PATH%"
REM set "PROMPT=(venv) %PROMPT%"
