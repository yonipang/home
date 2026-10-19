# 등불나무 — Claude 작업 규칙

이 저장소는 웹소설 『등불나무』를 게임으로 옮기는 Godot 4 프로젝트다. 코드·데이터·문서는 Claude가 작성하고, 작가(저장소 주인)가 플레이하고 피드백한다. 사용자와는 **한국어**로 대화한다.

## 결정된 방향 (바꾸려면 사용자에게 먼저 묻는다)
- 2D 탑다운, **모바일 세로 우선** (기준 해상도 720×1280, stretch `canvas_items` + aspect `expand`). 이후 PC·콘솔은 같은 내용을 가로 배치로 옮긴다.
- 하루 = 아침·낮·저녁 3구간, **모든 플랫폼 동일하게 8~12분** (`DayClock.DEFAULT_SEGMENT_SECONDS`).
- 이동은 **플로팅 조이스틱**(누른 곳에 나타남), 상호작용은 **대상을 탭**. 화면 위 HUD는 공책 버튼 하나뿐.
- 저장은 잠들 때만. 앱이 백그라운드로 가면 이어 하기용 일시 저장, 불러오면 삭제 (되돌리기 금지).
- 전투 없음. 디자인 기둥: 행복의 역설 · 기록이 곧 진행 · 손이 아는 것 · 서두르면 흩어진다.

## 구조
- `scripts/core/` — 화면과 무관한 규칙. 새 규칙은 여기에 두고 반드시 `tests/`에 테스트를 추가한다.
  - `game_state.gd` (autoload `GameState`): 하루 행동, 하루 마감·망각, 저장
  - `happiness.gd`, `relationships.gd`, `notebook.gd`, `day_clock.gd`
  - `world_state.gd`: 망각해도 남는 것 (물건, 경계 등불, 빛의 원, 이층집·호박·낚시 진행)
  - `content.gd`: 대사·활동 데이터. **대사 수정은 이 파일만.**
- `scripts/village/village.gd` — 마을 그리기(코드 드로잉), 이동, 탭 대상 찾기
- `scripts/ui/` — 조이스틱, 대화창, 공책, 낚시, 하루 마감, 아침 화면. UI는 코드로 만든다 (`UIKit` 헬퍼).
- `scripts/main.gd` — 전체를 묶음 + 개발용 `--smoke`, `--shot` 모드

## 작업할 때
- 수정 후 반드시 실행:
  ```
  godot --headless --import
  godot --headless --script res://tests/run_tests.gd
  godot --headless -- --smoke          # "SMOKE OK"가 나와야 함
  ```
- 화면을 바꿨으면 스크린샷으로 직접 확인한다 (xvfb 필요):
  `xvfb-run -a godot --rendering-driver opengl3 --resolution 720x1280 -- --shot=village --out=/tmp/v.png`
  장면: `village`, `dialogue`, `notebook`, `fishing`, `sleep`, `morning`, `forgot`, `explore`, `house`, `clues`, `walk`(걷는 모습 48장)
- 터치 영역은 최소 88px(720 기준). 선택지는 화면 아래쪽에 둔다.
- 한글 조사는 `Content.josa()`를 쓴다. 글꼴: 본문 Gowun Dodum(KS X 1001 2,350자 부분집합), 공책 손글씨 Nanum Pen Script(원본 그대로 — OFL 예약 이름 때문에 수정 금지).
- `main` 푸시 = GitHub Pages 자동 배포 (https://yonipang.github.io/home/). 테스트가 실패하면 배포되지 않는다.
- 원작 설정(망각 규칙, 인물 말투)을 바꾸는 변경은 사용자 확인 후에만.
- 밸런스 원칙: 평범한 날을 다 채워도 행복 100에 닿지 않고, 큰일(잔치·호박·첫 물고기) 하나가 있어야 넘친다. 성실하게 하면 첫 망각은 3일째쯤 (`--smoke`가 검사).
