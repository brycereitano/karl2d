package android_main

import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import k2 "../.."

tex: k2.Texture
pos: k2.Vec2

init :: proc() {
	k2.init(1280, 720, "Greetings from Karl2D!")

	log.debug("In init")

	tex = k2.load_texture_from_bytes(#load("../basics/sixten.jpg"))
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	k2.clear(k2.DARK_GRAY)

	if k2.mouse_button_is_held(.Left) {
		pos := k2.get_mouse_position()
		k2.draw_circle(pos, 50, k2.WHITE)
	}

	// We use the current time to spin and move the texture.
	t := k2.get_time()
	pos_x := f32(math.sin(t) * 200)
	rot := f32(t * 1.5)
	tex_rect := k2.get_texture_rect(tex)
	tex_rect_dst := k2.Rect{pos_x + 600, 450, tex_rect.w * 3, tex_rect.h * 3}

	k2.draw_texture_ex(tex, tex_rect, tex_rect_dst, {tex_rect_dst.w / 2, tex_rect_dst.h / 2}, rot)

	k2.draw_rect({10, 10, 60, 60}, k2.GREEN)
	k2.draw_rect({20, 20, 40, 40}, k2.LIGHT_GREEN)

	dt := k2.get_frame_time()
	msg1 := fmt.tprintf("Time since start: %.2f s", t)
	msg2 := fmt.tprintf("Last frame time: %.3f ms (%.2f fps)", dt * 1000, dt == 0 ? 0 : 1 / dt)
	msg2_width := k2.measure_text(msg2, 48).x

	// k2.color_alpha takes a pre-defined color and replaces the alpha (transparency).
	k2.draw_rect({4, 95, msg2_width + 20, 162}, k2.color_alpha(k2.DARK_GRAY, 192))
	k2.draw_text("Hellöpe!", {15, 105}, 48, k2.LIGHT_RED)

	k2.draw_text(msg1, {15, 153}, 48, k2.ORANGE)
	k2.draw_text(msg2, {15, 201}, 48, k2.LIGHT_PURPLE)

	gamepad := 0
	offset := k2.Vec2{700, 200}
	title := fmt.tprintf("Gamepad %v", gamepad + 1)
	ts := k2.measure_text(title, 30)
	k2.draw_text(title, offset + {250, 60} - {ts.x/2, 0}, 30, k2.WHITE)

	button_color :: proc(
		gamepad: k2.Gamepad_Index,
		button: k2.Gamepad_Button,
		active := k2.WHITE,
		inactive := k2.GRAY,
	) -> k2.Color {
		return k2.gamepad_button_is_held(gamepad, button) ? active : inactive
	}

	g := gamepad
	o := offset
	k2.draw_circle(o + {120, 120}, 10, button_color(g, .Left_Face_Up))
	k2.draw_circle(o + {120, 160}, 10, button_color(g, .Left_Face_Down))
	k2.draw_circle(o + {100, 140}, 10, button_color(g, .Left_Face_Left))
	k2.draw_circle(o + {140, 140}, 10, button_color(g, .Left_Face_Right))

	k2.draw_circle(o + {320+50, 120}, 10, button_color(g, .Right_Face_Up))
	k2.draw_circle(o + {320+50, 160}, 10, button_color(g, .Right_Face_Down))
	k2.draw_circle(o + {300+50, 140}, 10, button_color(g, .Right_Face_Left))
	k2.draw_circle(o + {340+50, 140}, 10, button_color(g, .Right_Face_Right))

	k2.draw_rect_vec(o + {250 - 30, 140}, {20, 10}, button_color(g, .Middle_Face_Left))
	k2.draw_rect_vec(o + {250 + 10, 140}, {20, 10}, button_color(g, .Middle_Face_Right))

	left_stick := k2.Vec2 {
		k2.get_gamepad_axis(gamepad, .Left_Stick_X),
		k2.get_gamepad_axis(gamepad, .Left_Stick_Y),
	}

	right_stick := k2.Vec2 {
		k2.get_gamepad_axis(gamepad, .Right_Stick_X),
		k2.get_gamepad_axis(gamepad, .Right_Stick_Y),
	}

	left_trigger  := k2.get_gamepad_axis(gamepad, .Left_Trigger)
	right_trigger := k2.get_gamepad_axis(gamepad, .Right_Trigger)

	k2.set_gamepad_vibration(gamepad, left_trigger, right_trigger)

	k2.draw_rect_vec(o + {80, 50}, {20, 10}, button_color(g, .Left_Shoulder))
	k2.draw_rect_vec(o + {50, 50} + {0, left_trigger * 20}, {20, 10}, button_color(g, .Left_Trigger, k2.WHITE, k2.GRAY))

	k2.draw_rect_vec(o + {420, 50}, {20, 10}, button_color(g, .Right_Shoulder))
	k2.draw_rect_vec(o + {450, 50} + {0, right_trigger * 20}, {20, 10}, button_color(g, .Right_Trigger, k2.WHITE, k2.GRAY))
	k2.draw_circle(o + {200, 200} + 20 * left_stick, 20, button_color(g, .Left_Stick_Press, k2.WHITE, k2.GRAY))
	k2.draw_circle(o + {300, 200} + 20 * right_stick, 20, button_color(g, .Right_Stick_Press, k2.WHITE, k2.GRAY))


	k2.present()

	// The calls to `fmt.tprintf` above allocate using `context.temp_allocator`. Those allocations
	// are not needed for more than a frame, so they can be thrown away now.
	free_all(context.temp_allocator)

	return true
}

shutdown :: proc() {
	k2.destroy_texture(tex)
	k2.shutdown()
}
