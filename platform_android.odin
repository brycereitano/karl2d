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
				s.window_render_glue = make_android_gl_glue(s.window, s.allocator)
			}
		case .TERM_WINDOW:
			s.window = nil
			append(&s.events, Event_Close_Window_Requested{})
		case .WINDOW_RESIZED:
			append(&s.events, Event_Screen_Resize{
				width = int(android.get_width(s.window)),
				height = int(android.get_height(s.window)),
			})
		case .GAINED_FOCUS:
			s.suspended = false
		case .LOST_FOCUS:
			s.suspended = true
		}
	}

	s.android_app.on_input_event = proc "c" (a: ^android.App, event: ^android.Input_Event) -> i32 {
		context = s.ctx

		#partial switch android.input_event_get_type(event) {
		case .Key:
			source := android.input_event_get_source(event)
			if (source & .Gamepad > .Unknown || source & .Joystick > .Unknown) {
				// Handle multiple?
				s.gamepads[0].active = true

				keycode := android.key_event_get_key_code(event)

				button := translate_android_button(keycode)
				if button == .None {
					#partial switch keycode {
					case .Power, .Volume_Up, .Volume_Down: // Bubble up to OS
					return 0;
					case:
					return 1;
					}
				}

				action := android.motion_event_get_action(event) & .Mask
				processed := 0
				#partial switch (action) {
				case .Down:
					append(&s.events, Event_Gamepad_Button_Went_Down{
						gamepad = 0,
						button = button,
					})
					processed = 1
				case .Up:
					append(&s.events, Event_Gamepad_Button_Went_Up{
						gamepad = 0,
						button = button,
					})
					processed = 1
				}
				return 0
			}
		case .Motion:
			#partial switch android.input_event_get_source(event) {
			case .Joystick, .Gamepad:
				action := android.motion_event_get_action(event) & .Mask
				for i in 0 ..< android.motion_event_get_pointer_count(event) {
					s.gamepads[i].active = true
					s.gamepads[i].axes[.Left_Stick_X].value = android.motion_event_get_axis_value(event, .X, i)
					s.gamepads[i].axes[.Left_Stick_Y].value = android.motion_event_get_axis_value(event, .Y, i)
					s.gamepads[i].axes[.Right_Stick_X].value = android.motion_event_get_axis_value(event, .Z, i)
					s.gamepads[i].axes[.Right_Stick_Y].value = android.motion_event_get_axis_value(event, .R_Z, i)

					// Trigger axises don't work on PS4 controllers
					s.gamepads[i].axes[.Left_Trigger].value = android.motion_event_get_axis_value(event, .Brake, i)*2 - 1;
					s.gamepads[i].axes[.Right_Trigger].value = android.motion_event_get_axis_value(event, .Gas, i)*2 - 1;

					// dpad is an axis on android
					x := android.motion_event_get_axis_value(event, .Hat_X, i)
					if s.gamepads[i].previous_dpad_horizontal != 0 && s.gamepads[i].previous_dpad_horizontal != x {
						append(&s.events, Event_Gamepad_Button_Went_Up {
							gamepad = int(i),
							button = s.gamepads[i].previous_dpad_horizontal == -1 ? .Left_Face_Left : .Left_Face_Right,
						})
					} else if x != 0 {
						append(&s.events, Event_Gamepad_Button_Went_Down {
							gamepad = int(i),
							button = x == -1 ? .Left_Face_Left : .Left_Face_Right,
						})
					}
					s.gamepads[i].previous_dpad_horizontal = x

					y := android.motion_event_get_axis_value(event, .Hat_Y, i)
					if s.gamepads[i].previous_dpad_vertical != 0 && s.gamepads[i].previous_dpad_vertical != y {
						append(&s.events, Event_Gamepad_Button_Went_Up {
							gamepad = int(i),
							button = s.gamepads[i].previous_dpad_vertical == -1 ? .Left_Face_Up : .Left_Face_Down,
						})
					} else if y != 0 {
						append(&s.events, Event_Gamepad_Button_Went_Down {
							gamepad = int(i),
							button = y == -1 ? .Left_Face_Up : .Left_Face_Down,
						})
					}
					s.gamepads[i].previous_dpad_vertical = y
				}
				return 1
			case .Touchscreen:
				action := android.motion_event_get_action(event) & .Mask
				processed := i32(0)
				for i in 0 ..< android.motion_event_get_pointer_count(event) {
					//id := android.motion_event_get_pointer_id(event, i)
					// TODO: Process rest of touches
					x, y := android.motion_event_get_x(event, i), android.motion_event_get_y(event, i)
					#partial switch (action) {
					case .Down:
						if i == 0 {
							append(&s.events, Event_Mouse_Button_Went_Down{button = .Left})
							append(&s.events, Event_Mouse_Move { position = { x, y } })
						}
						processed = 1
					case .Up:
						if i == 0 {
							append(&s.events, Event_Mouse_Button_Went_Up{button = .Left})
						}
						processed = 1
					case .Move:
						if i == 0 {
							append(&s.events, Event_Mouse_Move { position = { x, y } })
						}
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
	a := s.allocator
	delete(s.events)
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
	if gamepad < 0 || gamepad > len(s.gamepads) - 1 || gamepad > MAX_GAMEPADS {
		return false
	}

	return s.gamepads[gamepad].active
}

android_get_gamepad_axis :: proc(gamepad: Gamepad_Index, axis: Gamepad_Axis) -> f32 {
	if axis < min(Gamepad_Axis) || axis > max(Gamepad_Axis) {
		return 0
	}

	if gamepad < 0 || gamepad >= MAX_GAMEPADS {
		return 0
	}

	return s.gamepads[gamepad].axes[axis].value
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
	suspended:          bool,

	gamepads: [MAX_GAMEPADS]Android_Gamepad,
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

Android_Gamepad :: struct {
	active: bool,
	axes: [Gamepad_Axis]Android_Gamepad_Axis_Info,

	previous_dpad_horizontal: f32,
	previous_dpad_vertical: f32,
}

Android_Gamepad_Axis_Info :: struct {
	value: f32,
}

translate_android_button :: proc(b: android.Keycode) -> Gamepad_Button {
	#partial switch b {
	case .Button_A: return .Right_Face_Down;
	case .Button_B: return .Right_Face_Right;
	case .Button_X: return .Right_Face_Left;
	case .Button_Y: return .Right_Face_Up;

	case .Button_L1: return .Left_Shoulder;
	case .Button_L2: return .Left_Trigger;
	case .Button_R1: return .Right_Shoulder;
	case .Button_R2: return .Right_Trigger;

	case .Button_Select: return .Middle_Face_Left;
	case .Button_Mode: return .Middle_Face_Middle;
	case .Button_Start: return .Middle_Face_Right;
	case .Button_Thumb_Left: return .Left_Stick_Press;
	case .Button_Thumb_Right: return .Right_Stick_Press;
	case:
	return .None
	}
}
