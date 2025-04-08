extends TextureRect


# This is just to see freezes more clearly
func _process(delta: float) -> void:
    position = position + 10 * delta * Vector2.ONE
