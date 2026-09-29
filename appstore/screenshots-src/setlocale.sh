#!/bin/zsh
# Switches a simulator's system language/region (so the status bar clock and date match the
# screenshot's locale), reboots it and reapplies the clean status bar.
# usage: setlocale.sh <udid> <en|es|fr>
U=$1; L=$2
case $L in
  en) LOC=en_US ;;
  es) LOC=es_MX ;;
  fr) LOC=fr_FR ;;
  *)  LOC=$L ;;
esac
HERE=${0:A:h}
xcrun simctl boot $U 2>/dev/null
xcrun simctl bootstatus $U -b >/dev/null
xcrun simctl spawn $U defaults write -g AppleLanguages -array $L
xcrun simctl spawn $U defaults write -g AppleLocale $LOC
# iPad: full-screen apps, so no window resize grip in the corner.
xcrun simctl spawn $U defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO
xcrun simctl shutdown $U
$HERE/statusbar.sh $U
