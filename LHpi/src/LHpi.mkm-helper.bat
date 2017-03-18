@echo off
echo Batch file to call LHpi.mkm-helper.lua
cd /D D:\Magic - The Gathering\Magic Album\Prices
lib\bin\lua53.exe LHpi.mkm-helper.lua %* download standard MM3 "Zendikar Expeditions" REL PRE 26 FNM 50 52 53 all
