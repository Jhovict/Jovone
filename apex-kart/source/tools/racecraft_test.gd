extends SceneTree
const AI := preload("res://scripts/racecraft.gd")
class Kart extends RefCounted:
	var driver := {"code":"TEST"}
	var racecraft := {}
	var s := 100.0
	var d := 0.0
	var vx := 22.0
	var lane := 0.0
	var pace := 1.0
	var pit_state := 0
	func grip_factor(): return 1.0
class Track extends RefCounted:
	var length := 1000.0
	var hw := 4.5
	var wet := false
	var corner := false
	func line_offset_at(_s): return 2.0 if corner else 0.0
	func speed_at(s): return 18.0 if corner and s>125.0 else 30.0
func _initialize(): call_deferred("run")
func run():
	var track := Track.new()
	var c := Kart.new()
	var front := Kart.new()
	front.s = 110
	front.vx = 16
	var r := AI.decide(c,[c,front],track,.016,true,false)
	assert(r["mode"] == "attack" and absf(r["lane"]) > 1.5)
	var side: float = c.racecraft["side"]
	front.d = .1
	for i in 30: AI.decide(c,[c,front],track,.016,true,false)
	assert(c.racecraft["side"] == side)
	c.racecraft.clear()
	var blocker := Kart.new()
	blocker.s = 104
	blocker.d = -1.85
	r = AI.decide(c,[c,front,blocker],track,.016,true,false)
	assert(r["lane"] > 0.0)
	front.s = 102
	front.d = 0
	r = AI.decide(c,[c,front],track,.016,true,false)
	assert(r["speed"] < front.vx)
	var beside := Kart.new()
	beside.s = c.s
	beside.d = 1.7
	r = AI.decide(c,[c,beside],track,.016,true,false)
	assert(r["lane"] <= .051)
	c.racecraft.clear()
	track.corner = true
	var rear := Kart.new()
	rear.s = 91
	rear.vx = 27
	r = AI.decide(c,[c,rear],track,.016,true,false)
	assert(r["mode"] == "defend")
	for i in 120: AI.decide(c,[c,rear],track,.016,true,false)
	assert(c.racecraft["mode"] != "defend")
	# Wrap-around traffic at the finish line must still trigger safe following.
	c.s = 999
	front.s = 1
	track.corner = false
	r = AI.decide(c,[c,front],track,.016,true,false)
	assert(r["speed"] < front.vx)
	print("RACECRAFT PASS: committed pass, blocked lane, following, overlap, single defence, lap wrap")
	quit()

