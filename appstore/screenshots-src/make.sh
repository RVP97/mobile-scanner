#!/bin/zsh
# One command for the whole set: build the Debug app, install it on both simulators, capture
# every screen in each locale's app language, and compose the App Store PNGs.
#
#   ./make.sh                    every locale in strings.json
#   ./make.sh en-US es-MX        just these
#   SKIP_BUILD=1 ./make.sh ...   reuse the last build
#   SKIP_CAPTURE=1 ./make.sh ... re-render from the existing raw captures only
#   DEVICES=ipad ./make.sh ...   capture only these devices (iphone, ipad)
set -e
HERE=${0:A:h}
REPO=${HERE:h:h}
IPHONE_UDID=${IPHONE_UDID:-DD0DB49F-B8B1-4679-9D6E-8002E6423CD8}
IPAD_UDID=${IPAD_UDID:-665EC18A-3C90-483E-A4C8-50AA2DDFA7A7}
DEVICES=(${=DEVICES:-iphone ipad})
export IPHONE_UDID IPAD_UDID

LOCALES=("$@")
if (( ${#LOCALES} == 0 )); then
  LOCALES=(${(f)"$(node -e 'console.log(Object.keys(require(process.argv[1])).filter(k=>!k.startsWith("_")).join("\n"))' $HERE/strings.json)"})
fi

if [[ -z $SKIP_CAPTURE ]]; then
  APP=$REPO/Lens/build/dd-screenshots/Build/Products/Debug-iphonesimulator/Lens.app
  if [[ -z $SKIP_BUILD ]]; then
    (cd $REPO/Lens && xcodegen generate >/dev/null && xcodebuild -project Lens.xcodeproj -scheme Lens \
      -destination 'generic/platform=iOS Simulator' -derivedDataPath build/dd-screenshots \
      CODE_SIGNING_ALLOWED=NO build | tail -1)
  fi
  for U in $IPHONE_UDID $IPAD_UDID; do
    $HERE/statusbar.sh $U
    xcrun simctl install $U $APP
  done
  # Each app language is captured once, even when several store locales share it.
  typeset -A done_langs
  for LOCALE in $LOCALES; do
    L=$(node -e 'console.log(require(process.argv[1])[process.argv[2]].app)' $HERE/strings.json $LOCALE)
    [[ -n ${done_langs[$L]} ]] && continue
    done_langs[$L]=1
    for D in $DEVICES; do $HERE/capture.sh $D $L >/dev/null; done
    echo "captured $L"
  done
fi

node $HERE/render.mjs $LOCALES
