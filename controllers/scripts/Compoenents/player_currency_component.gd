class_name PlayerCurrencyComponent
extends Node

## Manages different currency types (coins, gems, credits, etc.)
## Usage: Add as child node to Player, then add CogitoCurrency nodes as children

signal currency_changed(currency_name: String, old_value: float, new_value: float)

@export var is_logging: bool = false

var player_currencies: Dictionary = {}

func _ready():
	await get_tree().process_frame
	_setup_currencies()

func _setup_currencies():
	# Find all CogitoCurrency children
	for currency in find_children("", "CogitoCurrency", false):
		player_currencies[currency.currency_name] = currency
		_log("Cogito Currency found: " + currency.currency_name)

func increase_currency(currency_name: String, value: float) -> bool:
	var currency = player_currencies.get(currency_name)
	if not currency:
		_log("Increase currency: Currency '" + currency_name + "' not found")
		return false
	
	var old_value = currency.current_value
	currency.add(value)
	currency_changed.emit(currency_name, old_value, currency.current_value)
	return true

func decrease_currency(currency_name: String, value: float) -> bool:
	var currency = player_currencies.get(currency_name)
	if not currency:
		_log("Decrease currency: " + currency_name + " - Currency not found")
		return false
	
	if currency.current_value < value:
		_log("Not enough " + currency_name)
		return false
	
	var old_value = currency.current_value
	currency.subtract(value)
	currency_changed.emit(currency_name, old_value, currency.current_value)
	return true

func get_currency_value(currency_name: String) -> float:
	var currency = player_currencies.get(currency_name)
	if currency:
		return currency.current_value
	return 0.0

func has_currency(currency_name: String, amount: float) -> bool:
	var currency = player_currencies.get(currency_name)
	if not currency:
		return false
	return currency.current_value >= amount

func _log(message: String):
	if is_logging:
		print("[PlayerCurrencyComponent] ", message)