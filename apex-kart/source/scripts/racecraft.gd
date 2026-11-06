extends RefCounted
## Decisions persist across frames; all speed changes remain within the vehicle physics.
static func decide(c, cars: Array, track, dt: float, running: bool, random_errors := true) -> Dictionary:
	var style := preload("res://scripts/rival_style.gd").profile(String(c.driver.get("code", "JOG")))
	var mem: Dictionary = c.racecraft
	if mem.is_empty():
		mem.merge({"hold": 0.0, "cooldown": 0.0, "side": 0.0, "mode": "line", "mistake": 0.0, "error_clock": 18.0 + float(c.get_instance_id() % 23)})
	for timer in ["hold", "cooldown", "mistake"]:
		mem[timer] = maxf(0.0, float(mem[timer]) - dt)
	var lim: float = maxf(0.5, track.hw - 0.95)
	var ideal: float = track.line_offset_at(c.s)
	var spd: float = absf(c.vx)
	var vt: float = track.speed_at(c.s + spd * 0.25) * c.pace * sqrt(c.grip_factor())
	var ahead = null
	var behind = null
	var front_gap := 30.0
	var rear_gap := 16.0
	var overlap := false
	var neighbors: Array = []
	for other in cars:
		if other == c or other.pit_state != 0: continue
		var gap: float = fposmod(other.s - c.s + track.length * 0.5, track.length) - track.length * 0.5
		if absf(gap) > 30.0: continue
		neighbors.append([other, gap])
		if absf(gap) < 3.2: overlap = true
		if gap > 0.0 and gap < front_gap and absf(other.d - c.d) < 1.5:
			ahead = other
			front_gap = gap
		if gap < -3.2 and -gap < rear_gap and absf(other.d - c.d) < 2.8:
			behind = other
			rear_gap = -gap
	var target := clampf(ideal + c.lane, -lim, lim)
	if float(mem["hold"]) <= 0.0:
		mem["mode"] = "line"
		if ahead != null and front_gap < 20.0 and vt > absf(ahead.vx) + float(style["closing"]):
			var best_score := -INF
			var choice := 0.0
			for side in [-1.0, 1.0]:
				var lane: float = ahead.d + side * 1.85
				if absf(lane) > lim: continue
				var clear := true
				for pair in neighbors:
					if pair[0] == ahead: continue
					if absf(float(pair[1])) < 12.0 and absf(float(pair[0].d) - lane) < 1.65: clear = false
				if not clear: continue
				var score := -absf(lane - c.d) * 0.6 - absf(lane - track.line_offset_at(c.s + 35.0)) * 0.25
				if score > best_score:
					best_score = score
					choice = side
			if choice != 0.0:
				mem["side"] = choice
				mem["hold"] = float(style["commit"])
				mem["mode"] = "attack"
				mem["lane"] = clampf(ahead.d + choice * 1.85, -lim, lim)
		elif behind != null and not overlap and float(mem["cooldown"]) <= 0.0 and rear_gap > 6.0 and absf(behind.vx) > spd + 0.8 and track.speed_at(c.s + 35.0) < vt * 0.95:
			# A single early defensive move; never react across a kart already alongside.
			mem["mode"] = "defend"
			mem["hold"] = 1.5
			mem["cooldown"] = float(style["defence"])
			mem["lane"] = clampf(track.line_offset_at(c.s + 35.0) * 0.55, -lim, lim)
	if mem["mode"] != "line": target = float(mem.get("lane", ideal))
	else: target = ideal
	# Preserve a lane for side-by-side cars, including through the next corner.
	for pair in neighbors:
		var other = pair[0]
		var gap: float = pair[1]
		if absf(gap) < 4.0:
			var side := signf(c.d - float(other.d))
			if side == 0.0: side = -1.0 if c.get_instance_id() < other.get_instance_id() else 1.0
			if side > 0.0: target = maxf(target, float(other.d) + 1.65)
			else: target = minf(target, float(other.d) - 1.65)
		if gap > 0.0 and gap < 4.0 + spd * float(style["gap"]) and absf(float(other.d) - c.d) < 1.45:
			vt = minf(vt, maxf(0.0, absf(other.vx) + (gap - 3.3) * 0.65))
	# Small recoverable errors only in clear traffic: a lifted throttle / wider exit.
	if running and random_errors and not overlap and ahead == null:
		mem["error_clock"] = float(mem["error_clock"]) - dt
		if float(mem["error_clock"]) <= 0.0:
			mem["error_clock"] = randf_range(25.0, 65.0)
			if randf() < clampf((1.25 - c.pace) * float(style["error"]) * (1.8 if track.wet else 1.0), 0.08, 0.5):
				mem["mistake"] = 1.3
	if float(mem["mistake"]) > 0.0:
		vt *= 0.92
		target += sin(float(mem["mistake"]) / 1.3 * PI) * 0.30
	return {"speed": maxf(0.0, vt), "lane": clampf(target, -lim, lim) - ideal, "mode": mem["mode"]}
