// A minimal program that opens a window and draws some text in it each frame.
//
// This is a web-compatible version of `../minimal_hello_world`. Usually I try to make all examples
// web compatible. But I wanted to keep the `minimal_hello_world` example clean.
//
// The android compatibility comes from splitting the example up into `init` and `step` and `shutdown`.
//
// Compile using command-line by going to the Karl2D repository root folder and executing:
// `odin run build_web -- examples/minimal_hello_world_web`
// The output will be in `examples/minimal_hello_world_web/bin/web`
package karl2d_minimal_hello_world_android

import k2 "../.."

init :: proc() {
	k2.init(1280, 720, "Greetings from Karl2D!")
}

step :: proc() -> bool {
	// Update will make sure all the input state and frame timers are up-to-date.
	//
	// If update returns false, then it means that the player tried to close the app. 
	if !k2.update() {
		return false
	}

	// Clear the screen with a color
	k2.clear(k2.LIGHT_BLUE)

	// Write a message at coordinates (x, y) = (50, 50) with font height 100.
	k2.draw_text("Hellope!", {50, 50}, 100, k2.DARK_BLUE)

	// Nothing you drew this frame is shown until you call this.
	k2.present()

	return true
}

shutdown :: proc() {
	k2.shutdown()
}
