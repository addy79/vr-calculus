class_name MathExpr
extends RefCounted
## A user-typed math function such as "x^2 - y^2" or "2x sin(y)".
## A small recursive-descent parser turns the text into a Godot Expression
## string, adding what Expression lacks: ^ for powers, implicit multiplication
## (2x, x y, 3sin(x)), ln, pi and e. Use compile(), then check `error`.

## Name -> [Godot function, argument count].
const FUNCTIONS := {
	"sin": ["sin", 1], "cos": ["cos", 1], "tan": ["tan", 1],
	"asin": ["asin", 1], "acos": ["acos", 1], "atan": ["atan", 1],
	"arcsin": ["asin", 1], "arccos": ["acos", 1], "arctan": ["atan", 1],
	"sinh": ["sinh", 1], "cosh": ["cosh", 1], "tanh": ["tanh", 1],
	"sqrt": ["sqrt", 1], "exp": ["exp", 1], "ln": ["log", 1], "log": ["log", 1],
	"abs": ["absf", 1], "floor": ["floor", 1], "ceil": ["ceil", 1], "sign": ["signf", 1],
	"min": ["minf", 2], "max": ["maxf", 2], "atan2": ["atan2", 2],
}
const CONSTANTS := {"pi": "PI", "π": "PI", "e": "2.718281828459045", "tau": "TAU"}

var text := ""
var variables: PackedStringArray
var error := ""
## The generated Godot expression (for debugging).
var compiled := ""

var _expression := Expression.new()
var _tokens: Array[String] = []
var _pos := 0
var _args: Array = []


static func compile(source: String, vars: PackedStringArray) -> MathExpr:
	var expr := MathExpr.new()
	expr.text = source.strip_edges()
	expr.variables = vars
	expr._compile()
	return expr


## Compiles "(a, b, c)" into one MathExpr per component. Returns
## {"exprs": Array[MathExpr], "error": String}.
static func compile_tuple(source: String, vars: PackedStringArray, count: int) -> Dictionary:
	var parts := split_tuple(source)
	var exprs: Array[MathExpr] = []
	if parts.size() != count:
		var example := "(−y, x, 0)" if vars.has("z") else "(cos t, sin t, t/3)"
		return {"exprs": exprs, "error": "Need %d components separated by commas, like %s" % [count, example]}
	for i in count:
		var expr := compile(parts[i], vars)
		if not expr.is_valid():
			return {"exprs": exprs, "error": "Component %d: %s" % [i + 1, expr.error]}
		exprs.append(expr)
	return {"exprs": exprs, "error": ""}


## Splits "(a, b, c)" or "a, b, c" at top-level commas (not those inside max(x, y)).
static func split_tuple(source: String) -> PackedStringArray:
	var s := source.strip_edges()
	# Drop one pair of outer brackets if they enclose everything.
	if s.begins_with("(") and s.ends_with(")"):
		var depth := 0
		var encloses := true
		for i in s.length():
			depth += 1 if s[i] == "(" else (-1 if s[i] == ")" else 0)
			if depth == 0 and i < s.length() - 1:
				encloses = false
				break
		if encloses:
			s = s.substr(1, s.length() - 2)
	var parts := PackedStringArray()
	var depth := 0
	var start := 0
	for i in s.length():
		if s[i] == "(":
			depth += 1
		elif s[i] == ")":
			depth -= 1
		elif s[i] == "," and depth == 0:
			parts.append(s.substr(start, i - start).strip_edges())
			start = i + 1
	parts.append(s.substr(start).strip_edges())
	return parts


func is_valid() -> bool:
	return error.is_empty()


## Evaluates with values in the same order as `variables`. Returns NAN on
## failure (e.g. sqrt of a negative number gives NAN too).
func evaluate(values: Array) -> float:
	var result: Variant = _expression.execute(values, null, false)
	if _expression.has_execute_failed() or not (result is float or result is int):
		return NAN
	return float(result)


func eval1(a: float) -> float:
	_args.resize(1)
	_args[0] = a
	return evaluate(_args)


func eval2(a: float, b: float) -> float:
	_args.resize(2)
	_args[0] = a
	_args[1] = b
	return evaluate(_args)


func _compile() -> void:
	if text.is_empty():
		error = "Type a function first"
		return
	if not _tokenize():
		return
	_pos = 0
	compiled = _parse_sum()
	if error.is_empty() and _pos < _tokens.size():
		error = "Unexpected '%s'" % _tokens[_pos]
	if not error.is_empty():
		return
	if _expression.parse(compiled, variables) != OK:
		error = _expression.get_error_text()
		return
	# Probe once so typos like an unknown name surface now, not mid-plot.
	var probe := []
	for v in variables:
		probe.append(0.5)
	_expression.execute(probe, null, false)
	if _expression.has_execute_failed():
		error = _expression.get_error_text()


func _tokenize() -> bool:
	var s := text.replace("**", "^").replace("·", "*").replace("×", "*").replace("−", "-") \
			.replace("ω", "w")
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == " " or c == "\t":
			i += 1
		elif c.is_valid_int() or c == ".":
			var start := i
			while i < s.length() and (s[i].is_valid_int() or s[i] == "."):
				i += 1
			# Allow scientific notation like 1e-3, but not "2e" meaning 2·e.
			if i + 1 < s.length() and s[i] == "e" and (s[i + 1].is_valid_int()
					or (s[i + 1] in "+-" and i + 2 < s.length() and s[i + 2].is_valid_int())):
				i += 2
				while i < s.length() and s[i].is_valid_int():
					i += 1
			var number := s.substr(start, i - start)
			if not number.is_valid_float():
				error = "Bad number '%s'" % number
				return false
			_tokens.append(number)
		elif _is_letter(c):
			var start := i
			while i < s.length() and (_is_letter(s[i]) or s[i].is_valid_int()):
				i += 1
			_split_word(s.substr(start, i - start))
		elif c in "+-*/^(),":
			_tokens.append(c)
			i += 1
		else:
			error = "Unexpected character '%s'" % c
			return false
	return true


## Splits glued names like "xy" or "xsin" into known pieces (x, y, sin).
func _split_word(word: String) -> void:
	if FUNCTIONS.has(word) or CONSTANTS.has(word) or variables.has(word):
		_tokens.append(word)
		return
	var i := 0
	while i < word.length():
		var best := ""
		for name: String in FUNCTIONS.keys() + CONSTANTS.keys() + Array(variables):
			if word.substr(i).begins_with(name) and name.length() > best.length():
				best = name
		if best.is_empty():
			best = word[i]  # Unknown: reported by the parser.
		_tokens.append(best)
		i += best.length()


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c == "π"


func _peek() -> String:
	return _tokens[_pos] if _pos < _tokens.size() else ""


func _expect(token: String) -> void:
	if _peek() == token:
		_pos += 1
	elif error.is_empty():
		error = "Missing '%s'" % token if _peek().is_empty() else "Expected '%s' but found '%s'" % [token, _peek()]


## sum := product (('+' | '-') product)*
func _parse_sum() -> String:
	var out := _parse_product()
	while error.is_empty() and _peek() in ["+", "-"]:
		var op := _peek()
		_pos += 1
		out = "(%s %s %s)" % [out, op, _parse_product()]
	return out


## product := unary (('*' | '/' | implicit) unary)*
func _parse_product() -> String:
	var out := _parse_unary()
	while error.is_empty():
		var t := _peek()
		if t == "*" or t == "/":
			_pos += 1
			out = "(%s %s %s)" % [out, t, _parse_unary()]
		elif _starts_factor(t):
			out = "(%s * %s)" % [out, _parse_unary()]
		else:
			break
	return out


## unary := '-' unary | power   (so -x^2 = -(x^2))
func _parse_unary() -> String:
	if _peek() == "-":
		_pos += 1
		return "(-%s)" % _parse_unary()
	if _peek() == "+":
		_pos += 1
		return _parse_unary()
	return _parse_power()


## power := atom ('^' unary)?   (right-associative)
func _parse_power() -> String:
	var base := _parse_atom()
	if error.is_empty() and _peek() == "^":
		_pos += 1
		return "pow(%s, %s)" % [base, _parse_unary()]
	return base


func _parse_atom() -> String:
	var t := _peek()
	if t.is_empty():
		if error.is_empty():
			error = "Expression ends too early"
		return "0"
	_pos += 1
	if t == "(":
		var inner := _parse_sum()
		_expect(")")
		return inner
	if t.is_valid_float():
		return t if "." in t or "e" in t else t + ".0"
	if variables.has(t):
		return t
	if CONSTANTS.has(t):
		return CONSTANTS[t]
	if FUNCTIONS.has(t):
		var spec: Array = FUNCTIONS[t]
		var args := PackedStringArray()
		if _peek() == "(":
			_pos += 1
			args.append(_parse_sum())
			while error.is_empty() and _peek() == ",":
				_pos += 1
				args.append(_parse_sum())
			_expect(")")
		elif spec[1] == 1:
			# sin x, sin 2x: argument without brackets binds to one power term.
			args.append(_parse_power())
		if error.is_empty() and args.size() != spec[1]:
			error = "%s needs %d argument%s" % [t, spec[1], "" if spec[1] == 1 else "s"]
		return "%s(%s)" % [spec[0], ", ".join(args)]
	if error.is_empty():
		if _is_letter(t[0]):
			error = "Unknown name '%s' (use %s)" % [t, ", ".join(variables)]
		else:
			error = "Unexpected '%s'" % t
	return "0"


func _starts_factor(t: String) -> bool:
	return t == "(" or t.is_valid_float() or variables.has(t) or CONSTANTS.has(t) \
			or FUNCTIONS.has(t)
