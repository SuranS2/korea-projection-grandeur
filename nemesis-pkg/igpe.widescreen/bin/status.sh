#!/system/bin/sh
# NEMESIS Manager > Grandeur IG Widescreen > Launch:
# USB 맨 위의 kp-wide-off / kp-wide-on 처리 및 현재 와이드스크린/유선 설정 상태 출력
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
APP=${APP:-/data/nemesis/apps/igpe.widescreen}
BK=${BK:-/data/nemesis/backup/igpe.widescreen}
USBS=${USBS:-"/storage/usb0 /storage/usb1"}
MOUNTS=${MOUNTS:-/proc/mounts}
umask 077

WIDESCREEN_LIB=1 . "$APP/svc/widescreen.sh"
prod=$(getprop ro.build.product 2>/dev/null)

_wo=0; _won=0
for _u in $USBS; do
  grep -q " $_u " "$MOUNTS" 2>/dev/null || continue
  [ -f "$_u/kp-wide-off" ] && _wo=1
  [ -f "$_u/kp-wide-on" ] && _won=1
done

_wmsg=
if [ $_wo = 1 ] || [ $_won = 1 ]; then
  if wide_supported || { [ ! -L "$SYSORIG" ] && [ -d "$SYSORIG" ]; } || { [ ! -L "$WIDEOFF" ] && [ -f "$WIDEOFF" ]; }; then
    if [ $_wo = 1 ]; then
      [ "${WIDEOFF%/*}" != "$WIDEOFF" ] && [ -n "${WIDEOFF%/*}" ] && mkdir -p "${WIDEOFF%/*}" 2>/dev/null
      [ -L "$WIDEOFF" ] && rm -f "$WIDEOFF"
      : > "$WIDEOFF"
      if wide_restore; then _wmsg="와이드스크린(1920x720) 끔"
      else _wmsg="와이드스크린(1920x720) 끔(일부 설정 되돌리지 못함)"; fi
    elif [ $_won = 1 ]; then
      rm -f "$WIDEOFF"
      if wide_apply; then _wmsg="와이드스크린(1920x720) 켬"
      else _wmsg="와이드스크린(1920x720) 켬(일부 설정 적용 실패)"; fi
    fi
  else
    _wmsg="지원 대상 차종/빌드($CARS_WIDE)가 아닙니다"
  fi
fi

_cp=$(sys_get carplay_ss_osd 2>/dev/null)
_aa=$(sys_get androidauto_ss_osd 2>/dev/null)
_cai=$(sys_get carplay_information 2>/dev/null)
_aai=$(sys_get androidauto_information 2>/dev/null)
_ds=$(getprop ro.device.splitscreen 2>/dev/null)

if ! car_in "$prod" "$CARS_WIDE"; then
  _st="비대상 ($prod)"
elif [ ! -L "$WIDEOFF" ] && [ -f "$WIDEOFF" ]; then
  _st="꺼짐 (kp-wide-off)"
elif wide_supported; then
  _st="켜짐 (1920x720)"
else
  _st="대기 (splitscreen=${_ds:-없음})"
fi

echo "Grandeur IG Widescreen: $_st"
[ -n "$_wmsg" ] && echo "- 변경: $_wmsg"
echo "- carplay_ss_osd=${_cp:-?}, androidauto_ss_osd=${_aa:-?}"
echo "- carplay_information=${_cai:-?}, androidauto_information=${_aai:-?}"
exit 0
