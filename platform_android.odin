#+build linux:android
#+private file
#+vet explicit-allocators

package karl2d

import "base:runtime"
import "log"

import "platform_bindings/android"

@(private = "package")
PLATFORM_ANDROID :: Platform_Interface {
	state_size = android_state_size,
	init = android_init,
	shutdown = android_shutdown,
	get_window_render_glue = android_get_window_render_glue,
	get_events = android_get_events,
	get_screen_width = android_get_width,
	get_screen_height = android_get_height,
	set_window_position = android_set_position,
	set_screen_size = android_set_size,
	get_window_scale = android_get_window_scale,
	set_window_mode = android_set_window_mode,
	is_gamepad_active = android_is_gamepad_active,
	get_gamepad_axis = android_get_gamepad_axis,
	set_gamepad_vibration = android_set_gamepad_vibration,
	set_internal_state = android_set_internal_state,
}

Android_App :: android.App

s: ^Android_State

android_state_size :: proc() -> int {
	return size_of(Android_State)
}

android_init :: proc(
	window_state: rawptr,
	screen_width: int,
	screen_height: int,
	window_title: string,
	options: Init_Options,
	allocator: runtime.Allocator,
) {
	assert(window_state != nil)
	s = (^Android_State)(window_state)
	s.allocator = allocator

	s.android_app = (^android.App)(context.user_ptr)
	s.android_app.on_app_cmd = proc "c" (a: ^android.App, cmd: android.App_Command) {
		s := cast(^Android_State)a.user_data
		context = s.ctx

		#partial switch cmd {
		case .INIT_WINDOW:
			if a.window != nil {
				s.window = a.window
				log.infof("Window initialized: %", s.window)
				s.window_render_glue = make_android_gl_glue(s.window, s.allocator)
			}
		case .TERM_WINDOW:
			s.window = nil
			log.info("Window terminated")
		case .GAINED_FOCUS:
			s.suspended = false
		case .LOST_FOCUS:
			s.suspended = true
		}
	}


	s.android_app.on_input_event = proc "c" (a: ^android.App, event: ^android.Input_Event) -> i32 {
		context = s.ctx

		#partial switch android.input_event_get_type(event) {
		case .Motion:
			#partial switch android.input_event_get_source(event) {
			case .Touchscreen:
				action := android.motion_event_get_action(event) & .Mask
				processed := i32(0)
				for i in 0 ..< android.motion_event_get_pointer_count(event) {
					//id := android.motion_event_get_pointer_id(event, i)
					x, y := android.motion_event_get_x(event, i), android.motion_event_get_y(event, i)
					#partial switch (action) {
					case .Down:
						log.debugf("touch %d down (%0.1f, %0.1f)", i, x, y)
						processed = 1
					case .Up:
						log.debugf("touch %d up (%0.1f, %0.1f)", i, x, y)
						processed = 1
					case .Move:
						log.debugf("touch %d move (%0.1f, %0.1f)", i, x, y)
						processed = 1
					}
				}
				return processed
			}
		}
		return 0
	}

	s.android_app.user_data = s
	s.ctx = context

	// How to handle this?
	events := make([dynamic]Event, allocator)
	for android_get_width() == 0 {
		android_get_events(&events)
	}
	runtime.delete(events)
}

android_shutdown :: proc() {
	// TODO
	// s.window.shutdown()
	a := s.allocator
	free(s.window_state, a)
}

android_get_window_render_glue :: proc() -> Window_Render_Glue {
	return s.window_render_glue
}

android_get_events :: proc(events: ^[dynamic]Event) {
	ident: i32
	android_events: i32
	source: ^android.Poll_Source

	app := s.android_app

	for {
		if s.exiting {
			break
		}

		timeout: i32 = -1 if s.suspended else 0
		ident := android.looper_poll_once(timeout, nil, &android_events, auto_cast &source)
		if ident < 0 {
			break
		}

		// Check this event.
		if source != nil {
			source.process(app, source)
		}

		// @TODO: Add sensor events. See:
		// https://github.com/android/ndk-samples/blob/master/native-activity/app/src/main/cpp/main.cpp

		if app.destroy_requested != 0 {
			append(&s.events, Event_Close_Window_Requested{})
			return
		}
	}

	append(events, ..s.events[:])
	runtime.clear(&s.events)
}
android_is_gamepad_active :: proc(gamepad: int) -> bool {
	return false
}

android_get_gamepad_axis :: proc(gamepad: Gamepad_Index, axis: Gamepad_Axis) -> f32 {
	return 0
}
android_set_gamepad_vibration :: proc(gamepad: Gamepad_Index, left: f32, right: f32) {
	return
}

android_get_width :: proc() -> int {
	return int(android.get_width(s.window)) if s.window != nil else 0
}

android_get_height :: proc() -> int {
	return int(android.get_height(s.window)) if s.window != nil else 0
}

android_set_position :: proc(x: int, y: int) {
	//s.window.set_position(x, y)
}

android_set_size :: proc(w, h: int) {
	//s.window.set_size(w, h)
}

android_get_window_scale :: proc() -> f32 {
	return 1.0
	//return s.window.get_window_scale()
}

android_create_connected_gamepads :: proc() {}

android_set_internal_state :: proc(state: rawptr) {
	assert(state != nil)
	s = (^Android_State)(state)
}

android_set_window_mode :: proc(window_mode: Window_Mode) {
	//s.window.set_window_mode(window_mode)
}

Android_State :: struct {
	window:             rawptr,
	window_state:       rawptr,
	window_render_glue: Window_Render_Glue,
	ctx:                runtime.Context,
	allocator:          runtime.Allocator,
	android_app:        ^Android_App,
	events:             [dynamic]Event,
	exiting:            bool,
	suspended:          bool,
}

@(private = "package")
Android_Window_Interface :: struct {
	state_size:             proc() -> int,
	init:                   proc(
		window_state: rawptr,
		window_width: int,
		window_height: int,
		window_title: string,
		init_options: Init_Options,
		allocator: runtime.Allocator,
	),
	shutdown:               proc(),
	get_window_render_glue: proc() -> Window_Render_Glue,
	get_events:             proc(events: ^[dynamic]Event),
	set_position:           proc(x: int, y: int),
	set_size:               proc(w, h: int),
	get_width:              proc() -> int,
	get_height:             proc() -> int,
	get_window_scale:       proc() -> f32,
	set_window_mode:        proc(window_mode: Window_Mode),
	set_internal_state:     proc(state: rawptr),
}
