extends Node

const MENU_SCENE := "res://scenes/menu/main_menu.tscn"


func _ready() -> void:
	call_deferred("_open_menu")


func _open_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
