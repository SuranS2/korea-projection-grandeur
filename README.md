# Grandeur IG Widescreen (`igpe.widescreen`)

한국 내수 더 뉴 그랜저 IG PE (`IGPE.KOR.*.260902`) Gen5W 헤드유닛에서 순정 핫스팟(`hostapd`)·`HMG-API`·`/system` 파일을 전혀 건드리지 않고 **카플레이·안드로이드 오토 `1920x720` 전체화면(와이드스크린)과 유선 연결 설정만** 적용·유지하는 NEMESIS 패키지입니다.

- **기존 `korea.projection`과 함께 설치 가능:** `korea.projection`(1.7.2 등)이 이미 설치되어 있어도 **삭제나 재부팅 없이** 바로 추가 설치해 전체화면 설정값만 변경·유지할 수 있습니다. (단, 이미 와이드 패치가 포함된 `korea.projection` 빌드를 사용 중이라면 중복 설치할 필요가 없습니다.)
- **단독(유선) 설치도 가능:** 무선 프로젝션이나 `HMG-API` 없이도 NEMESIS만 있으면 동작하며, `busybox`·`awk`·`sed`·`/system` 수정 없이 순정 `/system/bin/sh` + `toolbox`로만 작동합니다.
- **자동 백업 및 원복:** 설치 전에 기존 `Settings.System` 값을 저장해 두며, NEMESIS Manager에서 **Uninstall**하면 설치 전 상태로 자동 복원됩니다.

> ⚠️ 차량 소프트웨어를 변경하는 패키지입니다. 모든 책임은 차주 본인에게 있으며, 설치와 조작은 반드시 정차 상태에서 진행하세요.

---

## 지원 대상

| 항목 | 내용 |
|---|---|
| 확인된 빌드 패턴 | `IGPE.KOR.*.260902` (예: `IGPE.KOR.S5W_M.V039.001.260902`, `IGPE.KOR.0000.V039.001.260902`) |
| 필요 환경 | **NEMESIS 1.16 이상** (`HMG-API`는 없어도 됨) |
| USB 메모리 | 32GB 이하 권장, **FAT32** 포맷 |

- 다른 차종(`IGPE21`, `IGPEHEV`, `DN8`, `CN7` 등)이나 다른 소프트웨어 날짜 빌드(`260604` 등)에서는 안전을 위해 설정을 적용하지 않습니다.
- 다른 차종·빌드용으로 직접 빌드하려면 [NEMESIS.data](nemesis-pkg/igpe.widescreen/NEMESIS.data)의 `os=`와 [svc/widescreen.sh](nemesis-pkg/igpe.widescreen/svc/widescreen.sh)의 `CARS_WIDE`를 수정한 뒤 `sh scripts/build-usb.sh`로 다시 묶으면 됩니다.

---

## USB에 담아 바로 설치하기

### 1. USB 준비 (FAT32)
1. 32GB 이하 USB 메모리를 **FAT32**로 포맷합니다.
2. 아래 두 가지 방법 중 하나로 USB 설치 파일을 받습니다.
   - **방법 A (권장 · ZIP 다운로드):** [Releases](../../releases) 또는 [`dist/igpe-widescreen-1.0.0-usb.zip`](dist/igpe-widescreen-1.0.0-usb.zip)을 내려받아 압축을 푼 뒤, **폴더 안의 내용물 3개**를 USB 맨 위(루트)에 복사합니다.
   - **방법 B (저장소 `usb/` 폴더 사용):** 이 브랜치의 [`usb/`](usb) 폴더 안의 내용물을 그대로 USB 맨 위(루트)에 복사합니다.

### 2. USB 폴더 구조 확인
USB를 열었을 때 맨 위에 아래 3가지가 바로 보여야 합니다.

```text
USB (맨 위 / 루트)
├─ NEMESIS.data
├─ README.txt
└─ packages/
    └─ igpe.widescreen.zip   ← 안쪽 zip은 절대 풀지 마세요
```

> 가장 흔한 실수: `packages/igpe.widescreen.zip`의 압축을 풀어 버리거나, 바깥 ZIP 이름 폴더째로 USB에 복사하면 NEMESIS가 인식하지 못합니다.

### 3. 차량에서 설치
1. 시동을 켜고 내비게이션 화면이 완전히 부팅될 때까지 기다립니다.
2. 준비한 USB를 차량 USB 단자에 꽂고 설치 팝업이 뜨면 **예**를 누릅니다.
3. 설치가 완료되면 USB를 빼고, 필요 시 폰을 다시 연결해 `1920x720` 전체화면 적용 여부를 확인합니다.

---

## 일시 끄기 / 다시 켜기 (USB 토글)

패키지를 지우지 않고 순정 분할화면으로 잠시 되돌리거나 다시 켤 수 있습니다.

1. FAT32 USB 맨 위(루트)에 확장자 없는 빈 파일을 만듭니다.
   - 끄기(원래 값 복원): `kp-wide-off`
   - 다시 켜기(`1920x720` 재적용): `kp-wide-on`
2. USB를 차량에 꽂은 상태에서 **NEMESIS Manager → Grandeur IG Widescreen (1920x720) → Launch**를 누릅니다(또는 재설치).
3. 두 파일이 모두 있으면 안전을 위해 `kp-wide-off`가 우선합니다.

---

## 삭제 및 원래 상태로 복구

NEMESIS Manager에서 **Grandeur IG Widescreen (1920x720) → Uninstall**을 실행하면:
- 설치 전에 이미 있던 설정값은 원래 숫자로 복원됩니다.
- 설치 전에 없던(`null`) 키는 `content delete`로 다시 제거됩니다.
- 패키지 설치 이후 사용자가 직접 바꾼 키가 있다면 덮어쓰지 않고 보존합니다.

---

## 변경·보호하는 시스템 설정 (`Settings.System`)

- 와이드스크린 (`0` / `-1` 적용):
  - `carplay_ss_osd`, `carplay_ss_osd_dr1`, `carplay_ss_osd_dr2` (`0`)
  - `androidauto_ss_osd`, `androidauto_ss_osd_dr1`, `androidauto_ss_osd_dr2` (`0`)
  - `phoneprojection_setting_use_split_screen`, `phoneprojection_setting_use_split_screen_dr1`, `phoneprojection_setting_use_split_screen_dr2` (`-1`)
- 유선 프로젝션 보호 (미설정이거나 `0`이 아닌 경우만 `1`로 설정, 명시적 `0`은 유지):
  - `carplay_information`, `carplay_information_dr1`, `carplay_information_dr2`
  - `androidauto_information`, `androidauto_information_dr1`, `androidauto_information_dr2`
  - `phoneprojection_setting_enable_usb_cable`, `phoneprojection_setting_enable_usb_cable_dr1`, `phoneprojection_setting_enable_usb_cable_dr2`

---

## 참고 및 미확인 사항

- `usb/` 및 `dist/igpe-widescreen-1.0.0-usb.zip`은 `scripts/build-usb.sh`로 생성되었으며 PC 스텁 테스트(`sh tests/stub-test.sh`, `sh`·`mksh`·`ksh`)를 통과했습니다.
- `HMG-API`나 `korea.projection` 없이 순정 상태로 **유선 Apple CarPlay**만 쓸 경우, `HKMC_DiPO`가 `carplay_wireless` 여부를 참조하는 분기로 인해 순정 유선 CarPlay에 `1920x720`이 반영되는지는 실차 검증이 필요합니다. (`korea.projection`이 이미 설치된 환경에서는 유·무선 동작을 실차에서 함께 확인해 주세요.)

---

## 직접 검증 및 빌드하기 (개발자용)

```sh
sh tests/stub-test.sh
sh scripts/build-usb.sh ./dist
```
