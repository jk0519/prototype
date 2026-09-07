extends SceneTree
## Enlarged renderer contact sheet for visual seam/overlap review, not concept art.
const Model = preload("res://scripts/match_model.gd")
const Renderer = preload("res://scripts/athlete_renderer.gd")
var samples: Array = []
var canvas: Node2D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var p = Model.new().players[0]
	p.movement_bounds = Vector2(-10000,10000)
	p.serve_pose = "ready"
	for frame in range(55):
		p.step(1.0/120.0,{"move":1.0})
		if frame in [4,18,28,42]: samples.append(p.visual_pose())
	p.reset(0)
	p.serve_pose = "windup"
	for t in [0.07,0.15,0.22]:
		p.serve_pose_time = t
		samples.append(p.visual_pose())
	p.serve_pose = ""
	p.pos.y = 200
	p.velocity = Vector2(0,0)
	for t in [0.035,0.078,0.118,0.18,0.28]:
		p.swing_elapsed = t
		samples.append(p.visual_pose())
	canvas = Node2D.new()
	root.add_child(canvas)
	canvas.scale = Vector2(2.5,2.5)
	canvas.draw.connect(draw_samples)
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/sideout-v013-poses.png")
	quit()
func draw_samples() -> void:
	canvas.draw_rect(Rect2(0,0,600,400),Color("14243a"))
	for i in range(samples.size()):
		var at = Vector2(64 + (i%4)*126,98 + (i/4)*104)
		canvas.draw_line(at+Vector2(-45,3),at+Vector2(45,3),Color("638899"),0.5)
		Renderer.draw_pose(canvas,samples[i],at,1,0)
