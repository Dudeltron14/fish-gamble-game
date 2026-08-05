extends CanvasLayer

@onready var coins_label: Label    = %CoinsLabel
@onready var equipped_label: Label = %EquippedLabel
@onready var context_hint: Label   = %ContextHint
@onready var bait_warning_label: Label = %WarningLabel
@onready var hook_warning_label: Label = %HookWarningLabel
@onready var chat_input: LineEdit = %ChatInput
@onready var fishing_reward_label: Label = %FishingRewardLabel
@onready var mail_badge: Label = %MailBadge

var _hint_tween: Tween
var _reward_tween: Tween
var _reward_color_tween: Tween
var _reward_token := 0

var _warning_clear_token := 0
var _last_hook_durability := -1
var _last_hook_max := 0
var _has_seen_hook_state := false

func _ready() -> void:
	add_to_group("hud")
	ClientSettings.register_ui_scale_target($TopPanel, Vector2.ZERO)
	ClientSettings.register_ui_scale_target(context_hint, Vector2(0.5, 1.0))
	ClientSettings.register_ui_scale_target(bait_warning_label, Vector2(0.5, 0.0))
	ClientSettings.register_ui_scale_target(hook_warning_label, Vector2(0.5, 0.0))
	ClientSettings.register_ui_scale_target(%SettingsBtn, Vector2(1.0, 0.0))
	ClientSettings.register_ui_scale_target(chat_input, Vector2(0.5, 1.0))
	ClientSettings.register_ui_scale_target(fishing_reward_label, Vector2(0.5, 0.0))
	_style_context_hint()
	_style_warning_label(bait_warning_label)
	_style_warning_label(hook_warning_label)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.zone_hint_changed.connect(_on_zone_hint_changed)
	GameManager.equipped_changed.connect(_refresh_equipped)
	GameManager.owned_changed.connect(_refresh_equipped)
	GameManager.hook_durability_changed.connect(_on_hook_durability_changed)
	GameManager.fishing_result_completed.connect(_hide_warnings_after_fishing_result)
	NetAPI.bait_empty.connect(func(): _show_warning(bait_warning_label, "Bait ran out. Buy or equip more bait."))
	NetAPI.hook_broken.connect(func(): _show_warning(hook_warning_label, "Hook broke. Buy or equip another hook."))
	NetAPI.mailbox_unread_changed.connect(_show_mail_unread)
	%SettingsBtn.pressed.connect(func(): ClientSettings.open(self))
	chat_input.max_length = NetAPI.CHAT_MAX_LENGTH
	chat_input.text_submitted.connect(_send_chat)
	_on_coins_changed(GameManager.current_coins)
	_refresh_equipped()

func _input(event: InputEvent) -> void:
	if not get_tree().get_nodes_in_group("mailbox_modal").is_empty():
		return
	if chat_input.visible:
		if event.is_action_pressed("ui_cancel"):
			chat_input.hide()
			chat_input.release_focus()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		chat_input.show()
		chat_input.grab_focus()
		get_viewport().set_input_as_handled()

func _send_chat(message: String) -> void:
	chat_input.clear()
	chat_input.hide()
	chat_input.release_focus()
	if not message.strip_edges().is_empty() and multiplayer.multiplayer_peer:
		NetAPI.rpc_id(1, "c2s_chat_send", message)

func _on_coins_changed(amount: int) -> void:
	coins_label.text = "Coins: %d" % amount

func _show_mail_unread(count: int) -> void:
	mail_badge.visible = count > 0
	mail_badge.text = "✉  %d unread %s" % [count, "MESSAGE" if count == 1 else "MESSAGES"]

func _on_zone_hint_changed(hint: String) -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	context_hint.text = hint
	context_hint.visible = hint != ""
	if hint.is_empty():
		return
	context_hint.modulate.a = 0.0
	context_hint.scale = Vector2.ONE * 0.92
	_hint_tween = create_tween().set_parallel(true)
	_hint_tween.tween_property(context_hint, "modulate:a", 1.0, 0.12)
	_hint_tween.tween_property(context_hint, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func show_fishing_reward(success: bool, message: String, personal_record: bool) -> void:
	_reward_token += 1
	if _reward_tween and _reward_tween.is_valid(): _reward_tween.kill()
	if _reward_color_tween and _reward_color_tween.is_valid(): _reward_color_tween.kill()
	fishing_reward_label.text = message
	fishing_reward_label.modulate = Color(0.3, 1.0, 0.4) if success else Color(1.0, 0.4, 0.4)
	fishing_reward_label.visible = true
	fishing_reward_label.scale = Vector2.ONE * 0.6
	_reward_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_reward_tween.tween_property(fishing_reward_label, "scale", Vector2.ONE, 0.35)
	if personal_record:
		_reward_color_tween = create_tween().set_loops()
		for color in [Color(1.0, 0.2, 0.2), Color(1.0, 0.9, 0.15), Color(0.2, 1.0, 0.8), Color(0.3, 0.5, 1.0)]:
			_reward_color_tween.tween_property(fishing_reward_label, "modulate", color, 0.12)
	_hide_fishing_reward_after(_reward_token, 9.0 if personal_record else 2.5, personal_record)

func _hide_fishing_reward_after(token: int, delay: float, personal_record: bool) -> void:
	await get_tree().create_timer(delay).timeout
	if token != _reward_token:
		return
	if personal_record and _reward_color_tween and _reward_color_tween.is_valid():
		_reward_color_tween.kill()
	_reward_tween = create_tween()
	_reward_tween.tween_property(fishing_reward_label, "modulate:a", 0.0, 1.0 if personal_record else 0.25)
	await _reward_tween.finished
	if token == _reward_token:
		fishing_reward_label.visible = false

func _on_hook_durability_changed(current: int, max_val: int) -> void:
	if _has_seen_hook_state \
			and _last_hook_durability == 1 \
			and current > _last_hook_durability \
			and max_val == _last_hook_max:
		_show_warning(hook_warning_label, "Hook broke. Next owned hook auto-equipped.")
	_last_hook_durability = current
	_last_hook_max = max_val
	_has_seen_hook_state = true
	_refresh_equipped()

func _refresh_equipped() -> void:
	equipped_label.text = GameManager.get_equipped_summary()

func _style_context_hint() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.04, 0.78)
	style.border_color = Color(0.68, 0.92, 0.70, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	context_hint.add_theme_stylebox_override("normal", style)
	context_hint.add_theme_font_size_override("font_size", 25)

func _style_warning_label(label: Label) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.03, 0.02, 0.84)
	style.border_color = Color(1.0, 0.28, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	label.add_theme_stylebox_override("normal", style)
	label.add_theme_font_size_override("font_size", 22)

func _show_warning(label: Label, message: String) -> void:
	_warning_clear_token += 1
	label.text = message
	label.visible = true

func _hide_warnings_after_fishing_result() -> void:
	if not bait_warning_label.visible and not hook_warning_label.visible:
		return
	_warning_clear_token += 1
	var token := _warning_clear_token
	await get_tree().create_timer(3.0).timeout
	if token == _warning_clear_token:
		bait_warning_label.visible = false
		hook_warning_label.visible = false
