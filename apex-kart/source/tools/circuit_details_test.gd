extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = root.get_node("Game")
	var Track = load("res://scripts/track.gd")
	var Details = load("res://scripts/circuit_details.gd")
	var checks := 0
	for idx in game.tracks.size():
		var track = Track.new()
		root.add_child(track)
		track.build(game.tracks[idx],"dry",false)
		Details.build(track)
		var stands := 0
		var landmark := false
		for child in track.get_children():
			if child.has_meta("footprint_radius"):
				assert(track._free_at(child.position,float(child.get_meta("footprint_radius")),true))
				checks += 1
			if String(child.name).begins_with("Grandstand"): stands+=1
			if child.name == "CircuitLandmark": landmark=true
		assert(stands>0 and landmark,"Missing scenery on "+game.tracks[idx]["name"])
		print("SCENERY ",idx," stands=",stands," landmark=",landmark)
		track.free()
	print("SCENERY PASS: all 16 tracks; footprints clear=",checks)
	quit()
