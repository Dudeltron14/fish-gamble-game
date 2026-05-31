extends Node

const BUS_MASTER := "Master"
const BUS_SFX    := "SFX"
const BUS_MUSIC  := "Music"

# ── Music playlists ───────────────────────────────────────────────────────────
# Edit these path arrays to assign tracks to each context.
# Tracks cycle in order; set shuffle = true to randomise.

const PLAYLISTS: Dictionary = {
	"world":   [],   # populated below — fill with AudioStream paths
	"fishing": [],
	"shop":    [],
	"casino":  [],
}

const PLAYLIST_PATHS: Dictionary = {
	"world": [
		"res://assets/music/Harbor Dice.mp3",
		"res://assets/music/Harbor Dice (1).mp3",
		"res://assets/music/Velvet Reel.mp3",
		"res://assets/music/Velvet Reel (1).mp3",
		"res://assets/music/Dockside Dice.mp3",
		"res://assets/music/Dockside Dice (1).mp3",
	],
	"fishing": [
		"res://assets/music/Harbor Dice.mp3",
		"res://assets/music/Harbor Dice (1).mp3",
		"res://assets/music/Velvet Reel.mp3",
		"res://assets/music/Velvet Reel (1).mp3",
		"res://assets/music/Dockside Dice.mp3",
		"res://assets/music/Dockside Dice (1).mp3",
	],
	"shop": [
		"res://assets/music/Harbor Dice.mp3",
		"res://assets/music/Harbor Dice (1).mp3",
		"res://assets/music/Velvet Reel.mp3",
		"res://assets/music/Velvet Reel (1).mp3",
		"res://assets/music/Dockside Dice.mp3",
		"res://assets/music/Dockside Dice (1).mp3",
	],
	"casino": [
		"res://assets/music/Dockside Jackpot.mp3",
		"res://assets/music/Dockside Jackpot (1).mp3",
		"res://assets/music/Jackpot Harbor.mp3",
		"res://assets/music/Jackpot Harbor (1).mp3",
	],
}

@export var shuffle_playlists: bool = false
@export var crossfade_time: float   = 1.5
@export var context_fade_out: float = 0.8

# ── SFX library ───────────────────────────────────────────────────────────────

const SFX_DIR := "res://assets/sfx/"
var _sfx_lib: Dictionary = {}

# ── Internal state ────────────────────────────────────────────────────────────

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

var _current_playlist: Array      = []
var _current_context: String      = ""
var _track_index: int             = 0
var _playlist_loaded: Dictionary  = {}
var _music_vol_linear: float      = 1.0
var _sfx_vol_linear: float        = 1.0

func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.finished.connect(_on_track_finished)
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		_sfx_pool.append(player)

	_preload_playlists()
	_load_sfx()

func _load_sfx() -> void:
	for name: String in [
		"sfx_cast", "sfx_bite", "sfx_reel_tick", "sfx_catch", "sfx_miss",
		"sfx_hook_break", "sfx_bait_empty", "sfx_buy", "sfx_equip",
		"sfx_not_enough_coins", "sfx_menu_open", "sfx_menu_close", "sfx_coins",
		"sfx_card_deal", "sfx_blackjack_win", "sfx_blackjack_lose", "sfx_blackjack_push",
	]:
		var path := SFX_DIR + name + ".wav"
		if ResourceLoader.exists(path):
			_sfx_lib[name] = load(path)

func sfx(name: String) -> void:
	play_sfx(_sfx_lib.get(name))

# ── Playlist system ───────────────────────────────────────────────────────────

func _preload_playlists() -> void:
	for context in PLAYLIST_PATHS:
		var streams: Array = []
		for path: String in PLAYLIST_PATHS[context]:
			if ResourceLoader.exists(path):
				streams.append(load(path))
		_playlist_loaded[context] = streams

func set_music_context(context: String) -> void:
	if context == _current_context:
		return
	# If new context shares the same playlist paths, just relabel — don't restart
	var new_paths: Array = PLAYLIST_PATHS.get(context, [])
	var old_paths: Array = PLAYLIST_PATHS.get(_current_context, [])
	_current_context = context
	if new_paths == old_paths and not _current_playlist.is_empty():
		return
	var playlist: Array = _playlist_loaded.get(context, [])
	if playlist.is_empty():
		stop_music(context_fade_out)
		return
	_current_playlist = playlist.duplicate()
	if shuffle_playlists:
		_current_playlist.shuffle()
	_track_index = 0
	_play_current_track()

func _play_current_track() -> void:
	if _current_playlist.is_empty():
		return
	var stream: AudioStream = _current_playlist[_track_index]
	play_music(stream, crossfade_time * 0.5)

func _on_track_finished() -> void:
	if _current_playlist.is_empty():
		return
	_track_index = (_track_index + 1) % _current_playlist.size()
	_play_current_track()

func skip_track() -> void:
	if _current_playlist.is_empty():
		return
	stop_music(crossfade_time * 0.5)
	await get_tree().create_timer(crossfade_time * 0.5).timeout
	_track_index = (_track_index + 1) % _current_playlist.size()
	_play_current_track()

# ── Core music controls ───────────────────────────────────────────────────────

func play_music(stream: AudioStream, fade_in: float = 0.5) -> void:
	if _music_player.playing and _music_player.stream == stream:
		return
	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, fade_in)

func stop_music(fade_out: float = 0.5) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
	tween.tween_callback(_music_player.stop)

# ── SFX ───────────────────────────────────────────────────────────────────────

func set_music_volume(linear: float) -> void:
	_music_vol_linear = clampf(linear, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(maxf(_music_vol_linear, 0.0001))

func set_sfx_volume(linear: float) -> void:
	_sfx_vol_linear = clampf(linear, 0.0, 1.0)
	var db := linear_to_db(maxf(_sfx_vol_linear, 0.0001))
	for player: AudioStreamPlayer in _sfx_pool:
		player.volume_db = db

func play_sfx(stream: AudioStream) -> void:
	if stream == null:
		return
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(maxf(_sfx_vol_linear, 0.0001))
			player.play()
			return

func set_volume(bus: String, volume_db: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, volume_db)
