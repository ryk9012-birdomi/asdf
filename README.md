# 잿불 서약 / Oath of Embers

용의 교단이 왕국을 잠식하는 시대, 맹세로 묶인 세 모험가가 잿빛 고갯길을 넘어 교단의 심장부로 향하는 **D&D풍 판타지 파티 로그라이트**입니다. 발더스 게이트 3처럼 주도권 순서, d20 명중 굴림, 전열과 후열, 주문과 기술로 싸웁니다.

- 엔진: **Godot 4.7.2 stable** / GDScript / Compatibility(OpenGL) 렌더러
- 프로젝트 루트: [`godot/project.godot`](godot/project.godot) (이 폴더가 `res://`)
- 현재 단계: **MVP 1 · 2단계**, 3 대 3 턴제 전투

## 실행

[Godot 4.7.2](https://godotengine.org/download/)를 설치합니다. 스크립트는 다음 순서로 실행 파일을 찾습니다. `-GodotPath` 인자, `GODOT_BIN` 환경 변수, `%LOCALAPPDATA%\Godot\Godot-4.7.2\`, PATH의 `godot`/`godot4` 순입니다.

| 목적 | 명령 |
|---|---|
| 전투 바로 실행 | `Play-Godot.cmd` 더블클릭 또는 `./Open-Godot.ps1 -Run` |
| Godot 에디터 열기 | `./Open-Godot.ps1` |
| 자동 검증 | `./Open-Godot.ps1 -Test` |

Windows 외 환경에서는 직접 실행합니다.

```sh
godot --path godot                                                   # 전투 실행
godot --headless --path godot --editor --import                      # 최초 1회 리소스 임포트
godot --headless --path godot --script res://tests/test_character_system.gd
godot --headless --path godot --script res://tests/test_battle.gd
```

## 전투 화면

- **왼쪽은 일행, 오른쪽은 적(고블린 약탈자)** 입니다. 양쪽 모두 전열 카드가 가운데 VS 쪽으로 가장 가깝게 배치됩니다.
- 일행: **알데릭**(Paladin, 전열) · **시엔**(Rogue, 중열) · **엘로웬**(Wizard, 후열)
- 상단 칩은 이번 라운드의 주도권(행동 순서)입니다. 금색으로 빛나는 카드는 현재 행동자입니다.
- 스킬 버튼을 누른 뒤 **초록빛으로 빛나는 카드**를 클릭하면 대상이 확정됩니다. 모험 일지에 각 공격의 d20 명중 굴림이 기록됩니다.
- 피해 유형별로 연출이 다릅니다. 물리 근접은 베기, 화염은 불줄기, 비전은 세 갈래 마법 화살, 광휘는 빛기둥입니다. 치명타는 화면이 흔들리고, 보호막은 파동이 퍼지며, 쓰러지면 표시가 찍힙니다.

## 폴더

```text
godot/
├─ project.godot
├─ scenes/     battle(전투), main(야영지), ui(카드/전투 UI)
├─ scripts/    battle(규칙), characters(유닛/데이터), skills, ui(표시·연출)
├─ data/       classes · enemies · skills  (.tres 데이터)
├─ tests/      헤드리스 자동 검증
└─ docs/       단계별 개발 문서
```

## 문서

- [프로젝트 구조와 1단계 기록](godot/README.md)
- [MVP 1 · 2단계: 턴제 전투 구현·조작·테스트](godot/docs/MVP1_STEP2.md)
