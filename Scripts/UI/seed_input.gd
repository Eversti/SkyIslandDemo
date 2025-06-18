extends LineEdit

var old_text = ""


func _on_text_changed(new_text: String) -> void:
	if new_text.is_empty() or new_text.is_valid_int():
		old_text = text
	else:
		$".".text = old_text
