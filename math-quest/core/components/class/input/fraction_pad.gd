extends SegmentPad
class_name FractionPad

# Fraction answers ("3/4"): top number over bottom number.

func setup(q: Dictionary) -> void:
	separator = "/"
	max_digits = [2, 2]
	placeholders = ["?", "?"]
	stacked = true
	super.setup(q)
