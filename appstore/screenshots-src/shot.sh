#!/bin/zsh
# Captures one real app screen through the DEBUG QA harness.
# usage: shot.sh <udid> <lang> <appearance> <out.png> <delay> <launch args...>
#   lang: en | es | fr (passed as -AppleLanguages / -AppleLocale)
U=$1; L=$2; A=$3; OUT=$4; DELAY=$5; shift 5
case $L in
  en) LOC=en_US ;;
  es) LOC=es_MX ;;
  fr) LOC=fr_FR ;;
  *)  LOC=$L ;;
esac
xcrun simctl terminate $U com.rvp97.scanner >/dev/null 2>&1
xcrun simctl launch $U com.rvp97.scanner -AppleLanguages "($L)" -AppleLocale $LOC \
  -qaAppearance $A "$@" >/dev/null
sleep $DELAY
mkdir -p ${OUT:h}
xcrun simctl io $U screenshot --type=png $OUT >/dev/null 2>&1
echo $OUT
