extends SceneTree
## Run: godot --headless --path . -s tests/parser_test.gd

func _init() -> void:
	var cases := [
		["x^2 - y^2", 2.0, 1.0, 3.0], ["2x sin(y)", 1.5, PI / 2, 3.0], ["xy", 2.0, 3.0, 6.0],
		["-x^2", 3.0, 0.0, -9.0], ["2^-1", 0.0, 0.0, 0.5], ["e^(-(x^2+y^2))", 0.0, 0.0, 1.0],
		["ln(e)", 0.0, 0.0, 1.0], ["sqrt(x)", 4.0, 0.0, 2.0], ["1/2", 0.0, 0.0, 0.5],
		["3(x+1)(y-1)", 1.0, 2.0, 6.0], ["sin x cos y", PI / 2, 0.0, 1.0], ["2pi", 0, 0, TAU],
		["abs(x) + max(x, y)", -2.0, 1.0, 3.0], ["x**3", 2.0, 0, 8.0], ["1e-3*x", 1000.0, 0, 1.0],
		["2e", 0, 0, 2 * exp(1.0)], ["xsin(y)", 2.0, PI / 2, 2.0], ["2^3^2", 0, 0, 512.0],
	]
	var fails := 0
	for c in cases:
		var e := MathExpr.compile(c[0], PackedStringArray(["x", "y"]))
		var v := e.eval2(c[1], c[2]) if e.is_valid() else NAN
		var ok := e.is_valid() and is_equal_approx(v, c[3])
		if not ok: fails += 1
		print("%s  %-22s -> %s   [%s] %s" % ["ok  " if ok else "FAIL", c[0], v, e.compiled, e.error])
	for bad in ["", "x +", "(x", "z^2", "sin()", "2 $ x", "max(x)", "x y)"]:
		var e := MathExpr.compile(bad, PackedStringArray(["x", "y"]))
		if e.is_valid(): fails += 1
		print("%s  %-22s error: %s" % ["ok  " if not e.is_valid() else "FAIL", bad, e.error])
	var vec := MathExpr.compile_tuple("(-y, x*max(x, 1), 0)", PackedStringArray(["x", "y", "z"]), 3)
	var ok: bool = vec.error.is_empty() and vec.exprs.size() == 3 and is_equal_approx(vec.exprs[1].evaluate([2.0, 0.0, 0.0]), 4.0)
	if not ok: fails += 1
	print("%s  tuple (-y, x*max(x, 1), 0) %s" % ["ok  " if ok else "FAIL", vec.error])
	for bad in ["(x, y)", "(x, y, q)", "x, y, z, 1"]:
		var r := MathExpr.compile_tuple(bad, PackedStringArray(["x", "y", "z"]), 3)
		if r.error.is_empty(): fails += 1
		print("%s  %-22s error: %s" % ["ok  " if not r.error.is_empty() else "FAIL", bad, r.error])
	var w := MathExpr.compile("R cos(ω t)", PackedStringArray(["t", "R", "w"]))
	ok = w.is_valid() and is_equal_approx(w.evaluate([PI, 2.0, 1.0]), -2.0)
	if not ok: fails += 1
	print("%s  ω alias: %s %s" % ["ok  " if ok else "FAIL", w.compiled, w.error])
	print("failures: ", fails)
	quit(fails)
