extends CharacterBody2D

# =========================
# RAYS
# =========================
@onready var head_ray: RayCast2D = $HeadRayCast2D
@onready var body_ray: RayCast2D = $BodyRayCast2D
@onready var up_ray: RayCast2D   = $UpRayCast2D
@onready var goal_ray: RayCast2D = $GoalRayCast2D
@onready var crack_ray: RayCast2D = $CrackRayCast2D

# =========================
# COLLISION / VISUAL
# =========================
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

# =========================
# CONSTANTS
# =========================
const SPEED := 11000.0
const JUMP_VELOCITY := -520.0

# =========================
# FSM FLAGS
# =========================
var do_jump := false
var do_run := true
var stop := false
var is_crawling := false
var dir := 1

# =========================
# CRAWL SIZE
# =========================
var normal_height := 0.0
var crawl_height := 0.0

# crawl stand safety check
var stand_clear_timer := 0.0
const STAND_CLEAR_TIME := 0.3

# =========================
# BODY-ONLY DELAYED JUMP
# =========================
var body_only_timer := 0.0
const BODY_ONLY_JUMP_TIME := 0.2

# =========================
# STUCK DETECTION
# =========================
var last_x := 0.0
var stuck_timer := 0.0
const STUCK_TIME := 0.5
const STUCK_EPS := 1.0

var flip_cd := 0.0
const FLIP_CD_TIME := 0.3


func _ready():
	var shape := body_shape.shape as RectangleShape2D
	normal_height = shape.size.y
	crawl_height = normal_height * 0.5
	up_ray.enabled = false


func _physics_process(delta: float) -> void:
	if not GlobalVariables.is_actors_locked:
		if flip_cd > 0.0:
			flip_cd -= delta

		update_fsm(delta)
		apply_actions(delta)

		if not is_on_floor():
			velocity += get_gravity() * delta

		move_and_slide()

		# ===== stuck detection =====
		if abs(global_position.x - last_x) < STUCK_EPS:
			stuck_timer += delta
		else:
			stuck_timer = 0.0
		last_x = global_position.x

		if flip_cd <= 0.0 and stuck_timer >= STUCK_TIME:
			flip_direction()

		# ===== volume / crawl =====
		if is_crawling:
			enter_crawl()
			handle_stand_check(delta)
		else:
			exit_crawl()


# =========================
# FSM DECISION
# =========================
func update_fsm(delta: float) -> void:
	do_run = true
	do_jump = false
	stop = false

	# ===== CRAWL ENTER =====
	if head_ray.is_colliding() and !body_ray.is_colliding():
		is_crawling = true
		stand_clear_timer = 0.0
		up_ray.enabled = true

	# ===== BODY ONLY → DELAYED JUMP =====
	if body_ray.is_colliding() and !head_ray.is_colliding():
		body_only_timer += delta
		if body_only_timer >= BODY_ONLY_JUMP_TIME:
			do_jump = true
			return
	else:
		body_only_timer = 0.0

	# ===== WALL → JUMP =====
	if !is_crawling and head_ray.is_colliding() and body_ray.is_colliding():
		do_jump = true

	# ===== GAP =====
	if crack_ray.is_colliding() and !goal_ray.is_colliding():
		do_run = false
		do_jump = false
		stop = true
		return

	if goal_ray.is_colliding() and !crack_ray.is_colliding():
		do_jump = true
		return


# =========================
# ACTION
# =========================
func apply_actions(delta: float) -> void:
	if stop:
		stop_run()
		return

	if do_run:
		run(delta)

	if do_jump:
		jump()


func run(delta: float) -> void:
	velocity.x = SPEED * delta * dir


func stop_run() -> void:
	velocity.x = move_toward(velocity.x, 0, 100)


func jump() -> void:
	if is_on_floor() and !is_crawling:
		velocity.y = JUMP_VELOCITY


# =========================
# CRAWL LOGIC
# =========================
func enter_crawl():
	var shape := body_shape.shape as RectangleShape2D
	if shape.size.y == crawl_height:
		return

	shape.size.y = crawl_height
	body_shape.position.y = (normal_height - crawl_height) * 0.5
	sprite.scale.y = 0.5


func exit_crawl():
	var shape := body_shape.shape as RectangleShape2D
	if shape.size.y == normal_height:
		return

	shape.size.y = normal_height
	body_shape.position.y = 0
	sprite.scale.y = 1.0
	up_ray.enabled = false


func handle_stand_check(delta: float):
	if !up_ray.is_colliding():
		stand_clear_timer += delta
		if stand_clear_timer >= STAND_CLEAR_TIME:
			is_crawling = false
			stand_clear_timer = 0.0
	else:
		stand_clear_timer = 0.0


# =========================
# DIRECTION
# =========================
func flip_direction():
	dir *= -1

	head_ray.target_position.x *= -1
	body_ray.target_position.x *= -1
	goal_ray.target_position.x *= -1
	crack_ray.target_position.x *= -1
	up_ray.target_position.x *= -1

	stuck_timer = 0.0
	flip_cd = FLIP_CD_TIME
