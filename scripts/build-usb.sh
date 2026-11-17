#!/bin/sh
# 더 뉴 그랜저 IG (IGPE.KOR.*.260902) 와이드스크린 전용 NEMESIS USB 설치 묶음을 만든다.
set -e
umask 022
B=$(cd "$(dirname "$0")/.." && pwd)
PKGDIR=$B/nemesis-pkg/igpe.widescreen
OUT=${1:-$(cd "$B/.." && pwd)}

[ -d "$PKGDIR" ] || { echo "패키지 폴더 없음: $PKGDIR" >&2; exit 1; }
VER=$(grep '^package-version=' "$PKGDIR/NEMESIS.data" | sed 's/^package-version=//; s/\r$//')
case "$VER" in
  ''|*[!0-9.]*) echo "package-version 읽기 실패: '$VER'" >&2; exit 1 ;;
esac

W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/pkg" "$W/usb/packages"

cp -R "$PKGDIR"/. "$W/pkg/"
find "$W/pkg" -type f \( -name '*.sh' -o -name 'NEMESIS.data' \) -exec sh -c '
  for f in "$@"; do
    tr -d "\r" < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
' _ {} +
chmod 644 "$W/pkg/NEMESIS.data"
chmod 755 "$W/pkg/svc/widescreen.sh" "$W/pkg/scripts/post.sh" "$W/pkg/scripts/preun.sh" "$W/pkg/bin/status.sh"

(cd "$W/pkg" && zip -X -q -r "$W/usb/packages/igpe.widescreen.zip" .)

printf '[nemesis]\ntype=install\npath=packages/igpe.widescreen.zip\n' > "$W/usb/NEMESIS.data"
cat > "$W/usb/README.txt" <<EOF
Grandeur IG Widescreen (1920x720) $VER - USB 설치 파일
(NEMESIS Manager 목록에서는 "Grandeur IG Widescreen (1920x720)"으로 보입니다)

* 무선 핫스팟(hostapd), Wi-Fi 잠금, HMG-API 무선 모드를 설치하거나 수정하지 않고
  더 뉴 그랜저 IG (IGPE.KOR.*.260902)의 1920x720 전체화면과 유선 프로젝션 설정만 적용·유지합니다.
* 기존 korea.projection(1.7.2 등)이 설치된 상태에서도 삭제 없이 바로 설치해 설정값만 변경할 수 있습니다.
  (단, 이미 와이드 패치가 포함된 korea.projection 버전을 쓰는 경우 중복 설치할 필요는 없습니다.)

1. USB를 FAT32로 포맷합니다.
2. 이 폴더 안의 NEMESIS.data, README.txt, packages 폴더를 USB 맨 위에 복사합니다.
3. 시동을 켜고 내비 화면이 다 뜬 뒤 USB를 꽂고 설치를 진행합니다.
4. 분할화면으로 잠시 되돌리려면 USB 맨 위에 빈 파일 kp-wide-off를 넣고 Launch(또는 재설치)하세요.
   다시 1920x720으로 켜려면 kp-wide-on 파일을 넣고 Launch하세요.
5. NEMESIS Manager에서 Uninstall하면 설치 전 원래 시스템 설정으로 자동 복원됩니다.
EOF

Z="$OUT/igpe-widescreen-$VER-usb.zip"
rm -f "$Z"
(cd "$W/usb" && zip -X -q -r "$Z" NEMESIS.data README.txt packages/igpe.widescreen.zip)
echo "만듦: $Z"
sha256sum "$Z" 2>/dev/null || shasum -a 256 "$Z"
