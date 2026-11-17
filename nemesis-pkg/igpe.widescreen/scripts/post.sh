#!/system/bin/sh
# postinstall: 그랜저 IG (IGPE.KOR.*.260902) 1920x720 와이드스크린 적용/토글 및 유선 설정 보호
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
APP=${APP:-/data/nemesis/apps/igpe.widescreen}
BK=${BK:-/data/nemesis/backup/igpe.widescreen}
umask 077
mkdir -p "$BK" 2>/dev/null
WIDESCREEN_LIB=1 . "$APP/svc/widescreen.sh"

if wide_supported || { [ ! -L "$SYSORIG" ] && [ -d "$SYSORIG" ]; } || { [ ! -L "$WIDEOFF" ] && [ -f "$WIDEOFF" ]; }; then
  USBS=${USBS:-"/storage/usb0 /storage/usb1"}
  _wo=0; _won=0
  for _u in $USBS; do
    [ -f "$_u/kp-wide-off" ] && _wo=1
    [ -f "$_u/kp-wide-on" ] && _won=1
  done
  if [ $_wo = 1 ]; then
    [ "${WIDEOFF%/*}" != "$WIDEOFF" ] && [ -n "${WIDEOFF%/*}" ] && mkdir -p "${WIDEOFF%/*}" 2>/dev/null
    [ -L "$WIDEOFF" ] && rm -f "$WIDEOFF"
    : > "$WIDEOFF"; echo "와이드스크린(1920x720) 끔"
  elif [ $_won = 1 ]; then
    rm -f "$WIDEOFF"; echo "와이드스크린(1920x720) 켬"
  fi
  if [ ! -L "$WIDEOFF" ] && [ -f "$WIDEOFF" ]; then
    wide_restore || echo "와이드스크린 설정 되돌리기 건너뜀"
  else
    wide_apply || echo "와이드스크린 설정 적용 건너뜀(서비스 시작 후 다시 시도)"
  fi
fi
usb_guard || echo "유선 프로젝션 설정 보호 건너뜀(서비스 시작 후 다시 시도)"
exit 0
