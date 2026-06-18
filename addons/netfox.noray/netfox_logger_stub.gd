class_name NetfoxLogger
extends RefCounted
## Minimal stub so netfox.noray works WITHOUT the netfox core addon. Real netfox
## ships a richer logger; we only need the surface noray.gd touches.

var _name: String = "Noray"

static func _for_noray(name: String) -> NetfoxLogger:
	var l := NetfoxLogger.new()
	l._name = name
	return l

func _fmt(format: String, args: Array) -> String:
	if args.is_empty():
		return format
	return format % args

func info(format: String, args: Array = []) -> void:
	print("[%s] %s" % [_name, _fmt(format, args)])

func debug(_format: String, _args: Array = []) -> void:
	pass

func trace(_format: String, _args: Array = []) -> void:
	pass

func error(format: String, args: Array = []) -> void:
	push_error("[%s] %s" % [_name, _fmt(format, args)])
