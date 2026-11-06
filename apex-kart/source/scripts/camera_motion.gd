extends RefCounted
## Bounded, critically damped head motion; presentation only, never vehicle physics.
var ready := false
var previous_speed := 0.0
var time := 0.0
var acceleration := 0.0
var lateral := 0.0
var lens := Vector2.ZERO
var pitch_spring := Vector2.ZERO
var roll_spring := Vector2.ZERO
var surface_gain := 0.0
var impact_gain := 0.0
var fov := 0.0
var pitch := 0.0
var roll := 0.0
var offset := Vector3.ZERO
var jitter := Vector3.ZERO
var chase_distance := 0.0
var chase_height := 0.0
static func spring(state: Vector2, target: float, rate: float, dt: float) -> Vector2:
	var difference := state.x - target
	var impulse := state.y + rate * difference
	var decay := exp(-rate * dt)
	return Vector2(target + (difference + impulse * dt) * decay, (state.y - rate * impulse * dt) * decay)
func reset(speed: float) -> void:
	ready = true
	previous_speed = speed
	acceleration = 0.0
	lateral = 0.0
	lens = Vector2.ZERO
	pitch_spring = Vector2.ZERO
	roll_spring = Vector2.ZERO
	surface_gain = 0.0
	impact_gain = 0.0
	fov = 0.0
	pitch = 0.0
	roll = 0.0
	offset = Vector3.ZERO
	jitter = Vector3.ZERO
	chase_distance = 0.0
	chase_height = 0.0
func update(delta: float, speed: float, yaw_rate: float, surface: int, impact: float, strength: float, snap := false) -> void:
	if not ready or snap or delta > 0.25:
		reset(speed)
		return
	var dt := maxf(delta, 0.0)
	if dt == 0.0: return
	var raw_acc := clampf((speed - previous_speed) / dt, -25.0, 15.0)
	previous_speed = speed
	if strength <= 0.0:
		reset(speed)
		return
	time += dt * clampf(22.0+absf(speed)*.75,22.0,55.0)
	acceleration = lerpf(acceleration, raw_acc, 1.0-exp(-dt*5.0))
	lateral = lerpf(lateral, clampf(speed*yaw_rate,-24.0,24.0), 1.0-exp(-dt*6.0))
	var fast := smoothstep(6.0,40.0,absf(speed))
	lens = spring(lens,(9.0*fast+maxf(acceleration,0.0)*.12)*strength,4.5,dt)
	pitch_spring = spring(pitch_spring,clampf(-acceleration*.0018,-.025,.042)*strength,8.0,dt)
	roll_spring = spring(roll_spring,clampf(-lateral*.0022,-.045,.045)*strength,7.0,dt)
	fov = clampf(lens.x,0.0,11.0)
	pitch = pitch_spring.x
	roll = roll_spring.x
	offset = Vector3(clampf(lateral*.00085,-.018,.018),-absf(lateral)*.00018,clampf(acceleration*.0016,-.032,.022))*strength
	chase_distance = (fast*.20+clampf(acceleration*.022,-.24,.22))*strength
	chase_height = -fast*.10*strength
	var surface_target := (0.007 if surface==1 else (0.009 if surface==2 else 0.0))*smoothstep(2.0,15.0,absf(speed))
	surface_gain = lerpf(surface_gain,surface_target,1.0-exp(-dt*18.0))
	impact_gain = maxf(clampf(impact,0.0,1.0)*.018,impact_gain*exp(-dt*13.0))
	var amount := (surface_gain+impact_gain+.0011*fast*fast)*strength
	# Distance-dependent rumble: kerbs get faster as wheel speed increases.
	var phase := time
	jitter = Vector3(sin(phase*.83)*.4,sin(phase)+sin(phase*1.71)*.25,0)*amount
