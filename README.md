# Game

현재 개발 중인 **잔광 항로** Godot 프로젝트는 [`godot/project.godot`](godot/project.godot)에 있습니다.

- `./Open-Godot.ps1`: Godot Editor 열기
- `Play-Godot.cmd` 더블클릭 또는 `./Open-Godot.ps1 -Run`: 3 대 3 전투 실행
- `./Open-Godot.ps1 -Test`: 자동 검증
- [프로젝트 구조와 개발 안내](godot/README.md)
- [MVP 1 · 2단계: 턴제 전투 구현·조작·테스트](godot/docs/MVP1_STEP2.md)

아래는 기존 Unity 프로젝트 안내입니다.

Unity 6.3 (6000.3.11f1) 기반 PC용 3D 프로젝트입니다. 공식 Universal 3D 템플릿(URP)으로 생성했습니다.

## 시작하기

1. `Open-Unity.ps1`을 PowerShell로 실행하거나 Unity Hub에서 이 폴더를 프로젝트로 추가합니다.
2. `Assets/Scenes/SampleScene.unity`를 엽니다.
3. 상단 Play 버튼으로 실행합니다. 현재는 템플릿 기본 장면이며 게임 로직은 아직 없습니다.

## 폴더

- `Assets/Scenes`: 장면
- `Assets/Scripts`: C# 코드
- `Assets/Prefabs`: 재사용 오브젝트
- `Assets/Materials`: 머티리얼
- `Assets/Art`: 모델과 이미지
- `Assets/Audio`: 음악과 효과음
- `Assets/Settings`: 렌더링 설정

## 개발

- Input System과 URP는 템플릿에 포함되어 있습니다.
- `Assets`, `Packages`, `ProjectSettings`와 `.meta` 파일은 Git으로 관리합니다.
- `Library`, `Temp`, `Logs`, `UserSettings`, 빌드 결과는 Git에서 제외합니다.
- Windows 빌드는 File > Build Profiles에서 Windows를 선택합니다.
- 코드 편집기는 Edit > Preferences > External Tools에서 선택할 수 있습니다.

프로젝트 생성 명령 참고: [Unity 공식 문서](https://docs.unity3d.com/6000.3/Documentation/Manual/EditorCommandLineArguments.html)
