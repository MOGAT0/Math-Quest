extends SegmentPad
class_name TimeInput

# Time answers ("10:55"): hour box + minute box. Works with the clock
# tower station too: dragging its hands calls set_values([h, mm]).

func setup(q: Dictionary) -> void:
	separator = ":"
	max_digits = [2, 2]
	placeholders = ["hh", "mm"]
	stacked = false
	super.setup(q)


## Like setting a digital clock: an hour starting with 2-9 can't take a
## second digit, so jump straight to the minutes.
func _should_advance(index: int, text: String) -> bool:
	if index == 0:
		return text.length() >= 2 or text.to_int() >= 2
	return super._should_advance(index, text)


func set_time(hour: int, minute: int) -> void:
	set_values([str(hour), "%02d" % minute])
