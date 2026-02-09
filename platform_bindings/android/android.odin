#+build linux:android
package android

import "core:c"
import "core:sys/posix"

foreign import android_lib "system:android"

@(default_calling_convention = "c")
foreign android_lib {
	@(link_name = "__android_log_print")
	log_print :: proc(log_level: Log_Priority, tag: cstring, fmt: cstring, #c_vararg args: ..any) ---

	@(link_name = "ALooper_pollOnce")
	looper_poll_once :: proc(timeoutMillis: i32, outFd: ^c.int, events: ^c.int, outData: ^^rawptr) -> Looper_Poll ---

	@(link_name = "ANativeWindow_getWidth")
	get_width :: proc(_: rawptr) -> c.int ---

	@(link_name = "ANativeWindow_getHeight")
	get_height :: proc(_: rawptr) -> c.int ---

	@(link_name = "AInputEvent_getType")
	input_event_get_type :: proc(_: ^Input_Event) -> Event_Type ---

	@(link_name = "AInputEvent_getSource")
	input_event_get_source :: proc(_: ^Input_Event) -> Input_Source ---

	@(link_name = "AKeyEvent_getKeyCode")
	key_event_get_key_code :: proc(_: ^Input_Event) -> Keycode ---

	// @(link_name = "AKeyEvent_getAction")
	// key_event_get_action :: proc(_: ^Input_Event) -> 

	@(link_name = "AMotionEvent_getAction")
	motion_event_get_action :: proc(event: ^Input_Event) -> Motion_Event_Action ---

	@(link_name = "AMotionEvent_getPointerCount")
	motion_event_get_pointer_count :: proc(event: ^Input_Event) -> c.size_t ---

	// @(link_name = "AMotionEvent_getPointerId")
	// motion_event_get_pointer_id :: proc(event: ^Input_Event, pointer_index: c.size_t) -> c.int ---

	@(link_name = "AMotionEvent_getX")
	motion_event_get_x :: proc(event: ^Input_Event, pointer_index: c.size_t) -> c.float ---

	@(link_name = "AMotionEvent_getY")
	motion_event_get_y :: proc(event: ^Input_Event, pointer_index: c.size_t) -> c.float ---

	@(link_name = "AMotionEvent_getAxisValue")
	motion_event_get_axis_value :: proc(event: ^Input_Event, axis: Motion_Axis, pointer_index: c.size_t) -> c.float ---

}

/**
* Data associated with an ALooper fd that will be returned as the "outData"
* when that source has data ready.
*/
Poll_Source :: struct {
	// The identifier of this source.  May be LOOPER_ID_MAIN or
	// LOOPER_ID_INPUT.
	id:      i32,

	// The android_app this ident is associated with.
	app:     ^App,

	// Function to call to perform the standard processing of data from
	// this source.
	process: #type proc "c" (app: ^App, source: ^Poll_Source) -> i32,
}

/**
* This is the interface for the standard glue code of a threaded
* application.  In this model, the application's code is running
* in its own thread separate from the main thread of the process.
* It is not required that this thread be associated with the Java
* VM, although it will need to be in order to make JNI calls any
* Java objects.
*/
App :: struct {
	// The application can place a pointer to its own state object
	// here if it likes.
	user_data:            rawptr,

	// Fill this in with the function to process main app commands (APP_CMD_*)
	on_app_cmd:           #type proc "c" (app: ^App, cmd: App_Command),

	// Fill this in with the function to process input events.  At this point
	// the event has already been pre-dispatched, and it will be finished upon
	// return.  Return 1 if you have handled the event, 0 for any default
	// dispatching.
	on_input_event:       #type proc "c" (app: ^App, event: ^Input_Event) -> i32,

	// The ANativeActivity object instance that this app is running in.
	activity:             ^Native_Activity,

	// The current configuration the app is running in.
	config:               ^Configuration,

	// This is the last instance's saved state, as provided at creation time.
	// It is NULL if there was no state.  You can use this as you need; the
	// memory will remain around until you call android_app_exec_cmd() for
	// APP_CMD_RESUME, at which point it will be freed and savedState set to NULL.
	// These variables should only be changed when processing a APP_CMD_SAVE_STATE,
	// at which point they will be initialized to NULL and you can malloc your
	// state and place the information here.  In that case the memory will be
	// freed for you later.
	saved_state:          rawptr,
	saved_state_size:     c.size_t,

	// The ALooper associated with the app's thread.
	looper:               ^Looper,

	// When non-NULL, this is the input queue from which the app will
	// receive user input events.
	input_queue:          ^Input_Queue,

	// When non-NULL, this is the window surface that the app can draw in.
	window:               ^Native_Window,

	// Current content rectangle of the window; this is the area where the
	// window's content should be placed to be seen by the user.
	content_rect:         Rect,

	// Current state of the app's activity.  May be either APP_CMD_START,
	// APP_CMD_RESUME, APP_CMD_PAUSE, or APP_CMD_STOP; see below.
	activity_state:       c.int,

	// This is non-zero when the application's NativeActivity is being
	// destroyed and waiting for the app thread to complete.
	// Your android_main() must return to its caller when this is non-zero.
	destroy_requested:    c.int,

	// -------------------------------------------------
	// Below are "private" implementation of the glue code.
	mutex:                posix.pthread_mutex_t,
	cond:                 posix.pthread_cond_t,
	msgread:              c.int,
	msgwrite:             c.int,
	thread:               posix.pthread_t,
	cmd_poll_source:      Poll_Source,
	input_poll_source:    Poll_Source,
	running:              b32,
	state_saved:          b32,
	destroyed:            b32,
	redraw_needed:        b32,
	pending_input_queue:  ^Input_Queue,
	pending_window:       ^Native_Window,
	pending_content_rect: Rect,
}

//
// Opaque types
//

Input_Event :: struct {}
Native_Activity :: struct {}
Configuration :: struct {}
Looper :: struct {}
Input_Queue :: struct {}
Native_Window :: struct {}

//
// Other types
//

Rect :: struct {
	left:   i32,
	top:    i32,
	right:  i32,
	bottom: i32,
}

Looper_Poll :: enum c.int {
	Wake = -1,
	Callback = -2,
	Timeout = -3,
	Error = -4,
}

App_Command :: enum c.int {
	/**
     * Command from main thread: the AInputQueue has changed.  Upon processing
     * this command, android_app->inputQueue will be updated to the new queue
     * (or NULL).
     */
	INPUT_CHANGED,

	/**
     * Command from main thread: a new ANativeWindow is ready for use.  Upon
     * receiving this command, android_app->window will contain the new window
     * surface.
     */
	INIT_WINDOW,

	/**
     * Command from main thread: the existing ANativeWindow needs to be
     * terminated.  Upon receiving this command, android_app->window still
     * contains the existing window; after calling android_app_exec_cmd
     * it will be set to NULL.
     */
	TERM_WINDOW,

	/**
     * Command from main thread: the current ANativeWindow has been resized.
     * Please redraw with its new size.
     */
	WINDOW_RESIZED,

	/**
     * Command from main thread: the system needs that the current ANativeWindow
     * be redrawn.  You should redraw the window before handing this to
     * android_app_exec_cmd() in order to avoid transient drawing glitches.
     */
	WINDOW_REDRAW_NEEDED,

	/**
     * Command from main thread: the content area of the window has changed,
     * such as from the soft input window being shown or hidden.  You can
     * find the new content rect in android_app::contentRect.
     */
	CONTENT_RECT_CHANGED,

	/**
     * Command from main thread: the app's activity window has gained
     * input focus.
     */
	GAINED_FOCUS,

	/**
     * Command from main thread: the app's activity window has lost
     * input focus.
     */
	LOST_FOCUS,

	/**
     * Command from main thread: the current device configuration has changed.
     */
	CONFIG_CHANGED,

	/**
     * Command from main thread: the system is running low on memory.
     * Try to reduce your memory use.
     */
	LOW_MEMORY,

	/**
     * Command from main thread: the app's activity has been started.
     */
	START,

	/**
     * Command from main thread: the app's activity has been resumed.
     */
	RESUME,

	/**
     * Command from main thread: the app should generate a new saved state
     * for itself, to restore from later if needed.  If you have saved state,
     * allocate it with malloc and place it in android_app.savedState with
     * the size in android_app.savedStateSize.  The will be freed for you
     * later.
     */
	SAVE_STATE,

	/**
     * Command from main thread: the app's activity has been paused.
     */
	PAUSE,

	/**
     * Command from main thread: the app's activity has been stopped.
     */
	STOP,

	/**
     * Command from main thread: the app's activity is being destroyed,
     * and waiting for the app thread to clean up and exit before proceeding.
     */
	DESTROY,
}

Log_Priority :: enum c.int {
	/** For internal use only.  */
	UNKNOWN = 0,
	/** The default priority, for internal use only.  */
	DEFAULT, /* only for SetMinPriority() */
	/** Verbose logging. Should typically be disabled for a release apk. */
	VERBOSE,
	/** Debug logging. Should typically be disabled for a release apk. */
	DEBUG,
	/** Informational logging. Should typically be disabled for a release apk. */
	INFO,
	/** Warning logging. For use with recoverable failures. */
	WARN,
	/** Error logging. For use with unrecoverable failures. */
	ERROR,
	/** Fatal logging. For use when aborting. */
	FATAL,
	/** For internal use only.  */
	SILENT, /* only for SetMinPriority(); must be last */
}

Event_Type :: enum c.int {
  Key = 1,
  Motion,
  Focus,
  Capture,
  Drag,
  Touch_Mode,
}

Input_Source_Class :: enum c.int {
  Mask = 0x000000ff,
  None = 0x00000000,
  Button = 0x00000001,
  Pointer = 0x00000002,
  Navigation = 0x00000004,
  Position = 0x00000008,
  Joystick = 0x00000010,
}

Input_Source :: enum c.int {
  Unknown = 0x0000000,
  Keyboard = 0x0000100 | c.int(Input_Source_Class.Button),
  Dpad = 0x0000200 | c.int(Input_Source_Class.Button),
  Gamepad = 0x0000400 | c.int(Input_Source_Class.Button),
  Touchscreen = 0x0001000 | c.int(Input_Source_Class.Pointer),
  Mouse = 0x0002000 | c.int(Input_Source_Class.Pointer),
  Stylus = 0x0004000 | c.int(Input_Source_Class.Pointer),
  Bluetooth_Stylus = 0x0008000 + 0x0004000,
  Trackball = 0x0010000 | c.int(Input_Source_Class.Navigation),
  Mouse_Relative = 0x0020000 | c.int(Input_Source_Class.Navigation),
  Touchpad = 0x0100000 | c.int(Input_Source_Class.Position),
  Touch_Navigation = 0x0200000 | c.int(Input_Source_Class.None),
  Joystick = 0x1000000 | c.int(Input_Source_Class.Joystick),
  HDMI = 0x2000000 | c.int(Input_Source_Class.Button),
  Sensor = 0x4000000 | c.int(Input_Source_Class.None),
  Rotary_Encoder = 0x0400000 | c.int(Input_Source_Class.None),
  Any = 0xfffff00,
}

Motion_Event_Action :: enum c.int {
  Mask = 0xff,
  Pointer_Index_Mask = 0xff00,
  Down = 0,
  Up = 1,
  Move = 2,
  Cancel = 3,
  Outside = 4,
  Pointer_Down = 5,
  Pointer_Up = 6,
  Hover_Move = 7,
  Scroll = 8,
  Hover_Enter = 9,
  Hover_Exit = 10,
  Button_Press = 11,
  Button_Release = 12
}

Motion_Axis :: enum c.int {
	X = 0,
	Y = 1,
	Pressure = 2,
	Size = 3,
	Touch_Major = 4,
	Touch_Minor = 5,
	Tool_Major = 6,
	Tool_Minor = 7,
	Orientation = 8,
	Vertical_Scroll = 9,
	Horizontal_Scroll = 10,
	Z = 11,
	R_X = 12,
	R_Y = 13,
	R_Z = 14,
	Hat_X = 15,
	Hat_Y = 16,
	Left_Trigger = 17,
	Right_Trigger = 18,
	Throttle = 19,
	Rudder = 20,
	Wheel = 21,
	Gas = 22,
	Brake = 23,
	Distance = 24,
	Tilt = 25,
	Scroll = 26,
	Relative_X = 27,
	Relative_Y = 28,
	Generic1 = 32,
	Generic2 = 33,
	Generic3 = 34,
	Generic4 = 35,
	Generic5 = 36,
	Generic6 = 37,
	Generic7 = 38,
	Generic8 = 39,
	Generic9 = 40,
	Generic10 = 41,
	Generic11 = 42,
	Generic12 = 43,
	Generic13 = 44,
	Generic14 = 45,
	Generic15 = 46,
	Generic16 = 47,
}

Keycode :: enum c.int {
  Unknown = 0,
  Soft_Left = 1,
  Soft_Right = 2,
  Home = 3,
  Back = 4,
  Call = 5,
  Endcall = 6,
  N0 = 7,
  N1 = 8,
  N2 = 9,
  N3 = 10,
  N4 = 11,
  N5 = 12,
  N6 = 13,
  N7 = 14,
  N8 = 15,
  N9 = 16,
  Star = 17,
  Pound = 18,
  Dpad_Up = 19,
  Dpad_Down = 20,
  Dpad_Left = 21,
  Dpad_Right = 22,
  Dpad_Center = 23,
  Volume_Up = 24,
  Volume_Down = 25,
  Power = 26,
  Camera = 27,
  Clear = 28,
  A = 29,
  B = 30,
  C = 31,
  D = 32,
  E = 33,
  F = 34,
  G = 35,
  H = 36,
  I = 37,
  J = 38,
  K = 39,
  L = 40,
  M = 41,
  N = 42,
  O = 43,
  P = 44,
  Q = 45,
  R = 46,
  S = 47,
  T = 48,
  U = 49,
  V = 50,
  W = 51,
  X = 52,
  Y = 53,
  Z = 54,
  Comma = 55,
  Period = 56,
  Alt_Left = 57,
  Alt_Right = 58,
  Shift_Left = 59,
  Shift_Right = 60,
  Tab = 61,
  Space = 62,
  Sym = 63,
  Explorer = 64,
  Envelope = 65,
  Enter = 66,
  Del = 67,
  Grave = 68,
  Minus = 69,
  Equals = 70,
  Left_Bracket = 71,
  Right_Bracket = 72,
  Backslash = 73,
  Semicolon = 74,
  Apostrophe = 75,
  Slash = 76,
  At = 77,
  Num = 78,
  Headset_Hook = 79,
  Focus = 80,
  Plus = 81,
  Menu = 82,
  Notification = 83,
  Search = 84,
  Media_Play_Pause = 85,
  Media_Stop = 86,
  Media_Next = 87,
  Media_Previous = 88,
  Media_Rewind = 89,
  Media_Fast_Forward = 90,
  Mute = 91,
  Page_Up = 92,
  Page_Down = 93,
  Pict_Symbols = 94,
  Switch_Charset = 95,
  Button_A = 96,
  Button_B = 97,
  Button_C = 98,
  Button_X = 99,
  Button_Y = 100,
  Button_Z = 101,
  Button_L1 = 102,
  Button_R1 = 103,
  Button_L2 = 104,
  Button_R2 = 105,
  Button_Thumb_Left = 106,
  Button_Thumb_Right = 107,
  Button_Start = 108,
  Button_Select = 109,
  Button_Mode = 110,
  Escape = 111,
  Forward_Del = 112,
  Ctrl_Left = 113,
  Ctrl_Right = 114,
  Caps_Lock = 115,
  Scroll_Lock = 116,
  Meta_Left = 117,
  Meta_Right = 118,
  Function = 119,
  Sysrq = 120,
  Break = 121,
  Move_Home = 122,
  Move_End = 123,
  Insert = 124,
  Forward = 125,
  Media_Play = 126,
  Media_Pause = 127,
  Media_Close = 128,
  Media_Eject = 129,
  Media_Record = 130,
  F1 = 131,
  F2 = 132,
  F3 = 133,
  F4 = 134,
  F5 = 135,
  F6 = 136,
  F7 = 137,
  F8 = 138,
  F9 = 139,
  F10 = 140,
  F11 = 141,
  F12 = 142,
  Num_Lock = 143,
  Numpad_0 = 144,
  Numpad_1 = 145,
  Numpad_2 = 146,
  Numpad_3 = 147,
  Numpad_4 = 148,
  Numpad_5 = 149,
  Numpad_6 = 150,
  Numpad_7 = 151,
  Numpad_8 = 152,
  Numpad_9 = 153,
  Numpad_Divide = 154,
  Numpad_Multiply = 155,
  Numpad_Subtract = 156,
  Numpad_Add = 157,
  Numpad_Dot = 158,
  Numpad_Comma = 159,
  Numpad_Enter = 160,
  Numpad_Equals = 161,
  Numpad_Left_Paren = 162,
  Numpad_Right_Paren = 163,
  Volume_Mute = 164,
  Info = 165,
  Channel_Up = 166,
  Channel_Down = 167,
  Zoom_In = 168,
  Zoom_Out = 169,
  TV = 170,
  Window = 171,
  Guide = 172,
  Dvr = 173,
  Bookmark = 174,
  Captions = 175,
  Settings = 176,
  TV_Power = 177,
  TV_Input = 178,
  STB_Power = 179,
  STB_Input = 180,
  AVR_Power = 181,
  AVR_Input = 182,
  Prog_Red = 183,
  Prog_Green = 184,
  Prog_Yellow = 185,
  Prog_Blue = 186,
  App_Switch = 187,
  Button_1 = 188,
  Button_2 = 189,
  Button_3 = 190,
  Button_4 = 191,
  Button_5 = 192,
  Button_6 = 193,
  Button_7 = 194,
  Button_8 = 195,
  Button_9 = 196,
  Button_10 = 197,
  Button_11 = 198,
  Button_12 = 199,
  Button_13 = 200,
  Button_14 = 201,
  Button_15 = 202,
  Button_16 = 203,
  Language_Switch = 204,
  Manner_MODE = 205,
  Three_D_MODE = 206,
  Contacts = 207,
  Calendar = 208,
  Music = 209,
  Calculator = 210,
  Zenkaku_Hankaku = 211,
  Eisu = 212,
  Muhenkan = 213,
  Henkan = 214,
  Katakana_Hiragana = 215,
  Yen = 216,
  Ro = 217,
  Kana = 218,
  Assist = 219,
  Brightness_Down = 220,
  Brightness_Up = 221,
  Media_Audio_Track = 222,
  Sleep = 223,
  Wakeup = 224,
  Pairing = 225,
  Media_Top_Menu = 226,
  N11 = 227,
  N12 = 228,
  Last_Channel = 229,
  TV_Data_Service = 230,
  Voice_Assist = 231,
  TV_Radio_Service = 232,
  TV_Teletext = 233,
  TV_Number_Entry = 234,
  TV_Terrestrial_Analog = 235,
  TV_Terrestrial_Digital = 236,
  TV_Satellite = 237,
  TV_Satellite_Bs = 238,
  TV_Satellite_Cs = 239,
  TV_Satellite_Service = 240,
  TV_Network = 241,
  TV_Antenna_Cable = 242,
  TV_Input_Hdmi_1 = 243,
  TV_Input_Hdmi_2 = 244,
  TV_Input_Hdmi_3 = 245,
  TV_Input_Hdmi_4 = 246,
  TV_Input_Composite_1 = 247,
  TV_Input_Composite_2 = 248,
  TV_Input_Component_1 = 249,
  TV_Input_Component_2 = 250,
  TV_Input_VGA_1 = 251,
  TV_Audio_Description = 252,
  TV_Audio_Description_Mix_Up = 253,
  TV_Audio_Description_Mix_Down = 254,
  TV_Zoom_Mode = 255,
  TV_Contents_Menu = 256,
  TV_Media_Context_Menu = 257,
  TV_Timer_Programming = 258,
  Help = 259,
  Navigate_PreviouS = 260,
  Navigate_Next = 261,
  Navigate_In = 262,
  Navigate_Out = 263,
  Stem_Primary = 264,
  Stem_1 = 265,
  Stem_2 = 266,
  Stem_3 = 267,
  Dpad_Up_Left = 268,
  Dpad_Down_Left = 269,
  Dpad_Up_Right = 270,
  Dpad_Down_Right = 271,
  Media_Skip_Forward = 272,
  Media_Skip_Backward = 273,
  Media_Step_Forward = 274,
  Media_Step_Backward = 275,
  Soft_Sleep = 276,
  Cut = 277,
  Copy = 278,
  Paste = 279,
  System_Navigation_Up = 280,
  System_Navigation_Down = 281,
  System_Navigation_Left = 282,
  System_Navigation_Right = 283,
  All_Apps = 284,
  Refresh = 285,
  Thumbs_Up = 286,
  Thumbs_Down = 287,
  Profile_Switch = 288,
  Video_App_1 = 289,
  Video_App_2 = 290,
  Video_App_3 = 291,
  Video_App_4 = 292,
  Video_App_5 = 293,
  Video_App_6 = 294,
  Video_App_7 = 295,
  Video_App_8 = 296,
  Featured_App_1 = 297,
  Featured_App_2 = 298,
  Featured_App_3 = 299,
  Featured_App_4 = 300,
  Demo_App_1 = 301,
  Demo_App_2 = 302,
  Demo_App_3 = 303,
  Demo_App_4 = 304,
  Keyboard_Backlight_Down = 305,
  Keyboard_Backlight_Up = 306,
  Keyboard_Backlight_Toggle = 307,
  Stylus_Button_Primary = 308,
  Stylus_Button_Secondary = 309,
  Stylus_Button_Tertiary = 310,
  Stylus_Button_Tail = 311,
  Recent_Apps = 312,
  Macro_1 = 313,
  Macro_2 = 314,
  Macro_3 = 315,
  Macro_4 = 316,
  Emoji_Picker = 317,
  Screenshot = 318,
  Dictate = 319,
  New = 320,
  Close = 321,
  Do_Not_Disturb = 322,
  Print = 323,
  Lock = 324,
  Fullscreen = 325,
  F13 = 326,
  F14 = 327,
  F15 = 328,
  F16 = 329,
  F17 = 330,
  F18 = 331,
  F19 = 332,
  F20 = 333,
  F21 = 334,
  F22 = 335,
  F23 = 336,
  F24 = 337
}
