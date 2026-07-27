extends CanvasLayer

signal completed

const STATS_SCENE := preload("res://src/scenes/ui/HarborMasterStats.tscn")
const LEDGER_SCENE := preload("res://src/scenes/ui/HarborLedger.tscn")

const PAGES := [
	"Ahoy, %s. I’m the Harbor Master. The sea pays those who learn her moods.",
	"Move with WASD or the arrow keys. Hold E at the fishing dock to cast, then keep your line steady when something bites.",
	"Worms are honest beginner bait. Better bait and gear improve your chances; inspect your gear notes with [Tab].",
	"Sell catches at the fish shop, then save for rods, bait, and hooks. A broken hook or empty bait pouch ends a fine day quickly.",
	"The casino is a temptation, not a retirement plan. Keep the Harbor Ledger in mind: daily work earns gold too.",
]

var _page := 0
@onready var body: Label = %Body
@onready var next: Button = %Next

func _ready() -> void:
	%Tutorial.pressed.connect(_start_tutorial)
	%Stats.pressed.connect(_open.bind(STATS_SCENE))
	%DailyQuests.pressed.connect(_open.bind(LEDGER_SCENE))
	next.pressed.connect(_advance)
	%Close.pressed.connect(_close)
	%Back.pressed.connect(_show_menu)
	_show_menu()

func _start_tutorial() -> void:
	_page = 0
	%Choices.hide()
	%Back.show()
	next.show()
	_show_page()

func _open(scene: PackedScene) -> void:
	var overlay = scene.instantiate()
	get_parent().add_child(overlay)
	overlay.completed.connect(func(): show())
	hide()

func _show_menu() -> void:
	%Body.text = "The harbor keeps records, secrets, and a fair bit of salt. What can I do for you?"
	%Choices.show()
	%Back.hide()
	next.hide()

func _advance() -> void:
	_page += 1
	if _page >= PAGES.size():
		_show_menu()
	else:
		_show_page()

func _show_page() -> void:
	body.text = PAGES[_page] % GameManager.current_player_name if PAGES[_page].contains("%s") else PAGES[_page]
	next.text = "Finish" if _page == PAGES.size() - 1 else "Next"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

func _close() -> void:
	completed.emit()
	queue_free()
