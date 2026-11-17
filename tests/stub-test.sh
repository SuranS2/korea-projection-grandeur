#!/bin/sh
# 와이드스크린 전용 패키지(igpe.widescreen) PC 모의 검증 스크립트
B=$(cd "$(dirname "$0")/.." && pwd)
PKG=$B/nemesis-pkg/igpe.widescreen
T=$(mktemp -d /tmp/igpe-wide.XXXXXX)
trap 'rm -rf "$T"' EXIT
fails=0
ok() { echo "ok   $1"; }
bad() { echo "FAIL $1"; fails=$((fails+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

PY3=$(command -v python3)
KSHS=$(for s in mksh ksh; do command -v $s; done)
[ -n "$KSHS" ] || bad "구문 검사: mksh/ksh 없음"

# LF 정규화 복사본으로 구문·위생 검사
mkdir -p "$T/app" "$T/bin" "$T/tb"
cp -R "$PKG"/. "$T/app/"
for f in "$PKG/svc/widescreen.sh" "$PKG/scripts/post.sh" "$PKG/scripts/preun.sh" "$PKG/bin/status.sh"; do
  check "CRLF 없음: ${f#$B/}" '$PY3 -c "import sys; sys.exit(1 if chr(13).encode() in open(sys.argv[1],\"rb\").read() else 0)" "$f"'
  check "구문 검사 sh: ${f#$B/}" 'sh -n "$f"'
  for KSH in $KSHS; do check "구문 검사 $(basename $KSH): ${f#$B/}" '$KSH -n "$f"'; done
done
check "위생: 무선·시스템 변경(busybox/hostapd/hmgapid/remount/printf) 실행 코드 없음" '
  $PY3 - "$PKG/svc/widescreen.sh" "$PKG/scripts/post.sh" "$PKG/scripts/preun.sh" "$PKG/bin/status.sh" <<'\''PY'\''
import re, sys
bad = re.compile(r"\b(hostapd|dnsmasq|hmgapid|wpa_supplicant|remount|busybox|printf)\b")
for p in sys.argv[1:]:
    for idx, line in enumerate(open(p, encoding="utf-8"), 1):
        code = re.sub(r"(^|\s)#.*$", "", line.strip())
        if bad.search(code):
            sys.stderr.write("forbidden token in %s:%d: %s\n" % (p, idx, line.strip()))
            sys.exit(1)
PY'

cat > "$T/bin/dbtool.py" <<'PY'
import json, os, re, sys

db_path = os.environ["WS_DB"]
calls_path = os.environ["WS_CALLS"]
ws_dir = os.environ["WS_DIR"]

def load():
    if os.path.exists(db_path):
        with open(db_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"system": {}, "global": {}, "secure": {}}

def save(db):
    tmp = db_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, sort_keys=True)
    os.replace(tmp, db_path)

def log_call(line):
    with open(calls_path, "a", encoding="utf-8") as f:
        f.write(line + "\n")

mode, args = sys.argv[1], sys.argv[2:]
if mode == "settings":
    log_call("settings " + " ".join(args))
    if os.path.exists(os.path.join(ws_dir, "settings.fail")):
        sys.exit(1)
    if os.path.exists(os.path.join(ws_dir, "settings.garbage")):
        sys.stdout.write("Failure calling service settings: Broken pipe\n")
        sys.exit(0)
    op, ns, key = args[0], args[1], args[2]
    db = load()
    tbl = db.setdefault(ns, {})
    if op == "get":
        if os.path.exists(os.path.join(ws_dir, "settings.empty")):
            sys.exit(0)
        print(tbl.get(key, "null"))
    elif op == "put":
        val = args[3]
        if os.path.exists(os.path.join(ws_dir, "settings.ro")):
            sys.exit(0)
        tbl[key] = val
        save(db)
elif mode == "content":
    log_call("content " + " ".join(args))
    if os.path.exists(os.path.join(ws_dir, "content.fail")):
        sys.exit(1)
    uri = args[args.index("--uri") + 1]
    where = args[args.index("--where") + 1]
    m_uri = re.match(r"^content://settings/(system|global|secure)$", uri)
    m_where = re.match(r"^name='([A-Za-z0-9_]+)'$", where)
    if not m_uri or not m_where:
        sys.exit(2)
    if os.path.exists(os.path.join(ws_dir, "content.ro")):
        sys.exit(0)
    db = load()
    db.setdefault(m_uri.group(1), {}).pop(m_where.group(1), None)
    save(db)
PY

cat > "$T/bin/settings" <<E
#!/bin/sh
WS_DB=$T/db.json WS_CALLS=$T/calls WS_DIR=$T exec $PY3 $T/bin/dbtool.py settings "\$@"
E
cat > "$T/bin/content" <<E
#!/bin/sh
WS_DB=$T/db.json WS_CALLS=$T/calls WS_DIR=$T exec $PY3 $T/bin/dbtool.py content "\$@"
E
cat > "$T/bin/getprop" <<E
#!/bin/sh
case "\$1" in
  ro.build.product) cat $T/prop.product 2>/dev/null || echo IGPE.KOR.S5W_M.V039.001.260902 ;;
  ro.device.splitscreen) [ -f $T/prop.splitscreen ] && cat $T/prop.splitscreen ;;
  ro.product.opt.useppsettings) [ -f $T/prop.useppsettings ] && cat $T/prop.useppsettings ;;
  sys.boot_completed) echo 1 ;;
  *) echo 0 ;;
esac
E
printf '#!/bin/sh\n/bin/sleep 0.01\n' > "$T/bin/sleep"
chmod +x "$T/bin/"*

# pure toolbox PATH (busybox·awk·sed·printf 없음)
for c in rm mkdir cat grep date echo; do
  cmd=$(command -v $c)
  [ -n "$cmd" ] && ln -sf "$cmd" "$T/tb/$c"
done
ln -sf "$(command -v rmdir)" "$T/tb/rmdir"
cp "$T/bin/settings" "$T/bin/content" "$T/bin/getprop" "$T/bin/sleep" "$T/tb/"

sed "s#^export PATH=.*#export PATH=$T/tb#" "$PKG/svc/widescreen.sh" > "$T/app/svc/widescreen.sh"
sed "s#^export PATH=.*#export PATH=$T/tb#" "$PKG/scripts/post.sh" > "$T/app/scripts/post.sh"
sed "s#^export PATH=.*#export PATH=$T/tb#" "$PKG/scripts/preun.sh" > "$T/app/scripts/preun.sh"
sed "s#^export PATH=.*#export PATH=$T/tb#" "$PKG/bin/status.sh" > "$T/app/bin/status.sh"
chmod +x "$T/app/svc/widescreen.sh" "$T/app/scripts/post.sh" "$T/app/scripts/preun.sh" "$T/app/bin/status.sh"

db_set() { $PY3 -c 'import json,os,sys; p=sys.argv[1]; db=json.load(open(p)) if os.path.exists(p) else {"system":{},"global":{},"secure":{}}; db["system"][sys.argv[2]]=sys.argv[3]; json.dump(db,open(p,"w"),sort_keys=True)' "$T/db.json" "$1" "$2"; }
db_get() { $PY3 -c 'import json,os,sys; db=json.load(open(sys.argv[1])) if os.path.exists(sys.argv[1]) else {}; print(db.get("system",{}).get(sys.argv[2],"__ABSENT__"))' "$T/db.json" "$1"; }

reset_env() {
  rm -rf "$T/bk" "$T/usb0" "$T/usb1" "$T/stage" "$T/calls" "$T/out" "$T/db.json" \
    "$T/settings.fail" "$T/settings.ro" "$T/settings.empty" "$T/settings.garbage" "$T/content.fail" "$T/content.ro" "$T/victim"
  mkdir -p "$T/bk" "$T/usb0" "$T/usb1" "$T/stage"
  echo IGPE.KOR.S5W_M.V039.001.260902 > "$T/prop.product"
  echo left_right > "$T/prop.splitscreen"
  echo false > "$T/prop.useppsettings"
  printf '/dev/block/sda1 %s/usb0 vfat rw 0 0\n' "$T" > "$T/mounts"
  printf '{"system":{},"global":{},"secure":{}}\n' > "$T/db.json"
}

run_lib() {
  (PATH=$T/tb APP=$T/app BK=$T/bk WIDESCREEN_LIB=1 ${TSH:-/bin/sh} -c '. "$APP/svc/widescreen.sh"; '"$1")
}

# 1. 지원/격리 검사
reset_env
check "대상 차종: IGPE.KOR.0000·S5W_M .260902 지원, 타 모델·타 빌드 배제" '
  for p in IGPE.KOR.0000.V039.001.260902 IGPE.KOR.S5W_M.V039.001.260902; do
    echo "$p" > "$T/prop.product"
    run_lib wide_supported || exit 1
    run_lib usb_guard_supported || exit 1
  done
  for p in IGPE21.KOR.0000.V039.001.260902 IGPEHEV.KOR.0000.V039.001.260902 IGPE21HEV.KOR.0000.V039.001.260902 IGPE.KOR.S5W_M.V038.001.260604 DEPEHEV.KOR.0000.V039.001.260902 IGPE.USA.0000.V039.001.260902; do
    echo "$p" > "$T/prop.product"
    ! run_lib wide_supported || exit 1
    ! run_lib usb_guard_supported || exit 1
  done'

# 2. post.sh 설치 + USB 토글 + 비대상 격리
reset_env
db_set carplay_ss_osd_dr1 1
db_set phoneprojection_setting_use_split_screen 1
db_set androidauto_information_dr2 0
PATH=$T/tb APP=$T/app BK=$T/bk USBS="$T/usb0 $T/usb1" /bin/sh "$T/app/scripts/post.sh" > "$T/out" 2>&1; _rc=$?
check "post.sh: toolbox 전용 환경에서 와이드(0/-1) 및 USB 가드(1, 0 보존) 적용" '
  [ $_rc = 0 ] && ! grep -q "not found" "$T/out" &&
  [ "$(db_get carplay_ss_osd)" = 0 ] && [ "$(db_get carplay_ss_osd_dr1)" = 0 ] &&
  [ "$(db_get androidauto_ss_osd_dr2)" = 0 ] &&
  [ "$(db_get phoneprojection_setting_use_split_screen)" = -1 ] &&
  [ "$(db_get androidauto_information)" = 1 ] && [ "$(db_get androidauto_information_dr2)" = 0 ] &&
  [ "$(cat "$T/bk/sys.orig/carplay_ss_osd")" = "null 0" ] &&
  [ "$(cat "$T/bk/sys.orig/carplay_ss_osd_dr1")" = "1 0" ]'

# 3. status.sh (Launch) kp-wide-off / kp-wide-on
: > "$T/usb0/kp-wide-on"; : > "$T/usb1/kp-wide-off"
printf '/dev/block/sda1 %s/usb0 vfat rw 0 0\n/dev/block/sdb1 %s/usb1 vfat rw 0 0\n' "$T" "$T" > "$T/mounts"
PATH=$T/tb APP=$T/app BK=$T/bk USBS="$T/usb0 $T/usb1" MOUNTS=$T/mounts /bin/sh "$T/app/bin/status.sh" > "$T/out" 2>&1
check "status.sh: usb1 kp-wide-off 우선 → 원래 값(null→content delete, 1→1) 복원" '
  [ -f "$T/bk/wide-off" ] && grep -q "꺼짐 (kp-wide-off)" "$T/out" &&
  [ "$(db_get carplay_ss_osd)" = "__ABSENT__" ] && [ "$(db_get carplay_ss_osd_dr1)" = 1 ] &&
  [ "$(db_get phoneprojection_setting_use_split_screen)" = 1 ] &&
  [ "$(db_get androidauto_information)" = 1 ]'

rm -f "$T/usb1/kp-wide-off"
printf '/dev/block/sda1 %s/usb0 vfat rw 0 0\n' "$T" > "$T/mounts"
PATH=$T/tb APP=$T/app BK=$T/bk USBS="$T/usb0 $T/usb1" MOUNTS=$T/mounts /bin/sh "$T/app/bin/status.sh" > "$T/out" 2>&1
check "status.sh: kp-wide-on → wide-off 삭제 및 1920x720 재적용" '
  [ ! -f "$T/bk/wide-off" ] && grep -q "켜짐 (1920x720)" "$T/out" &&
  [ "$(db_get carplay_ss_osd)" = 0 ] && [ "$(db_get carplay_ss_osd_dr1)" = 0 ]'

# 4. widescreen.sh 서비스 루프(sh·mksh·ksh) 및 외부 변경 재적용
for _msh in /bin/sh $KSHS; do
  reset_env
  (PATH=$T/tb APP=$T/app BK=$T/bk WIDESCREEN_LIB=1 $_msh -c '. "$APP/svc/widescreen.sh"; _wc=0; sleep() { :; }; wait() { _wc=$((_wc+1)); [ $_wc -eq 1 ] && '$T'/tb/settings put system carplay_ss_osd 1; [ $_wc -ge 2 ] && exit 0; return 0; }; main') > "$T/out" 2>&1
  check "서비스 main()($_msh): 주기 점검에서 외부 변경(0→1) 재적용 및 sys.orig 보존" '
    [ "$(db_get carplay_ss_osd)" = 0 ] && [ "$(cat "$T/bk/sys.orig/carplay_ss_osd")" = "null 0" ]'
done

# 5. preun.sh 업데이트 보존 및 전체 삭제 복구
reset_env
PATH=$T/tb APP=$T/app BK=$T/bk USBS="$T/usb0 $T/usb1" /bin/sh "$T/app/scripts/post.sh" > "$T/out" 2>&1
echo id=igpe.widescreen > "$T/stage/NEMESIS.data"
rm -f "$T/calls"
PATH=$T/tb APP=$T/app BK=$T/bk STAGE=$T/stage /bin/sh "$T/app/scripts/preun.sh" > "$T/out" 2>&1
check "preun.sh(업데이트): \$SYSORIG 보존, settings/content 되돌림 없음" '
  [ -f "$T/bk/sys.orig/carplay_ss_osd" ] && ! grep -qE "^(settings put|content delete)" "$T/calls" 2>/dev/null'

rm -rf "$T/stage"; mkdir -p "$T/stage"
db_set androidauto_ss_osd 1
PATH=$T/tb APP=$T/app BK=$T/bk STAGE=$T/stage /bin/sh "$T/app/scripts/preun.sh" > "$T/out" 2>&1; _urc=$?
check "preun.sh(전체 삭제): null→content delete 복구, 외부 변경 유지, \$BK 삭제" '
  [ $_urc = 0 ] && [ ! -d "$T/bk" ] &&
  [ "$(db_get carplay_ss_osd)" = "__ABSENT__" ] &&
  [ "$(db_get androidauto_information)" = "__ABSENT__" ] &&
  [ "$(db_get androidauto_ss_osd)" = 1 ]'

# 6. 심볼릭 링크 방어 + set -f 보존
reset_env
mkdir -p "$T/bk/sys.orig"
echo "0 1" > "$T/victim"
ln -s "$T/victim" "$T/bk/sys.orig/carplay_ss_osd"
! run_lib wide_apply >/dev/null 2>&1; _wrc=$?
! run_lib sys_restore_all >/dev/null 2>&1; _rrc=$?
check "심볼릭 링크 방어 및 set -f 보존" '
  [ $_wrc = 0 ] && [ $_rrc = 0 ] && [ "$(cat "$T/victim")" = "0 1" ] &&
  run_lib "set -f; sys_restore_all >/dev/null 2>&1 || true; case \$- in *f*) exit 0 ;; *) exit 1 ;; esac"'

echo "---"
[ $fails -eq 0 ] && echo "모두 통과" || { echo "실패 $fails개"; exit 1; }
