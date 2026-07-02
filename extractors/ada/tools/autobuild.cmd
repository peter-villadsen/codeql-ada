@echo off
python "%CODEQL_EXTRACTOR_ADA_ROOT%\tools\spike_extractor.py"
exit /b %ERRORLEVEL%
