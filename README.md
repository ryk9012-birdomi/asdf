# 잔광 항로 / Afterlight Traverse

항성 간 항로가 무너진 시대, 세 명의 인양 대원이 전쟁 잔해 속에서 귀환 항로를 찾는 **SF 파티 로그라이트**입니다.

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

- **왼쪽은 아군(잔광 인양단), 오른쪽은 적(봉쇄군)** 입니다. 양쪽 모두 전열 카드가 가운데 VS 쪽으로 가장 가깝게 배치됩니다.
- 상단 칩은 이번 라운드의 남은 행동 순서입니다. 금색으로 빛나는 카드는 현재 행동자입니다.
- 스킬 버튼을 누른 뒤 **청록색으로 빛나는 카드**를 클릭하면 대상이 확정됩니다.
- 타격 시 궤적 빔, 파편, 피해 숫자, 치명타 화면 흔들림, 실드 파동, 전투 불능 표시가 나옵니다.

## 폴더

```text
godot/
├─ project.godot
├─ scenes/     battle(전투), main(준비실), ui(카드/전투 UI)
├─ scripts/    battle(규칙), characters(유닛/데이터), skills, ui(표시·연출)
├─ data/       classes · enemies · skills  (.tres 데이터)
├─ tests/      헤드리스 자동 검증
└─ docs/       단계별 개발 문서
```

## 문서

- [프로젝트 구조와 1단계 기록](godot/README.md)
- [MVP 1 · 2단계: 턴제 전투 구현·조작·테스트](godot/docs/MVP1_STEP2.md)

## 참고

저장소 루트의 `Assets/`, `Packages/`, `ProjectSettings/`, `Open-Unity.ps1`은 초기에 만든 Unity 템플릿의 잔재입니다. 게임 코드는 없고 현재 개발에 쓰이지 않습니다. Godot 빌드와 실행에는 영향이 없습니다.
