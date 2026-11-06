extends RefCounted
const NAMES := ["Agressivo", "Defensivo", "Consistente"]
const PROFILES := [
	{"commit":2.4,"closing":.25,"gap":.32,"defence":5.5,"error":1.3},
	{"commit":1.8,"closing":.65,"gap":.43,"defence":7.0,"error":.85},
	{"commit":2.1,"closing":.50,"gap":.40,"defence":9.0,"error":.55}]
static func index(code: String) -> int: return absi(code.hash()) % 3
static func profile(code: String) -> Dictionary: return PROFILES[index(code)]
static func title(code: String) -> String: return NAMES[index(code)]
