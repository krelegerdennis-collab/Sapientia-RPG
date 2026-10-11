extends RefCounted
class_name PvpConnectCode
## Connect-code: 6 tekens, hardop voor te lezen.
## Alfabet: hoofdletters (medeklinkers) en cijfers, zonder 0, O, 1, I en L.
## Voorbeeldvorm: K7NP2Q. Uniek per hostsessie.


const LENGTH := 6
const ALPHABET := "23456789BCDFGHJKMNPQRSTVWXYZ"


static func generate(rng: RandomNumberGenerator) -> String:
	var out := ""
	var n := ALPHABET.length()
	for _i in LENGTH:
		out += ALPHABET[rng.randi() % n]
	return out


static func parse(raw: String) -> String:
	var text := raw.strip_edges().to_upper()
	if text.length() != LENGTH:
		return ""
	for i in text.length():
		if ALPHABET.find(text[i]) < 0:
			return ""
	return text


static func is_valid(raw: String) -> bool:
	return parse(raw) != ""
