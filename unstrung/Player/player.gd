extends CharacterBody2D

@onready var head_ray: RayCast2D = $HeadRayCast2D
@onready var body_ray: RayCast2D = $BodyRayCast2D
@onready var up_ray: RayCast2D   = $UpRayCast2D
@onready var goal_ray: RayCast2D = $GoalRayCast2D
@onready var crack_ray: RayCast2D = $CrackRayCast2D
@onready var jump_check_ray: RayCast2D = $jump_check_ray

@onready var pivot: Node3D = $visual/SubViewport/World3D/PuppetPivot
@onready var anim: AnimationPlayer = \
$visual/SubViewport/World3D/PuppetPivot.get_child(0).get_node("AnimationPlayer")
@onready var body_shape: CollisionShape2D = $CollisionShape2D

const SPEED := 9500.0
const CRAWL_SPEED_MULT := 0.4
const JUMP_VELOCITY := -510.0

var do_jump := false
var do_run := true
var stop := false
var is_crawling := false

var is_turning := false
var turn_lock := false

var is_decelerating := false
const DECEL_FACTOR := 0.19

var turn_anim_playing := false

var dir := 1

var normal_height := 0.0
var crawl_height := 0.0

var stand_clear_timer := 0.0
const STAND_CLEAR_TIME := 0.3

var body_only_timer := 0.0
const BODY_ONLY_JUMP_TIME := 0.2

var last_x := 0.0
var stuck_timer := 0.0
const STUCK_TIME := 1.3
const STUCK_EPS := 1.0

var flip_cd := 0.0
const FLIP_CD_TIME := 0.3

var base_y := 0.0


func _ready():
	var shape := body_shape.shape as RectangleShape2D
	normal_height = shape.size.y
	crawl_height = normal_height * 0.5
	up_ray.enabled = false

	base_y = pivot.rotation.y
	anim.play("still_walk")


func _physics_process(delta: float) -> void:
	if not GlobalVariables.is_actors_locked:

		if flip_cd > 0.0:
			flip_cd -= delta

		update_fsm(delta)
		apply_actions(delta)

		if is_decelerating:
			velocity.x *= DECEL_FACTOR
			if abs(velocity.x) < 5:
				velocity.x = 0
				is_decelerating = false

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()

		update_animation()

		if abs(global_position.x - last_x) < STUCK_EPS:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
		last_x = global_position.x

		if flip_cd <= 0.0 and stuck_timer >= STUCK_TIME and not is_turning and not turn_lock:
			start_turn()

		if is_crawling:
			enter_crawl()
			handle_stand_check(delta)
		else:
			exit_crawl()
	elif GlobalVariables.is_system_lock:
		if not is_on_floor():
			velocity += get_gravity() * delta
			move_and_slide()



func update_animation():
	if is_turning:
		return

	if turn_anim_playing:
		return

	if is_crawling:
		if anim.current_animation != "crawl":
			anim.play("crawl")
		return

	if not is_on_floor():
		if anim.current_animation != "run_jump":
			anim.play("run_jump")
		return

	if abs(velocity.x) > 10:
		if anim.current_animation != "run":
			anim.play("run", -1, 1.45)
	else:
		if anim.current_animation != "still_walk":
			anim.play("still_walk")


func update_fsm(delta: float) -> void:
	do_run = true
	do_jump = false
	stop = false

	if is_turning:
		do_run = false
		do_jump = false
		stop = true
		return

	if head_ray.is_colliding() and !body_ray.is_colliding():
		is_crawling = true
		stand_clear_timer = 0.0
		up_ray.enabled = true

	if body_ray.is_colliding() and !head_ray.is_colliding():
		body_only_timer += delta
		if body_only_timer >= BODY_ONLY_JUMP_TIME:
			do_jump = true
			return
	else:
		body_only_timer = 0.0

	if !is_crawling and head_ray.is_colliding() and body_ray.is_colliding() and jump_check_ray.is_colliding():
		is_decelerating = true

		if not turn_anim_playing:
			anim.play("run_turn" ,-1 ,2)
			turn_anim_playing = true

		do_jump = false
		return

	if not (head_ray.is_colliding() and body_ray.is_colliding()):
		turn_lock = false

	if !is_crawling and head_ray.is_colliding() and body_ray.is_colliding() and !jump_check_ray.is_colliding():
		do_jump = true
		return

	if crack_ray.is_colliding() and !goal_ray.is_colliding():
		do_run = false
		do_jump = false
		stop = true
		return

	if goal_ray.is_colliding() and !crack_ray.is_colliding():
		do_jump = true
		return


func apply_actions(delta: float) -> void:
	if stop:
		stop_run()
		return

	if do_run:
		run(delta)

	if do_jump:
		jump()


func run(delta: float) -> void:
	var speed = SPEED
	if is_crawling:
		speed *= CRAWL_SPEED_MULT
	velocity.x = speed * delta * dir


func stop_run() -> void:
	velocity.x = 0


func jump() -> void:
	if is_on_floor() and !is_crawling:
		velocity.y = JUMP_VELOCITY


func start_turn():
	if is_turning:
		return

	is_turning = true
	turn_anim_playing = false
	is_decelerating = false

	velocity.x = 0

	dir *= -1

	var rays: Array[RayCast2D] = [head_ray, body_ray, goal_ray, crack_ray, jump_check_ray]
	for r in rays:
		r.position.x = -r.position.x
		r.target_position.x = -r.target_position.x

	pivot.rotation.y = base_y + (PI if dir == -1 else 0.0)

	var d := get_physics_process_delta_time()
	velocity.x = SPEED * d * dir

	stuck_timer = 0.0
	flip_cd = FLIP_CD_TIME
	is_turning = false


func enter_crawl():
	var shape := body_shape.shape as RectangleShape2D
	if shape.size.y == crawl_height:
		return

	shape.size.y = crawl_height
	body_shape.position.y = (normal_height - crawl_height) * 0.5


func exit_crawl():
	var shape := body_shape.shape as RectangleShape2D
	if shape.size.y == normal_height:
		return

	shape.size.y = normal_height
	body_shape.position.y = 0
	up_ray.enabled = false


func handle_stand_check(delta: float):
	if !up_ray.is_colliding():
		stand_clear_timer += delta
		if stand_clear_timer >= STAND_CLEAR_TIME:
			is_crawling = false
			stand_clear_timer = 0.0
	else:
		stand_clear_timer = 0.0
