#!/bin/zsh
# Captures every raw screen the set needs, from the DEBUG build, through the QA harness.
# usage: capture.sh <iphone|ipad> <lang>        (lang: en | es | fr | any app language code)
# Output: raw/<device>/<lang>/<scene>.png
# Simulators: IPHONE_UDID / IPAD_UDID (defaults below). The Debug app must already be installed
# (make.sh does that).
HERE=${0:A:h}
DEVICE=$1; L=$2
IPHONE_UDID=${IPHONE_UDID:-DD0DB49F-B8B1-4679-9D6E-8002E6423CD8}
IPAD_UDID=${IPAD_UDID:-665EC18A-3C90-483E-A4C8-50AA2DDFA7A7}
if [[ $DEVICE == ipad ]]; then U=$IPAD_UDID; else U=$IPHONE_UDID; fi
OUT=$HERE/raw/$DEVICE/$L
mkdir -p $OUT

# The iPad status bar shows the date, so the whole simulator follows the language.
if [[ $DEVICE == ipad ]]; then $HERE/setlocale.sh $U $L; else $HERE/statusbar.sh $U; fi

S=$HERE/shot.sh
W=${WAIT:-6}
$S $U $L dark  $OUT/home.png      $W -qaSeed YES -qaScreen home
$S $U $L dark  $OUT/danger.png    $W -qaSeed YES -qaLargeSheet YES -qaScreen result:danger
$S $U $L light $OUT/wifi.png      $W -qaSeed YES -qaLargeSheet YES -qaScreen result:wifi
$S $U $L light $OUT/travel.png    $W -qaSeed YES -qaLargeSheet YES -qaScreen result:travel
$S $U $L light $OUT/contact.png   $W -qaSeed YES -qaLargeSheet YES -qaScreen result:contact
$S $U $L light $OUT/show.png      $W -qaSeed YES -qaScreen show:wifi
$S $U $L light $OUT/studio.png    $W -qaSeed YES -qaScreen studio -qaPreset lagoon -qaLogo YES
$S $U $L light $OUT/everywhere.png $W -qaOnboarding everywhere
$S $U $L light $OUT/history.png   $W -qaSeed YES -qaScreen history
$S $U $L dark  $OUT/privacy.png   $W -qaSeed YES -qaScreen privacy
xcrun simctl terminate $U com.rvp97.scanner >/dev/null 2>&1
ls $OUT
