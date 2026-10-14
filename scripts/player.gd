class_name Player
extends RefCounted

var idx: int = 0
var name: String = ""
var team: int = 0
var is_human: bool = false
var color: Color = Color.WHITE
var res: Dictionary = {}
var age: int = 0
var aging: bool = false
var age_left: float = 0.0
var pop: int = 0
var pop_cap: int = 0
var reserved: int = 0
var alive: bool = true
var start_tile: Vector2i = Vector2i.ZERO
var difficulty: int = 1
var gather_mult: float = 1.0
var last_alarm: float = -100.0
var kills: int = 0
var losses: int = 0
var gathered: Dictionary = {"food": 0, "wood": 0, "gold": 0}
