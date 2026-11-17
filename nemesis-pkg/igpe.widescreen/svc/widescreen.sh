#!/system/bin/sh
# igpe.widescreen: 더 뉴 그랜저 IG (IGPE.KOR.*.260902) 전용 1920x720 와이드스크린 & 유선 USB 설정 보호.
# 무선 핫스팟(hostapd/dnsmasq), Wi-Fi 잠금, HMG-API 무선 모드는 전혀 건드리지 않으며 busybox 없이 동작한다.
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin

APP=${APP:-/data/nemesis/apps/igpe.widescreen}
BK=${BK:-/data/nemesis/backup/igpe.widescreen}
CARS_WIDE=${CARS_WIDE:-'IGPE.KOR.*.260902'}
WIDEOFF=${WIDEOFF:-$BK/wide-off}
SYSORIG=${SYSORIG:-$BK/sys.orig}

car_in() {
  _cr=1; _ci=$IFS; IFS=' '
  case $- in *f*) _cf=0 ;; *) _cf=1; set -f ;; esac
  for _ck in $2; do case "$1" in $_ck) _cr=0; break ;; esac; done
  [ $_cf = 1 ] && set +f
  IFS=$_ci
  return $_cr
}

log() { echo "$(date '+%m-%d %H:%M:%S') $*"; }

wide_supported() {
  _ws_prod=${prod:-$(getprop ro.build.product 2>/dev/null)}
  car_in "$_ws_prod" "$CARS_WIDE" || return 1
  case "$(getprop ro.device.splitscreen 2>/dev/null)" in ''|0|disable) return 1 ;; esac
  return 0
}

usb_guard_supported() {
  _ugs_prod=${prod:-$(getprop ro.build.product 2>/dev/null)}
  car_in "$_ugs_prod" "$CARS_WIDE"
}

sys_get() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  command -v settings >/dev/null 2>&1 || return 1
  _sg_out=$(settings get system "$1" 2>/dev/null) || return 1
  case $- in *f*) _sg_f=0 ;; *) _sg_f=1; set -f ;; esac
  set -- $_sg_out
  if [ $_sg_f = 1 ]; then set +f; fi
  [ $# -eq 1 ] || return 1
  case "$1" in
    null) echo null; return 0 ;;
    *)
      case "${1#-}" in ''|*[!0-9]*) return 1 ;; esac
      echo "$1"; return 0 ;;
  esac
}

sys_put() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  case "${2#-}" in ''|*[!0-9]*) return 1 ;; esac
  command -v settings >/dev/null 2>&1 || return 1
  settings put system "$1" "$2" >/dev/null 2>&1 || return 1
  _sp_rb=$(sys_get "$1") || return 1
  [ "$_sp_rb" = "$2" ]
}

sys_del() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  command -v content >/dev/null 2>&1 || return 1
  command -v settings >/dev/null 2>&1 || return 1
  content delete --uri content://settings/system --where "name='$1'" >/dev/null 2>&1 || return 1
  _sd_rb=$(sys_get "$1") || return 1
  [ "$_sd_rb" = null ]
}

sys_guard_set() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  case "${2#-}" in ''|*[!0-9]*) return 1 ;; esac
  if [ -L "$SYSORIG" ] || { [ -e "$SYSORIG" ] && [ ! -d "$SYSORIG" ]; }; then
    log "시스템 설정 백업 폴더가 올바르지 않아 건너뜀: $SYSORIG"
    return 1
  fi
  _sgs_f="$SYSORIG/$1"
  if [ -L "$_sgs_f" ] || { [ -e "$_sgs_f" ] && [ ! -f "$_sgs_f" ]; }; then
    log "시스템 설정 백업 파일이 올바르지 않아 건너뜀: $1"
    return 1
  fi
  if ! command -v settings >/dev/null 2>&1; then
    log "시스템 설정($1) 맞추기 건너뜀: settings 명령 없음"
    return 1
  fi
  _sgs_cur=$(sys_get "$1") || { log "시스템 설정($1) 값을 읽지 못함"; return 1; }
  if [ -f "$_sgs_f" ]; then
    _sgs_orig=; _sgs_prev=
    read _sgs_orig _sgs_prev < "$_sgs_f"
    case "$_sgs_orig" in
      null) ;;
      *) case "${_sgs_orig#-}" in ''|*[!0-9]*) _sgs_orig=$_sgs_cur ;; esac ;;
    esac
  else
    _sgs_orig=$_sgs_cur
  fi
  if [ "$_sgs_cur" = "$2" ]; then
    if [ -f "$_sgs_f" ] && [ "$_sgs_prev" != "$2" ]; then
      echo "$_sgs_orig $2" > "$_sgs_f" || return 1
    fi
    return 0
  fi
  if ! sys_put "$1" "$2"; then
    _sgs_now=$(sys_get "$1" 2>/dev/null)
    log "시스템 설정($1)을 $2(으)로 바꾸지 못함(지금 값 ${_sgs_now:-읽기실패})"
    return 1
  fi
  mkdir -p "$SYSORIG" 2>/dev/null || { log "시스템 설정 백업 폴더를 만들지 못함: $SYSORIG"; return 1; }
  echo "$_sgs_orig $2" > "$_sgs_f" || { log "시스템 설정 백업 쓰기 실패: $1"; return 1; }
  log "시스템 설정($1) $_sgs_cur → $2 (원래 값 $_sgs_orig)"
  return 0
}

sys_init_if_unset() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  case "${2#-}" in ''|*[!0-9]*) return 1 ;; esac
  _si_cur=$(sys_get "$1") || { log "시스템 설정($1) 값을 읽지 못함"; return 1; }
  case "$_si_cur" in
    0)
      if [ -z "$_USB_ZWARN_TOLD" ]; then
        log "주의: $1=0 (헤드유닛 설정에서 꺼져 있어 그대로 둠)"
        _USB_ZWARN_TOLD=1
      fi
      return 0 ;;
    1)
      return 0 ;;
    *)
      sys_guard_set "$1" "$2"
      return $? ;;
  esac
}

sys_restore_key() {
  case "$1" in ''|*[!A-Za-z0-9_]*) return 1 ;; esac
  if [ -L "$SYSORIG" ]; then
    log "시스템 설정($1) 되돌리기 건너뜀: 백업 폴더가 심볼릭 링크"
    return 1
  fi
  _srk_f="$SYSORIG/$1"
  if [ -L "$_srk_f" ]; then
    log "시스템 설정($1) 되돌리기 건너뜀: 백업 파일이 심볼릭 링크"
    return 1
  fi
  [ -f "$_srk_f" ] || return 0
  _srk_orig=; _srk_app=
  read _srk_orig _srk_app < "$_srk_f"
  case "$_srk_orig" in
    null) ;;
    *) case "${_srk_orig#-}" in ''|*[!0-9]*) log "시스템 설정($1) 되돌리기 건너뜀: 백업 기록이 올바르지 않음"; rm -f "$_srk_f"; return 1 ;; esac ;;
  esac
  case "${_srk_app#-}" in
    ''|*[!0-9]*) log "시스템 설정($1) 되돌리기 건너뜀: 백업 기록이 올바르지 않음"; rm -f "$_srk_f"; return 1 ;;
  esac
  if ! command -v settings >/dev/null 2>&1; then
    log "시스템 설정($1) 되돌리기 건너뜀: settings 명령 없음"
    return 1
  fi
  _srk_cur=$(sys_get "$1") || { log "시스템 설정($1) 되돌리기 건너뜀: 값을 읽지 못함"; return 1; }
  if [ "$_srk_cur" != "$_srk_app" ]; then
    log "시스템 설정($1) 그대로 둠: 우리가 바꾼 뒤 다른 곳에서 바뀜(지금 값 $_srk_cur)"
    rm -f "$_srk_f"
    return 0
  fi
  if [ "$_srk_orig" = null ]; then
    if ! command -v content >/dev/null 2>&1; then
      log "시스템 설정($1) 되돌리기 건너뜀: content 명령 없음"
      return 1
    fi
    if sys_del "$1"; then
      log "시스템 설정($1) 되돌림(삭제): $_srk_app → null"
      rm -f "$_srk_f"
      return 0
    fi
    log "시스템 설정($1)을 되돌리지 못함(삭제 실패)"
    return 1
  fi
  if sys_put "$1" "$_srk_orig"; then
    log "시스템 설정($1) 되돌림: $_srk_app → $_srk_orig"
    rm -f "$_srk_f"
    return 0
  fi
  _srk_now=$(sys_get "$1" 2>/dev/null)
  log "시스템 설정($1)을 되돌리지 못함(지금 값 ${_srk_now:-읽기실패})"
  return 1
}

sys_restore_keys() {
  _srks_rc=0
  for _srks_k in "$@"; do
    sys_restore_key "$_srks_k" || _srks_rc=1
  done
  return $_srks_rc
}

sys_restore_all() {
  if [ -L "$SYSORIG" ]; then
    log "시스템 설정 되돌리기 건너뜀: 백업 폴더가 심볼릭 링크"
    return 1
  fi
  [ -d "$SYSORIG" ] || return 0
  case $- in *f*) _sra_f=1; set +f ;; *) _sra_f=0 ;; esac
  _sra_rc=0
  for _sra_p in "$SYSORIG"/*; do
    if [ -L "$_sra_p" ]; then
      log "시스템 설정(${_sra_p##*/}) 되돌리기 건너뜀: 백업 파일이 심볼릭 링크"
      _sra_rc=1
      continue
    fi
    [ -f "$_sra_p" ] || continue
    sys_restore_key "${_sra_p##*/}" || _sra_rc=1
  done
  if [ $_sra_f = 1 ]; then set -f; fi
  rmdir "$SYSORIG" 2>/dev/null || :
  return $_sra_rc
}

wide_apply() {
  wide_supported || return 0
  if [ ! -L "$WIDEOFF" ] && [ -f "$WIDEOFF" ]; then return 0; fi
  if ! command -v settings >/dev/null 2>&1; then
    if [ -z "$_WIDE_NOSET_TOLD" ]; then log "와이드스크린 설정 건너뜀: settings 명령 없음"; fi
    _WIDE_NOSET_TOLD=1
    return 1
  fi
  _wa_rc=0
  for _wa_k in carplay_ss_osd carplay_ss_osd_dr1 carplay_ss_osd_dr2 \
               androidauto_ss_osd androidauto_ss_osd_dr1 androidauto_ss_osd_dr2; do
    sys_guard_set "$_wa_k" 0 || _wa_rc=1
  done
  _wa_upp=$(getprop ro.product.opt.useppsettings 2>/dev/null)
  if [ "$_wa_upp" = true ]; then
    for _wa_k in phoneprojection_setting_use_split_screen \
                 phoneprojection_setting_use_split_screen_dr1 \
                 phoneprojection_setting_use_split_screen_dr2; do
      sys_guard_set "$_wa_k" 0 || _wa_rc=1
    done
  else
    for _wa_k in phoneprojection_setting_use_split_screen \
                 phoneprojection_setting_use_split_screen_dr1 \
                 phoneprojection_setting_use_split_screen_dr2; do
      if _wa_v=$(sys_get "$_wa_k"); then
        if [ "$_wa_v" = 1 ]; then sys_guard_set "$_wa_k" -1 || _wa_rc=1; fi
      else
        log "시스템 설정($_wa_k) 값을 읽지 못함"
        _wa_rc=1
      fi
    done
  fi
  return $_wa_rc
}

wide_restore() {
  if [ -L "$SYSORIG" ]; then
    log "시스템 설정 되돌리기 건너뜀: 백업 폴더가 심볼릭 링크"
    return 1
  fi
  _wr_rc=0
  sys_restore_keys \
    carplay_ss_osd carplay_ss_osd_dr1 carplay_ss_osd_dr2 \
    androidauto_ss_osd androidauto_ss_osd_dr1 androidauto_ss_osd_dr2 \
    phoneprojection_setting_use_split_screen \
    phoneprojection_setting_use_split_screen_dr1 \
    phoneprojection_setting_use_split_screen_dr2 || _wr_rc=1
  if [ ! -L "$SYSORIG" ] && [ -d "$SYSORIG" ]; then
    rmdir "$SYSORIG" 2>/dev/null || :
  fi
  return $_wr_rc
}

usb_guard() {
  usb_guard_supported || return 0
  if ! command -v settings >/dev/null 2>&1; then
    if [ -z "$_USB_NOSET_TOLD" ]; then log "유선 USB 설정 확인 건너뜀: settings 명령 없음"; fi
    _USB_NOSET_TOLD=1
    return 1
  fi
  _ug_rc=0
  for _ug_k in androidauto_information androidauto_information_dr1 androidauto_information_dr2 \
               carplay_information carplay_information_dr1 carplay_information_dr2; do
    sys_init_if_unset "$_ug_k" 1 || _ug_rc=1
  done
  _ug_upp=$(getprop ro.product.opt.useppsettings 2>/dev/null)
  if [ "$_ug_upp" = true ]; then
    for _ug_k in phoneprojection_setting_enable_usb_cable \
                 phoneprojection_setting_enable_usb_cable_dr1 \
                 phoneprojection_setting_enable_usb_cable_dr2; do
      sys_init_if_unset "$_ug_k" 1 || _ug_rc=1
    done
  else
    for _ug_k in phoneprojection_setting_enable_usb_cable \
                 phoneprojection_setting_enable_usb_cable_dr1 \
                 phoneprojection_setting_enable_usb_cable_dr2; do
      if _ug_v=$(sys_get "$_ug_k"); then
        if [ "$_ug_v" = 0 ]; then sys_guard_set "$_ug_k" -1 || _ug_rc=1; fi
      else
        log "시스템 설정($_ug_k) 값을 읽지 못함"
        _ug_rc=1
      fi
    done
  fi
  return $_ug_rc
}

idle_forever() { while true; do sleep 3600 & wait $!; done; }

main() {
  umask 077
  trap 'log "멈춤"; exit 0' TERM INT HUP
  while [ "$(getprop sys.boot_completed 2>/dev/null)" != 1 ]; do sleep 2 & wait $!; done
  prod=$(getprop ro.build.product 2>/dev/null)
  if ! car_in "$prod" "$CARS_WIDE"; then
    log "시작 안 함: $prod 는 대상 모델이 아님 ($CARS_WIDE)"
    idle_forever
  fi
  wide_apply
  usb_guard
  log "와이드스크린 서비스 시작 ($prod)"
  while true; do
    sleep 600 &
    wait $!
    wide_apply
    usb_guard
  done
}

[ "$WIDESCREEN_LIB" = 1 ] || main
