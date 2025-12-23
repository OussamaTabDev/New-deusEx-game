# ThrowableDatabase.gd - Manages throwable item resources
extends Node
class_name ThrowableDatabase

@export var throwable_resources: Array[ThrowableResource]

var throwable_list: Dictionary = {}  # throwable_id -> ThrowableResource

func _ready():
	initialize()

func initialize():
	"""Load all throwable resources"""
	for throwable in throwable_resources:
		throwable_list[throwable.throwable_id] = throwable
	
	print("Loaded %d throwables" % throwable_list.size())

func get_throwable(throwable_id: int) -> ThrowableResource:
	"""Get throwable resource by ID"""
	return throwable_list.get(throwable_id)

func has_throwable(throwable_id: int) -> bool:
	"""Check if throwable exists"""
	return throwable_list.has(throwable_id)

func get_all_throwables() -> Dictionary:
	"""Get all throwables"""
	return throwable_list
