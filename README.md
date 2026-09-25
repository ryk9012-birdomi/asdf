# 잿불 서약 / Oath of Embers

용의 교단이 왕국을 잠식하는 시대, 맹세로 묶인 세 모험가가 잿빛 고갯길을 넘어 교단의 심장부로 향하는 **D&D풍 판타지 파티 로그라이트**입니다. 발더스 게이트 3처럼 주도권 순서, 전열과 후열, 주문과 기술로 싸우고, 모든 공격은 **6면체 주사위 2개(2d6)** 로 판정합니다.

- 엔진: **Godot 4.7.2 stable** / GDScript / Compatibility(OpenGL) 렌더러
- 프로젝트 루트: [`godot/project.godot`](godot/project.godot) (이 폴더가 `res://`)
- 현재 단계: **로드맵 3단계 완료**. 메인 메뉴 → 슬레이 더 스파이어식 여정 지도 → 전투·정예·휴식·보물 → 보스까지 한 막을 끝까지 플레이할 수 있습니다([로드맵](godot/docs/ROADMAP.md)).

## 실행

[Godot 4.7.2](https://godotengine.org/download/)를 설치합니다. 스크립트는 다음 순서로 실행 파일을 찾습니다. `-GodotPath` 인자, `GODOT_BIN` 환경 변수, `%LOCALAPPDATA%\Godot\Godot-4.7.2\`, PATH의 `godot`/`godot4` 순입니다.

| 목적 | 명령 |
|---|---|
| 게임 실행 (메인 메뉴) | `Play-Godot.cmd` 더블클릭 또는 `./Open-Godot.ps1 -Run` |
| Godot 에디터 열기 | `./Open-Godot.ps1` |
| 자동 검증 | `./Open-Godot.ps1 -Test` |

Windows 외 환경에서는 직접 실행합니다.

```sh
godot --path godot                                                   # 게임 실행 (메인 메뉴)
godot --headless --path godot --editor --import                      # 최초 1회 리소스 임포트
godot --headless --path godot --script res://tests/test_character_system.gd
godot --headless --path godot --script res://tests/test_battle.gd
godot --headless --path godot --script res://tests/test_flow.gd
godot --headless --path godot --script res://tests/test_run.gd
```

## 메인 메뉴

- **새 여정**: 새 지도를 만들고 여정을 시작합니다.
- **이어하기**: 진행 중인 여정으로 돌아갑니다. 게임을 끄면 사라지며, 파일 저장은 5단계에서 추가합니다.
- **야영지**: 일행의 능력치와 상태를 확인합니다.
- **종료**
- 전투와 야영지 화면에도 `메인 메뉴` 버튼이 있습니다. 화면이 바뀔 때마다 어둠이 걷히는 전환 효과가 공통으로 적용됩니다.

## 여정 지도

- 10층짜리 갈림길 지도에서 금빛으로 빛나는 다음 층 노드를 클릭해 길을 고릅니다. 한 번 고른 길은 되돌릴 수 없습니다.
- 노드 종류: 전투 · 정예(홉고블린 대장) · 휴식(HP 40% 회복) · 이벤트 · 보물(골드) · 보스(잿불 사제 모르간)
- 전투 사이에 HP가 이어집니다. 전투에서 이기면 쓰러진 동료는 HP 1로 일어나고, 파티가 전멸하면 여정이 끝납니다.

## 전투 화면

- **왼쪽은 일행, 오른쪽은 적(고블린 약탈자)** 입니다. 양쪽 모두 전열 카드가 가운데 VS 쪽으로 가장 가깝게 배치됩니다.
- 일행: **알데릭**(Paladin, 전열) · **시엔**(Rogue, 중열) · **엘로웬**(Wizard, 후열)
- 상단 칩은 이번 라운드의 주도권(행동 순서)입니다. 금색으로 빛나는 카드는 현재 행동자입니다.
- 스킬 버튼을 누른 뒤 **초록빛으로 빛나는 카드**를 클릭하면 대상이 확정됩니다. 대상 카드에 **적중·명중·스침·치명 확률(%)과 예상 피해**가 표시되고, 적 카드에는 다음 행동의 대상과 적중률이 예고됩니다.
- **판정:** `2d6 + 공격자 명중 − 대상 방어`
  - 6 이하: 빗나감
  - 7~9: 스침(피해 절반, 올림)
  - 10 이상: 명중
  - 주사위 눈의 합이 공격자의 치명 기준(기본 12, 로그는 11) 이상이면 보정과 관계없이 치명타(피해 2배)
  - 마법 화살처럼 `auto_hit` 스킬은 굴림 없이 명중합니다.
- 굴린 주사위 두 개가 대상 위에서 굴러 멈추고, 결과가 모험 일지에 `2d6 [5+3] +1 = 9 → 스침`처럼 기록됩니다.
- **HP 규모:** 레벨 1~2 유닛은 HP 10 이하(알데릭 10, 시엔 8, 엘로웬 6, 고블린 6), 레벨 5 이상의 정예·보스는 20 이상으로 설계합니다.
- 피해 유형별로 연출이 다릅니다. 물리 근접은 베기, 화염은 불줄기, 비전은 세 갈래 마법 화살, 광휘는 빛기둥입니다. 치명타는 화면이 흔들리고, 보호막은 파동이 퍼지며, 쓰러지면 표시가 찍힙니다.

## 폴더

```text
godot/
├─ project.godot
├─ scenes/     battle(전투), main(메인 메뉴·야영지), run(지도·노드·결과), ui(카드/전투 UI)
├─ scripts/    core(화면 전환), run(지도 생성·여정 상태·전투 구성·지도 화면), battle(규칙), characters(유닛/데이터), skills, ui(테마·표시·연출)
├─ data/       classes · enemies · skills  (.tres 데이터)
├─ tests/      헤드리스 자동 검증
└─ docs/       단계별 개발 문서
```

## 문서

- [로드맵: 메인 메뉴부터 한 막 완주까지](godot/docs/ROADMAP.md)
- [프로젝트 구조와 1단계 기록](godot/README.md)
- [MVP 1 · 2단계: 턴제 전투 구현·조작·테스트](godot/docs/MVP1_STEP2.md)
