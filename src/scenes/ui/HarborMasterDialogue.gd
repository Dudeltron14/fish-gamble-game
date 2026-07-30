extends CanvasLayer

signal completed

const STATS_SCENE := preload("res://src/scenes/ui/HarborMasterStats.tscn")
const LEDGER_SCENE := preload("res://src/scenes/ui/HarborLedger.tscn")
const TYPEWRITER_CHARS_PER_SECOND := 52.0
const WELCOME_PORTRAIT := preload("res://assets/characters/harbor_master_dialogue_welcome.png")
const SKEPTICAL_PORTRAIT := preload("res://assets/characters/harbor_master_dialogue_skeptical.png")
const JACKPOT_PORTRAIT := preload("res://assets/characters/harbor_master_dialogue_jackpot_dollar_eyes_v4.png")
const CASTING_PORTRAIT := preload("res://assets/characters/harbor_master_dialogue_casting.png")
const REELING_PORTRAIT := preload("res://assets/characters/harbor_master_dialogue_reeling.png")

const PAGES := [
	"Ahoy, %s! I’m the Harbor Master: keeper of the docks, the ledger, and several gulls with unpaid debts.",
	"Move with WASD or the arrow keys. Hold E at the fishing dock to cast. Aim with confidence; the ocean cannot tell whether you meant that.",
	"When the bobber twitches, keep your reel steady and bring that catch home. Pull too hard and the fish gets the last laugh—very bad manners.",
	"Every catch turns into gold straight away—no hauling a damp bucket to market. Worms are honest beginner bait; inspect your gear notes with [Tab].",
	"Spend that gold at the fish shop on better rods, bait, and hooks. A broken hook or empty bait pouch ends a fine day faster than a seagull ends a sandwich.",
	"And BLACKJACK! My favorite game. Cards are fixed before the shoe begins, so the dealer can only disappoint you honestly. Bet like a sailor, not like a lighthouse.",
	"This island keeps secrets beneath its waves—and there are many more shores to explore soon. For now, cast often, mind the fog, and don’t ask why the lighthouse blinks twice.",
]

var _page := 0
var _sub_overlay: Node = null
var _tutorial_active := false
var _typing := false
var _typed_characters := 0.0
@onready var body: Label = %Body
@onready var portrait: TextureRect = $Portrait

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_for_viewport)
	$Panel.gui_input.connect(_on_panel_gui_input)
	%Tutorial.pressed.connect(_start_tutorial)
	%Stats.pressed.connect(_open.bind(STATS_SCENE))
	%DailyQuests.pressed.connect(_open.bind(LEDGER_SCENE))
	%Close.pressed.connect(_close)
	_layout_for_viewport()
	_show_menu()

func _layout_for_viewport() -> void:
	var width := get_viewport().get_visible_rect().size.x
	var compact := width < 1000.0
	$Panel/Margin.add_theme_constant_override("margin_right", 20 if compact else clampi(roundi(width * 0.25), 180, 360))

func _start_tutorial() -> void:
	_page = 0
	_tutorial_active = true
	%Choices.hide()
	_show_page()

func _open(scene: PackedScene) -> void:
	if _sub_overlay != null:
		return
	_sub_overlay = scene.instantiate()
	get_parent().add_child(_sub_overlay)
	if _sub_overlay.has_method("present_with_harbor_master"):
		_sub_overlay.call("present_with_harbor_master")
	_sub_overlay.connect("completed", _close_sub_overlay)
	$Portrait.visible = get_viewport().get_visible_rect().size.x >= 1000.0
	body.hide()
	$Panel/Margin/VBox.hide()

func _close_sub_overlay() -> void:
	_sub_overlay = null
	$Portrait.show()
	body.show()
	$Panel/Margin/VBox.show()
	_show_menu()

func _show_menu() -> void:
	_tutorial_active = false
	_typing = false
	body.show()
	portrait.texture = WELCOME_PORTRAIT
	%Body.text = "The harbor keeps records, secrets, and a fair bit of salt. What can I do for you?"
	%Body.visible_characters = -1
	%Choices.show()

func _advance() -> void:
	_page += 1
	if _page >= PAGES.size():
		_show_menu()
	else:
		_show_page()

func _show_page() -> void:
	body.text = PAGES[_page] % GameManager.current_player_name if PAGES[_page].contains("%s") else PAGES[_page]
	portrait.texture = CASTING_PORTRAIT if _page == 1 else REELING_PORTRAIT if _page == 2 else JACKPOT_PORTRAIT if _page == 5 else SKEPTICAL_PORTRAIT if _page == 6 else WELCOME_PORTRAIT
	_typed_characters = 0.0
	body.visible_characters = 0
	_typing = true

func _process(delta: float) -> void:
	if not _typing:
		return
	_typed_characters = minf(_typed_characters + delta * TYPEWRITER_CHARS_PER_SECOND, body.text.length())
	body.visible_characters = floori(_typed_characters)
	_typing = _typed_characters < body.text.length()

func _advance_tutorial() -> void:
	if _typing:
		_typing = false
		body.visible_characters = -1
		return
	_advance()

func _on_panel_gui_input(event: InputEvent) -> void:
	if not _tutorial_active or not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	_advance_tutorial()
	$Panel.accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _sub_overlay == null:
		_close()

func _close() -> void:
	if _sub_overlay != null and is_instance_valid(_sub_overlay):
		_sub_overlay.queue_free()
	completed.emit()
	queue_free()
