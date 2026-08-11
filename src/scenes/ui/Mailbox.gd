extends CanvasLayer

signal completed

@onready var recipient_search: LineEdit = %RecipientSearch
@onready var recipient_matches: VBoxContainer = %RecipientMatches
@onready var recipient_summary: Label = %RecipientSummary
@onready var message: TextEdit = %Message
@onready var coins: SpinBox = %CoinAmount
@onready var status: Label = %Status
@onready var inbox: VBoxContainer = %Inbox
@onready var preview: RichTextLabel = %LetterPreview
@onready var actions: HBoxContainer = %Actions
@onready var claim: Button = %Claim
var _messages: Array = []
var _selected: Dictionary = {}
var _unread_first := true
var _players: Array[String] = []
var _recipients: Array[String] = []
var _claim_pending := false

func _ready() -> void:
	add_to_group("mailbox_modal")
	ClientSettings.register_ui_scale_target($Center/Panel, Vector2(0.5, 0.5))
	NetAPI.mailbox_loaded.connect(_show_messages)
	NetAPI.mailbox_result.connect(_show_result)
	%Send.pressed.connect(_send)
	%Refresh.pressed.connect(_fetch)
	%Sort.pressed.connect(_toggle_sort)
	%Reply.pressed.connect(_reply)
	%ReplyAll.pressed.connect(_reply_all)
	%Forward.pressed.connect(_forward)
	%Delete.pressed.connect(_delete)
	claim.pressed.connect(_claim)
	%Close.pressed.connect(_close)
	recipient_search.text_changed.connect(_refresh_recipient_matches)
	_set_letter_actions(false)
	message.grab_focus()
	_fetch()

func _send() -> void:
	NetAPI.rpc_id(1, "c2s_mailbox_send", _recipients, message.text, int(coins.value))

func _fetch() -> void:
	NetAPI.rpc_id(1, "c2s_mailbox_fetch")

func _show_result(ok: bool, reason: String) -> void:
	status.text = reason
	status.modulate = Color(0.3, 1.0, 0.4) if ok else Color(1.0, 0.4, 0.4)
	if _claim_pending:
		_claim_pending = false
		_refresh_preview()
	if ok:
		message.clear()
		coins.value = 0

func _show_messages(messages: Array, players: Array) -> void:
	_messages = messages.duplicate(true)
	_players.clear()
	for entry in players:
		var username: String = str(entry.get("username", "")) if entry is Dictionary else str(entry)
		if not username.is_empty() and username != GameManager.current_player_name:
			_players.append(username)
	_claim_pending = false
	if not _selected.is_empty():
		var selected_id := int(_selected.get("id", 0))
		_selected.clear()
		for entry: Dictionary in _messages:
			if int(entry.get("id", 0)) == selected_id:
				_selected = entry
				break
	_refresh_recipients()
	_draw_inbox()
	_refresh_preview()

func _refresh_recipients() -> void:
	recipient_summary.text = "Recipients: %s" % ", ".join(_recipients) if not _recipients.is_empty() else "No recipients selected."
	_refresh_recipient_matches(recipient_search.text)

func _refresh_recipient_matches(query: String) -> void:
	for child in recipient_matches.get_children():
		child.free()
	var needle := query.strip_edges().to_lower()
	if needle.is_empty():
		return
	for username in _players:
		if _recipients.has(username) or not username.to_lower().contains(needle):
			continue
		var result := Button.new()
		result.text = "Add %s" % username
		result.alignment = HORIZONTAL_ALIGNMENT_LEFT
		result.pressed.connect(_add_recipient.bind(username))
		recipient_matches.add_child(result)

func _add_recipient(username: String) -> void:
	if not _recipients.has(username):
		_recipients.append(username)
	recipient_search.clear()
	_refresh_recipients()

func _set_recipients(names: Array) -> void:
	_recipients.clear()
	for value in names:
		var username: String = str(value)
		if _players.has(username) and not _recipients.has(username): _recipients.append(username)
	_refresh_recipients()

func _draw_inbox() -> void:
	for child in inbox.get_children(): child.queue_free()
	var sorted := _messages.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if _unread_first and bool(a.get("read_at", 0)) != bool(b.get("read_at", 0)):
			return int(a.get("read_at", 0)) == 0
		return int(a.get("id", 0)) > int(b.get("id", 0))
	)
	if sorted.is_empty():
		var empty := Label.new(); empty.text = "No letters yet."; inbox.add_child(empty); return
	for entry: Dictionary in sorted:
		var row := Button.new()
		var unread := int(entry.get("read_at", 0)) == 0
		var attachment := "  +%dg" % int(entry.get("coin_amount", 0)) if int(entry.get("coin_amount", 0)) > 0 and int(entry.get("claimed_at", 0)) == 0 else ""
		row.text = "%s%s — %s%s" % ["● " if unread else "", str(entry.get("sender_username", "Unknown")), str(entry.get("body", "")).left(36), attachment]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.modulate = Color(1.0, 0.86, 0.35) if unread else Color(0.8, 0.8, 0.8)
		row.pressed.connect(_select_message.bind(entry))
		inbox.add_child(row)

func _select_message(entry: Dictionary) -> void:
	_selected = entry
	_claim_pending = false
	_refresh_preview()
	NetAPI.rpc_id(1, "c2s_mailbox_mark_read", int(entry.get("id", 0)))
	entry["read_at"] = 1
	_draw_inbox()

func _refresh_preview() -> void:
	if _selected.is_empty():
		preview.clear()
		_set_letter_actions(false)
		return
	var attachment := int(_selected.get("coin_amount", 0))
	preview.text = "[b]From:[/b] %s\n\n%s%s" % [str(_selected.get("sender_username", "Unknown")), str(_selected.get("body", "")), "\n\n[b]Attached:[/b] %d gold" % attachment if attachment > 0 else ""]
	_set_letter_actions(true)
	claim.disabled = _claim_pending or attachment <= 0 or int(_selected.get("claimed_at", 0)) != 0

func _set_letter_actions(show: bool) -> void:
	actions.visible = show
	actions.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	for child in actions.get_children():
		if child is Button: child.visible = show
	claim.disabled = true

func _reply() -> void:
	if _selected.is_empty(): return
	_set_recipients([str(_selected.get("sender_username", ""))])
	message.grab_focus()

func _reply_all() -> void:
	if _selected.is_empty(): return
	var names: Array = [str(_selected.get("sender_username", ""))]
	var copied: Variant = JSON.parse_string(str(_selected.get("recipient_list", "[]")))
	if copied is Array:
		for username in copied:
			if str(username) != GameManager.current_player_name: names.append(username)
	_set_recipients(names)
	message.grab_focus()

func _forward() -> void:
	if _selected.is_empty(): return
	_set_recipients([])
	message.text = "Fwd from %s: %s" % [str(_selected.get("sender_username", "Unknown")), str(_selected.get("body", ""))]
	recipient_search.grab_focus()

func _claim() -> void:
	if _selected.is_empty() or claim.disabled:
		return
	_claim_pending = true
	claim.disabled = true
	NetAPI.rpc_id(1, "c2s_mailbox_claim_coins", int(_selected.get("id", 0)))

func _delete() -> void:
	if not _selected.is_empty(): NetAPI.rpc_id(1, "c2s_mailbox_delete", int(_selected.get("id", 0)))
	_selected.clear()
	_refresh_preview()

func _toggle_sort() -> void:
	_unread_first = not _unread_first
	%Sort.text = "Unread First" if _unread_first else "Newest First"
	_draw_inbox()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	completed.emit()
	queue_free()
