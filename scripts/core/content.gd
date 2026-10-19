class_name Content
extends RefCounted
## 대사와 활동 데이터. 원작 1장(1~10화)을 바탕으로 한다.
## 대사를 고칠 때는 이 파일만 고치면 된다.

const NPCS := {
	"halmeoni": {
		"name": "달래 할머니",
		"titles": ["새로 온 분", "호박 좋아하는 분", "아가"],
		"lines": [
			"어서 와요. 새로 온 분이지? 호박 좋아해요?",
			"또 왔네, 호박 좋아하는 분. 오늘은 씨앗을 두 알씩 심을 거야.",
			"아가 왔니. 손 좀 빌려 주련?",
		],
		"forgot_hint": "이상하지. 처음 보는 얼굴인데, 손이 먼저 반가워하네.",
	},
	"moru": {
		"name": "모루",
		"titles": ["새로 오신 분", "이웃님", "친구"],
		"lines": [
			"어? 새로 오신 분이에요? 저는 모루예요. 대장간에 있는 그거요!",
			"이웃님! 쐐기 박는 법 알려 드릴까요? 밑에 이렇게 박고…",
			"친구! 오늘도 왔네요. 망치 소리 들렸죠?",
		],
		"forgot_hint": "우리 처음 보는 거죠? 근데 왜 이렇게 편하지.",
	},
	"gussi": {
		"name": "구 씨 아저씨",
		"titles": ["…", "젊은이", "자네"],
		"lines": [
			"……오늘도 하나도.",
			"젊은이 왔나. 오늘도 하나도.",
			"자네가 말한 미끼, 써 봤더니 입질은 오더군.",
		],
		"forgot_hint": "……조심해.",
	},
}

## 행복 게이지에 더해지는 양. 같은 일을 하루에 반복하면 절반씩 준다.
## 평범한 날을 다 채워도 100에 닿지 않고, 큰일(잔치·호박·첫 물고기) 하나가 있어야 넘친다.
const GAIN := {
	"talk": 6.0, "sit": 5.0, "field_help": 8.0, "give_wood": 3.0, "water": 5.0,
	"post": 1.0, "cook": 8.0, "furball": 3.0, "fish": 5.0,
	"party": 60.0, "harvest": 60.0, "first_fish": 60.0,
}

## 큰일: 원작 1장에서 '다음 날 잊은' 날들
const BIG_LOGS := {
	"party": "모루의 이층집이 다 지어져서 잔치를 했다.",
	"harvest": "가장 큰 호박 딴 날. 할머니가 호박죽을 쑤었다.",
	"first_fish": "구 씨 아저씨가 물고기를 잡은 날. 「있다더니, 진짜 있었구나.」",
}

const FURBALL_LINES := ["왜 또.", "발 조심해.", "…따라와.", "열매 따 먹으면 혼나.", "나 안 졸았어."]
const FURBALL_TIRED_LINE := "나 괜찮아. 진짜야."

const MORNING_FIRST := "어, 깼네. 좀 더 자지."
const MORNING_NORMAL := "늦잠 잤잖아."
const MORNING_AFTER_RULE := "…공책, 읽어 봐. 네 글씨야."

const RULES := {
	"forget": "아주 좋은 날의 다음 날, 동굴에서 있었던 일을 잊는다.",
	"hands": "잊어도 손에 익은 것과 내가 만든 것은 남는다.",
	"selves": "빈집은 이전의 내가 지은 집이다. 이번이 처음이 아니었다.",
	"hurt": "두 번째 나는 겁이 나서 나무 뿌리를 파헤쳤다. 그래서 털뭉치가 작아졌다.",
	"first": "첫 번째 나가 망각의 규칙을 알아냈고, 털뭉치에게 이름을 지어 주었다.",
	"counting": "금은 이전의 나들이 이 동굴에서 산 날이다. 털뭉치는 나 대신 날을 세어 왔다.",
}

const FAINT_TEXT := "등불이 꺼졌다. 차가운 것이 다리를 감았다…\n\n눈을 뜨니 나무 아래였다. 털뭉치가 어둠 속까지 들어와 나를 끌고 나왔다고 했다.\n털뭉치의 털 끝이 조금 투명해져 있었다."

const GOOD_DAY_MONOLOGUE := "오늘이 제일 좋았다."
const NOTE_TO_SELF := "이걸 읽고 있으면, 너는 나야."
const FORGOT_BANNER := "내 글씨다. 그런데 하나도 기억나지 않는다."

## 빛 밖의 빈집 (원작 2~3장). 이전의 내가 지은 집들이다.
## spots: 살필 곳. requires 가 있으면 그 단서들을 먼저 찾아야 보인다.
const HOUSES := {
	"house_east": {
		"name": "동쪽 빈집", "pos": Vector2(1080, 160),
		"intro": "창문이 나무 쪽으로 나 있다. 문 왼편 어깨 높이에 고리가 있다. 손이 먼저 그 고리를 찾았다.",
		"spots": [
			{"id": "e_tally", "label": "벽 살피기", "clue": "e_tally",
				"text": "벽에 금이 빼곡하다. 세어 보니 마흔세 개. 털뭉치가 뿌리에 긋는 금과 꼭 닮았다."},
			{"id": "e_chair", "label": "작은 의자 살피기", "clue": "e_chair",
				"text": "다리 하나가 짧아 쐐기를 박아 두었다. 밑에 박고, 엄지로 꾹. 모루가 알려 준 방법 그대로다."},
			{"id": "e_pencil", "label": "창틀 살피기", "clue": "e_pencil",
				"text": "창틀에 몽당연필이 놓여 있다. 깎은 자국이 주머니 속 내 연필과 똑같다."},
			{"id": "e_box", "label": "들뜬 바닥판 들어 보기", "clue": "e_box", "requires": ["e_tally", "e_pencil"],
				"text": "바닥판 아래에 상자가 있다. 뚜껑에 삐뚤빼뚤한 두 글자 — 내 이름이다.\n안에는 지도와 편지.\n「이걸 찾았으면, 너는 나야. 이번엔 네가 끝내.」"},
		],
	},
	"house_mid": {
		"name": "버섯숲 길 빈집", "pos": Vector2(-1080, 690),
		"intro": "문이 반쯤 열려 있다. 안은 엉망이다. 누군가 화가 났거나, 아주 무서웠던 것 같다.",
		"spots": [
			{"id": "m_bottles", "label": "바닥 살피기", "clue": "m_bottles",
				"text": "병이 열 개 넘게 깨져 있다. 찢긴 종이 조각에 「왜」, 「말 안 했」."},
			{"id": "m_hand", "label": "벽 살피기", "clue": "m_hand",
				"text": "벽에 흙 묻은 손자국이 있다. 대 보니 내 손과 크기가 같다. 금은 스물두 개."},
			{"id": "m_note", "label": "창틀 홈 살피기", "clue": "m_note",
				"text": "창틀 홈에 접힌 쪽지.\n「미안해. 내가 너를 작게 만들었어.」\n아래에 다른 글씨로 「다음의 나에게. 조르지 마.」"},
		],
	},
	"house_west": {
		"name": "빨간 문 빈집", "pos": Vector2(-1500, -260),
		"intro": "빨간 칠이 바랜 문. 서툴게 지었지만 튼튼하다. 가장 오래된 집 같다.",
		"spots": [
			{"id": "w_paper", "label": "벽에 붙은 종이 읽기", "clue": "w_paper",
				"text": "「알아낸 것. 좋은 날 다음 날 잊는다. 아주 좋은 날.」\n내 글씨다."},
			{"id": "w_tally", "label": "벽의 금 세기", "clue": "w_tally",
				"text": "금이 아흔여섯 개. 첫 금 옆에 둥근 홈이 파여 있다. 털뭉치의 뿌리에도 같은 홈이 있었다."},
			{"id": "w_chair", "label": "빨간 의자 살피기", "clue": "w_chair",
				"text": "짧은 다리에 돌을 괸 빨간 의자. 깔개 밑 종이에 「이름이 없대서 털뭉치라고 불렀다.」"},
		],
	},
}

## 단서의 짧은 이름 (공책에 적히는 말)
const CLUES := {
	"e_tally": "동쪽 집 벽의 금 43개", "e_chair": "쐐기 박은 작은 의자", "e_pencil": "나와 같은 몽당연필",
	"e_box": "내 이름이 새겨진 상자와 편지",
	"m_bottles": "깨진 병과 찢긴 종이", "m_hand": "내 손과 같은 흙 손자국", "m_note": "「미안해」 쪽지",
	"w_paper": "빨간 문 집의 '알아낸 것'", "w_tally": "금 96개와 둥근 홈", "w_chair": "빨간 의자와 털뭉치의 이름",
}

## 단서 잇기: 이 단서들을 함께 고르면 규칙이 확정된다
const LINKS := [
	{"rule": "selves", "clues": ["e_tally", "e_pencil", "e_box"]},
	{"rule": "hurt", "clues": ["m_hand", "m_note"]},
	{"rule": "first", "clues": ["w_paper", "w_chair"]},
	{"rule": "counting", "clues": ["e_tally", "w_tally"]},
]

const SPOT_NAMES := {
	"tree": "등불나무", "hearth": "화덕", "home": "내 집", "field": "할머니 밭", "pond": "연못",
}


## 받침에 맞는 조사를 붙인다. josa("모루", "와", "과") -> "모루와"
static func josa(word: String, without_final: String, with_final: String) -> String:
	if word.is_empty():
		return word
	var code := word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return word + without_final
	return word + (with_final if (code - 0xAC00) % 28 != 0 else without_final)


static func npc_title(id: String, stage: int) -> String:
	return NPCS[id].titles[clampi(stage, 0, 2)]


static func npc_line(id: String, stage: int) -> String:
	return NPCS[id].lines[clampi(stage, 0, 2)]
