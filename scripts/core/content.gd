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
		"activity": {"id": "field", "label": "밭일 돕기", "amount": 12.0, "log": "할머니와 씨앗을 두 알씩 심었다."},
	},
	"moru": {
		"name": "모루",
		"titles": ["새로 오신 분", "이웃님", "친구"],
		"lines": [
			"어? 새로 오신 분이에요? 저는 모루예요. 대장간에 있는 그거요!",
			"이웃님! 쐐기 박는 법 알려 드릴까요? 밑에 이렇게 박고…",
			"친구! 이층집 거의 다 됐어요. 저녁에 잔치해요, 잔치!",
		],
		"forgot_hint": "우리 처음 보는 거죠? 근데 왜 이렇게 편하지.",
		"activity": {"id": "party", "label": "잔치하기", "amount": 55.0, "log": "모루네 이층집에서 잔치를 했다.", "evening_only": true, "min_stage": 1},
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
		"activity": {"id": "sit", "label": "옆에 앉아 있기", "amount": 6.0, "log": "구 씨 아저씨 옆에 말없이 앉아 있었다."},
	},
}

const TALK_AMOUNT := 8.0

const FURBALL_LINES := ["왜 또.", "발 조심해.", "…따라와.", "열매 따 먹으면 혼나.", "나 안 졸았어."]
const FURBALL_TIRED_LINE := "나 괜찮아. 진짜야."

const OBJECTS := {
	"hearth": {"name": "화덕", "label": "빛버섯 수프 끓이기", "amount": 10.0, "furball_light": 4.0,
		"log": "빛버섯 수프를 끓였다. 털뭉치가 맛없다며 세 그릇 먹었다."},
	"home": {"name": "내 집", "label": "일찍 자기"},
}

const MORNING_FIRST := "어, 깼네. 좀 더 자지."
const MORNING_NORMAL := "늦잠 잤잖아."
const MORNING_AFTER_RULE := "…공책, 읽어 봐. 네 글씨야."

const RULES := {
	"forget": "아주 좋은 날의 다음 날, 동굴에서 있었던 일을 잊는다.",
}

const GOOD_DAY_MONOLOGUE := "오늘이 제일 좋았다."
const NOTE_TO_SELF := "이걸 읽고 있으면, 너는 나야."


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
