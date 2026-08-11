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
const KEEPER_MYSTERIOUS_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_mysterious.png")
const KEEPER_JOYOUS_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_joyous.png")
const KEEPER_CONCERNED_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_concerned.png")
const KEEPER_SMILING_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_smiling.png")
const KEEPER_WINKING_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_winking.png")
const KEEPER_SPOOKY_PORTRAIT := preload("res://assets/characters/lighthouse_keeper_dialogue_spooky.png")

const PAGES := [
	"Ahoy, %s! I’m the Harbor Master: keeper of the docks, the ledger, and several gulls with unpaid debts.",
	"Move with WASD or the arrow keys. Hold E at the fishing dock to cast. Aim with confidence; the ocean cannot tell whether you meant that.",
	"When the bobber twitches, keep your reel steady and bring that catch home. Pull too hard and the fish gets the last laugh—very bad manners.",
	"Every catch turns into gold straight away—no hauling a damp bucket to market. Worms are honest beginner bait; inspect your gear notes with [Tab].",
	"Spend that gold at the fish shop on better rods, bait, and hooks. A broken hook or empty bait pouch ends a fine day faster than a seagull ends a sandwich.",
	"And BLACKJACK! My favorite game. Cards are fixed before the shoe begins, so the dealer can only disappoint you honestly. Bet like a sailor, not like a lighthouse.",
	"This island keeps secrets beneath its waves—and there are many more shores to explore soon. For now, cast often, mind the fog, and don’t ask why the lighthouse blinks twice.",
]
const LIGHTHOUSE_PAGES := [
	"The lamp keeps the rocks honest, %s. I keep the fish honest. Mostly.",
	"At the pier, the harbor fish are forgiving. The lighthouse rocks hide rarer catches, especially after sunset.",
	"The reedbank is calmer water. Try smaller bait there, and watch for schools gathering near the reeds.",
	"Keep the lantern stocked and the night stays friendly. A dark lighthouse makes for very dramatic fishing and terrible paperwork.",
]

var _page := 0
var _sub_overlay: Node = null
var _tutorial_active := false
var _typing := false
var _typed_characters := 0.0
var _event_display := "Fishing events are loading..."
@onready var body: Label = %Body
@onready var portrait: TextureRect = $Portrait

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_for_viewport)
	$Panel.gui_input.connect(_on_panel_gui_input)
	%Tutorial.pressed.connect(_start_tutorial)
	%Stats.pressed.connect(_open.bind(STATS_SCENE))
	%DailyQuests.pressed.connect(_open.bind(LEDGER_SCENE))
	%FishingEvents.pressed.connect(_show_event)
	NetAPI.fishing_event_changed.connect(_on_fishing_event)
	%Close.pressed.connect(_close)
	_layout_for_viewport()
	$Panel/Margin/Name.text = "LIGHTHOUSE KEEPER" if GameManager.current_zone == "LighthouseKeeperZone" else "HARBOR MASTER"
	_show_menu()

func _on_fishing_event(_event_id: String, display_name: String, description: String, seconds_remaining: int) -> void:
	_event_display = "%s\n%s\nTime remaining: %02d:%02d" % [display_name, description, seconds_remaining / 60, seconds_remaining % 60]

func _show_event() -> void:
	_tutorial_active = false
	_typing = false
	portrait.texture = KEEPER_MYSTERIOUS_PORTRAIT if GameManager.current_zone == "LighthouseKeeperZone" else SKEPTICAL_PORTRAIT
	body.text = _event_display
	body.visible_characters = -1
	%Choices.hide()

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
	portrait.texture = KEEPER_SMILING_PORTRAIT if GameManager.current_zone == "LighthouseKeeperZone" else WELCOME_PORTRAIT
	%Body.text = "The lighthouse keeps watch over three fishing grounds. What would you like to know?" if GameManager.current_zone == "LighthouseKeeperZone" else "The harbor keeps records, secrets, and a fair bit of salt. What can I do for you?"
	%Body.visible_characters = -1
	%Choices.show()

func _advance() -> void:
	_page += 1
	if _page >= PAGES.size():
		_show_menu()
	else:
		_show_page()

func _show_page() -> void:
	var pages: Array = LIGHTHOUSE_PAGES if GameManager.current_zone == "LighthouseKeeperZone" else PAGES
	if _page >= pages.size():
		_show_menu()
		return
	body.text = pages[_page] % GameManager.current_player_name if pages[_page].contains("%s") else pages[_page]
	if GameManager.current_zone == "LighthouseKeeperZone":
		var keeper_portraits := [KEEPER_SMILING_PORTRAIT, KEEPER_WINKING_PORTRAIT, KEEPER_JOYOUS_PORTRAIT, KEEPER_CONCERNED_PORTRAIT, KEEPER_SPOOKY_PORTRAIT]
		portrait.texture = keeper_portraits[min(_page, keeper_portraits.size() - 1)]
	else:
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
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _sub_overlay != null and is_instance_valid(_sub_overlay):
		_sub_overlay.queue_free()
	completed.emit()
	queue_free()
