# MVP 1 · 2단계: 3 대 3 턴제 전투

기본 실행 장면은 `res://scenes/battle/BattleScene.tscn`입니다. 기존 캐릭터 상태 시스템 위에 전투를 연결했습니다. 기준 엔진은 실제 검증에 사용한 Godot 4.7.2 stable입니다.

## 1. 이번 단계의 목표

로그·위저드·팔라딘이 고블린 약탈자 3명과 싸우는 한 번의 전투를 끝까지 플레이합니다. Speed 기반 행동 순서, 기본 공격과 스킬, 스킬 선택 → 대상 선택, 명중·치명타·방어, 보호막, 기력·쿨다운, 사망자 제외, 승리·패배, 재시작을 구현했습니다. 적은 공격 → 보호막 → 화염병 패턴을 반복하고 다음 행동을 표시합니다.

전투 규칙은 BattleManager, 행동 순서는 TurnManager, 계산은 DamageCalculator, 대상 규칙은 TargetRules, 화면은 BattleUI로 분리했습니다. 전투 판정은 동기적으로 처리하고 Scene의 Timer가 행동 사이에 0.65초 간격을 둡니다. 적과 아군의 사망 노드는 결과 화면과 로그를 위해 씬에 남깁니다.

## 2. Scene Tree

```text
BattleScene (Control)                ← BattleScene.gd
├─ Units (Node)
│  ├─ CharacterUnit × 3             ← CharacterUnit.tscn / CharacterUnit.gd
│  └─ EnemyUnit × 3                 ← EnemyUnit.tscn / EnemyUnit.gd
├─ BattleManager (Node)              ← BattleManager.tscn / BattleManager.gd
│  └─ TurnManager (Node)             ← TurnManager.gd
├─ BattleUI (Control)                ← BattleUI.tscn / BattleUI.gd
│  ├─ EmberBackdrop                 # 횃불빛 연기·불씨 셰이더 배경
│  ├─ Scroll / Margin / VBox        # 실행 시 생성
│  │  ├─ 제목 / 야영지 / 재시작
│  │  ├─ 라운드 / 행동 순서 칩
│  │  ├─ 전장: 아군 카드(왼쪽) │ VS │ 적 카드·Intent(오른쪽)
│  │  ├─ 승패 결과 배너
│  │  ├─ 스킬 버튼 / 대기
│  │  └─ 전투 로그 / 조작 안내
│  └─ FX 레이어                     # 베기·화염·비전 화살·광휘 기둥·피해 숫자
└─ ActionTimer (Timer, One Shot)
```

CharacterLab의 `모험 떠나기` 버튼은 BattleScene으로, 전투의 `야영지` 버튼은 CharacterLab으로 이동합니다. 야영지 조작 결과를 전투에 가져오지는 않습니다. 이번 단계는 매번 시작 데이터로 생성하는 독립 전투이며, Run 사이의 상태 유지 책임은 다음 RunManager에 둡니다.

## 3. 필요한 파일

다음 파일을 추가했습니다. 모든 `res://` 경로는 `game/godot/` 기준입니다.

| 경로 | 책임 |
| --- | --- |
| `res://scripts/characters/EnemyData.gd` | CharacterData 상속, 데이터 기반 적 행동 패턴과 검증 |
| `res://scripts/characters/EnemyUnit.gd` | CharacterUnit 상속, 패턴 커서·행동 예고·비용 부족 시 대체 스킬 |
| `res://scripts/battle/BattleManager.gd` | 유닛 등록, 행동 검증·실행, 자원 비용, 결과 판정 |
| `res://scripts/battle/TurnManager.gd` | Speed 큐, 라운드, 턴 시작/종료 Signal |
| `res://scripts/battle/DamageCalculator.gd` | 명중·치명타·방어 계산 |
| `res://scripts/battle/TargetRules.gd` | 여덟 가지 대상 유형, 살아 있는 전열/후열 판정 |
| `res://scripts/battle/BattleScene.gd` | 유닛 생성, 타이머, 화면 이동 연결 |
| `res://scripts/ui/BattleUI.gd` | 상태 표시, 스킬/대상 선택, 로그, 결과 화면 |
| `res://scripts/ui/CombatantView.gd` | 문장(紋章) 방패, 금테 장식, HP 잔상 바·보호막 바·기력 구슬, 행동/대상 발광, 타격 흔들림, 전투 불능 표시 |
| `res://scripts/ui/EmberBackdrop.gd` | 전투·야영지 공용 횃불빛 연기와 불씨 배경 셰이더 |
| `res://scenes/battle/EnemyUnit.tscn` | EnemyUnit 스크립트가 붙은 Node |
| `res://scenes/battle/BattleManager.tscn` | BattleManager와 TurnManager 연결 |
| `res://scenes/battle/BattleScene.tscn` | 실행 가능한 3 대 3 전투 구성 |
| `res://scenes/ui/BattleUI.tscn` | 전투 UI 루트 |
| `res://data/enemies/goblin_raider.tres` | 고블린 약탈자 능력치와 행동 패턴 |
| `res://data/skills/goblin_slash.tres` | 녹슨 신월도 |
| `res://data/skills/goblin_guard.tres` | 방패 뒤로 숨기 |
| `res://data/skills/goblin_firebomb.tres` | 화염병 투척 |
| `res://tests/test_battle.gd` | 전투 규칙·승패·UI·화면 이동 검증 |

기존 CharacterUnit에 표시 이름과 개인 쿨다운, `begin_turn()`을 추가했습니다. 기존 캐릭터·스킬 Resource를 그대로 사용합니다. `project.godot`의 Main Scene, 야영지의 전투 시작 버튼, 루트의 실행/테스트 스크립트도 갱신했습니다.

## 4. 코드와 핵심 계약

전체 실행 코드는 실제 프로젝트 파일에 생략 없이 작성되어 있습니다.

- [BattleManager.gd](../scripts/battle/BattleManager.gd)
- [TurnManager.gd](../scripts/battle/TurnManager.gd)
- [DamageCalculator.gd](../scripts/battle/DamageCalculator.gd)
- [TargetRules.gd](../scripts/battle/TargetRules.gd)
- [EnemyData.gd](../scripts/characters/EnemyData.gd), [EnemyUnit.gd](../scripts/characters/EnemyUnit.gd)
- [BattleScene.gd](../scripts/battle/BattleScene.gd)
- [BattleUI.gd](../scripts/ui/BattleUI.gd), [CombatantView.gd](../scripts/ui/CombatantView.gd)
- [자동 검증 전체 코드](../tests/test_battle.gd)

**전투 상태:** `IDLE → PLAYER_INPUT 또는 ENEMY_TURN → RESOLVING → 다음 행동 또는 FINISHED`. 입력 가능한 상태에서만 플레이어의 요청을 받습니다. 스킬 소유권·비용·쿨다운·대상이 유효한지 먼저 검사하고 비용을 지불합니다. 잘못된 대상, 비용 부족, 재사용 대기 중 클릭, 행동 처리 중 연속 클릭은 상태와 자원을 바꾸지 않습니다. 플레이어 입력은 `player_action()`과 `player_pass()`를 사용합니다.

**턴:** 매 라운드 살아 있는 유닛을 Speed 내림차순으로 정렬합니다. 동률은 등록 순서(아군 배열 → 적 배열)로 고정합니다. 자신의 차례가 오면 쿨다운을 1 줄이고 기력을 최대치 이내에서 1 회복합니다. 사망한 유닛은 큐에 남아 있어도 건너뜁니다. Speed 변경은 다음 라운드부터 반영합니다. 전투당 아군 1–3명, 적 1–5명을 허용하며 동일 유닛 인스턴스 중복은 거부합니다.

**쿨다운:** Resource의 `cooldown=1`은 사용 후 다음 자기 차례 한 번 동안 사용 불가라는 의미입니다. 사용 시 런타임에는 `cooldown + 1`을 저장하고 개인 턴 시작 시 감소합니다. 다단 공격과 광역 공격도 기력 비용·쿨다운은 스킬 한 번에 한 번만 적용합니다. 대기는 공격 없이 턴을 끝내며, 다음 자기 차례에 기력을 다시 회복합니다.

**피해:** 명중 확률은 `clamp(명중 − 회피, 0, 1)`. 각 타격마다 명중과 치명타를 독립 판정합니다. 기본량은 `공격력 × 배율 + 고정값`, 치명타면 1.5배를 적용한 뒤 반올림하고 방어력을 뺍니다. 양수 기본량의 명중 공격은 최소 피해 1, 기본량 0은 피해 0입니다. PHYSICAL/ARCANE/FIRE/RADIANT는 현재 같은 방어 공식을 쓰며 연출만 다르고, 속성 내성은 아직 없습니다. TRUE_DAMAGE는 방어력을 무시하지만 보호막에는 흡수됩니다. 계산된 피해는 CharacterUnit의 보호막 → HP 순서로 적용합니다.

**대상:** 근접 스킬은 살아 있는 적 중 가장 앞선 FormationSlot만, 후열 스킬은 가장 뒤의 FormationSlot만 선택합니다. 해당 열에 여럿이면 그중 선택할 수 있습니다. 사망하면 다음 살아 있는 열이 노출됩니다. 일반 원거리 스킬은 모든 살아 있는 적 중 하나를 고릅니다. ALLY에는 자신도 포함합니다. SELF도 자기 카드를 클릭해 확정합니다. 광역은 강조된 대상 중 하나를 클릭하면 전체, RANDOM_ENEMY는 강조 대상 중 하나를 클릭하면 RNG가 실제 대상을 정합니다.

**적:** EnemyData의 `action_pattern=[0,1,2]`는 Skills 배열의 공격 → 보호막 → 화염병을 반복합니다. 계획한 스킬이 기력나 쿨다운 때문에 불가능하면 배열에서 첫 사용 가능한 스킬을 고르고, 하나도 없으면 대기합니다. 현재/다음 개인 턴의 기력 회복과 쿨다운 감소를 반영해 Intent를 표시합니다. Intent의 공격 수치는 방어·치명타·명중 판정 전 기본량입니다. 공격 대상은 TargetRules가 반환하는 첫 유효 대상입니다.

**Signal:** TurnManager는 `round_started`, `turn_started`, `turn_finished`를 제공합니다. BattleManager는 `changed`, `message_logged`, `action_resolved`, `battle_finished(victory)`와 연출용 `hit_resolved`, `hit_missed`, `shield_granted`를 제공합니다. UI는 상태를 읽고 명령 Signal을 보내며 직접 피해를 적용하지 않습니다. 전투 종료는 한 번만 발생하고 종료 시 AI 타이머를 멈춥니다. 재시작은 씬을 새로 만들어 이전 유닛·타이머·연결을 함께 정리합니다.

스킬의 기존 DAMAGE/SHIELD 효과와 대상 조합은 `.tres`만 추가해서 사용할 수 있습니다. 새로운 상태 효과·패시브·효과 종류를 추가할 때는 그 규칙을 구현하는 별도 로직이 필요합니다. 아이콘·사운드·애니메이션 필드는 정의를 유지하지만 아직 사용하지 않습니다. 현재 연출은 피해 유형별로 코드가 생성합니다. 물리 근접은 베기, 화염은 굵은 불줄기, 비전은 세 갈래 화살, 광휘는 빛기둥이고 보호막은 파동입니다.

## 5. Godot Editor 설정

`project.godot`를 열고 **F5**를 누르면 전투가 시작됩니다. 노드에 필요한 스크립트와 Resource는 `.tscn`에 이미 연결했습니다. Autoload나 Inspector의 추가 수동 Signal 연결은 필요 없습니다.

BattleScene 루트 Inspector에서 수정할 항목:

| 항목 | 기본값 / 의미 |
| --- | --- |
| Party Definitions | Paladin, Rogue, Wizard 순서. 최대 3명 |
| Enemy Definitions | 동일 Soldier Resource 3개. 최대 5명 |
| Action Delay | 0.65초. 행동 피드백 및 적 생각 시간 |
| Battle Seed | -1이면 무작위, 0 이상은 재현 가능한 난수 시드 |

배열 순서는 전열 → 중열 → 후열입니다. 적 4·5번째는 후열을 공유합니다. 실제 화면은 첫 번째 목표인 3 대 3에 맞췄으며, 더 많은 카드나 작은 창에서는 스크롤할 수 있습니다. 전투를 바꾸려면 위 데이터 배열을 편집하며 핵심 코드에 직업명별 조건문을 추가하지 않습니다.

## 6. 실행했을 때 기대되는 결과

Windows 파일 탐색기에서 `C:\Users\ryk01\Documents\ChatGPT\game\Play-Godot.cmd`를 더블클릭합니다. PowerShell에서는 다음을 실행합니다.

```powershell
cd C:\Users\ryk01\Documents\ChatGPT\game
.\Open-Godot.ps1 -Run
```

첫 행동은 시엔(Speed 16), 다음은 엘로웬(12), 고블린 셋(10), 알데릭(8) 순서입니다. 아군은 왼쪽, 적은 오른쪽에 있고 전열 카드가 가운데에 가장 가깝습니다. 금색으로 빛나는 카드는 현재 행동자, 초록빛으로 빛나는 카드는 선택 가능한 대상입니다. 스킬 버튼 → 빛나는 카드 순서로 클릭하세요. 알데릭의 신앙의 방패는 알데릭 자신을 대상으로 선택합니다. 사용 불가능한 스킬 버튼에는 기력 부족 또는 재사용 대기 사유가 표시됩니다. 모험 일지는 최근 60줄을 유지하고 스크롤해서 볼 수 있습니다.

적 전멸 시 승리, 아군 전멸 시 패배가 나타납니다. `전투 재시작`은 새 전투를 시작합니다. `야영지`에서는 기존 캐릭터 상태 테스트를 할 수 있습니다.

## 7. 테스트 방법

```powershell
.\Open-Godot.ps1 -Test
```

테스트 스크립트는 Editor 가져오기 → 기존 캐릭터 검증 → 전투 검증 순서로 실행합니다. Godot가 런타임 오류 후 종료 코드 0을 반환하는 경우도 실패로 판단하도록 출력의 `SCRIPT ERROR`/`ERROR`를 확인합니다.

실제 Godot 4.7.2 검증 결과: 기존 **45개**, 새 전투 **93개**, 총 **138개 통과**. 새 검증에는 명중/치명타/방어, 보호막과 다단 타격, 잘못된 입력의 무효화, 개인 쿨다운, 전열 노출, 적 패턴, 광역/아군/자신/무작위 대상, 최대 8명 큐, 승패, 타이머에 의한 적 자동 행동, UI 조작, 재시작, 야영지 왕복이 포함됩니다. 고정 시드 1–8에서는 공격 위주 전략이 5–6라운드에 승리했습니다. 대기만 하는 전략은 패배까지 진행됩니다. 이는 초기 전투 검증이며 전체 게임 밸런스 확정을 의미하지 않습니다.

렌더링 검증과 실제 화면 캡처:

```powershell
& "$env:LOCALAPPDATA\Godot\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe" --path .\godot --script res://tests/test_battle.gd -- --capture
```

`--capture`에는 `--headless`를 붙이지 않습니다. 결과는 `res://test-output/battle.png`이며 Git에서 제외합니다. 그래픽 화면도 실제 엔진에서 확인했습니다.

수동 검증은 단검 베기로 후열을 직접 선택할 수 없는지, 마법 화살은 후열을 선택할 수 있는지, 급소 찌르기 비용이 한 번만 드는지, 전열 사망 후 다음 적이 노출되는지, 신앙의 방패가 자신에게 적용되는지 확인하면 됩니다.

## 8. 발생할 가능성이 높은 오류

| 현상 | 확인할 내용 |
| --- | --- |
| 여전히 야영지가 먼저 열림 | F6는 현재 씬 실행입니다. F5 또는 실행 파일로 프로젝트를 시작하세요 |
| 새 클래스가 인식되지 않음 | Editor 파일 스캔을 기다리거나 `Open-Godot.ps1 -Test`로 가져오기 실행 |
| 스킬을 눌러도 바로 공격하지 않음 | 초록빛으로 빛나는 대상 카드를 눌러 확정해야 합니다. SELF 스킬도 동일합니다 |
| 고블린 공격량이 예고보다 낮음 | 예고는 방어 전 기본량. 실제 방어·치명타·회피·보호막이 별도로 적용됩니다 |
| 특정 스킬을 다음 차례에 못 씀 | 쿨다운 1은 다음 자기 차례 한 번을 쉬는 규칙입니다 |
| 새 적 데이터가 시작되지 않음 | Skills의 null 슬롯, action_pattern의 잘못된 인덱스, 적 인원 제한 확인 |
| 엔진 경로가 달라짐 | `Open-Godot.ps1 -GodotPath '실제 실행 파일 절대 경로' -Run` 사용 |

## 9. 다음 단계

MVP 2에서는 RunManager와 선형 맵을 추가합니다. `START → Battle → Rest → Battle → Boss`를 따라 이동하고 전투 사이에 파티 HP·획득 자원을 유지하도록 연결합니다. 현재 단계에는 맵, 보상, 장비, 상태 이상, 저장, 보스가 아직 없습니다. 전투 규칙과 UI가 분리되어 있으므로 이 기능들은 현재 전투를 재사용해 확장할 수 있습니다.
