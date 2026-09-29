#!/bin/zsh
# Boots a simulator (if needed) and sets the clean App Store status bar.
# usage: statusbar.sh <udid>
U=$1
xcrun simctl boot $U 2>/dev/null
xcrun simctl bootstatus $U -b >/dev/null
xcrun simctl status_bar $U override --time 9:41 --batteryState discharging --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 --dataNetwork wifi --operatorName ""
