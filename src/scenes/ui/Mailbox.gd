extends CanvasLayer

signal completed

@onready var recipient: LineEdit = %Recipient
@onready var message: LineEdit = %Message
@onready var status: Label = %Status
@onready var inbox: VBoxContainer = %Inbox

func _ready() -> void:
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	NetAPI.mailbox_loaded.connect(_show_messages)
	NetAPI.mailbox_result.connect(_show_result)
	%Send.pressed.connect(_send)
	%Refresh.pressed.connect(_fetch)
	message.text_submitted.connect(func(_text): _send())
	%Close.pressed.connect(_close)
	_fetch()

func _send() -> void:
	NetAPI.rpc_id(1, "c2s_mailbox_send", recipient.text, message.text)

func _fetch() -> void:
	NetAPI.rpc_id(1, "c2s_mailbox_fetch")

func _show_result(ok: bool, reason: String) -> void:
	status.text = reason
	status.modulate = Color(0.3, 1.0, 0.4) if ok else Color(1.0, 0.4, 0.4)
	if ok:
		message.clear()

func _show_messages(messages: Array) -> void:
	for child in inbox.get_children(): child.queue_free()
	if messages.is_empty():
		var empty := Label.new(); empty.text = "No letters yet."; inbox.add_child(empty); return
	for entry: Dictionary in messages:
		var row := Label.new()
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.text = "%s: %s" % [entry.get("sender_username", "Unknown"), entry.get("body", "")]
		inbox.add_child(row)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()

func _close() -> void:
	completed.emit()
	queue_free()
