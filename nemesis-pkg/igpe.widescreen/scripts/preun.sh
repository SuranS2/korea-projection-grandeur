#!/system/bin/sh
# preuninstall: 업데이트 시 백업 보존, 전체 삭제 시 원래 시스템 설정으로 복구
export PATH=/sbin:/vendor/bin:/system/sbin:/system/bin:/system/xbin
APP=${APP:-/data/nemesis/apps/igpe.widescreen}
BK=${BK:-/data/nemesis/backup/igpe.widescreen}
STAGE=${STAGE:-/data/local/tmp/nemesis/stage/igpe.widescreen}
umask 077

case "$(cat /proc/$PPID/cmdline 2>/dev/null)" in
  *uninstall*) ;;
  *)
    if grep -q '^id=igpe\.widescreen$' "$STAGE/NEMESIS.data" 2>/dev/null; then
      echo "igpe.widescreen 업데이트: 기존 설정 백업 유지"
      exit 0
    fi ;;
esac

WIDESCREEN_LIB=1 . "$APP/svc/widescreen.sh"
modmsg=""
sys_restore_all || modmsg=" 일부 시스템 설정(와이드/USB)을 되돌리지 못했습니다."
rm -rf "$BK"
echo "그랜저 IG 와이드스크린 패키지를 삭제하고 원래 시스템 설정을 복구했습니다.$modmsg"
exit 0
