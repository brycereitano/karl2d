package android_main

import "base:runtime"
import "core:log"
import "karl2d:platform_bindings/android"
import "karl2d:platform_bindings/android/aaudio"

default_assertion_failure_proc: runtime.Assertion_Failure_Proc

@(export)
android_main :: proc "c" (app: ^android.App) -> int {
	default_assertion_failure_proc = runtime.default_assertion_failure_proc
	// Make sure we set a context first thing in the main function
	context = runtime.default_context()
	when ODIN_DEBUG {
		context.logger = android.create_logger()
		context.assertion_failure_proc = proc(
			prefix, message: string,
			loc: runtime.Source_Code_Location,
		) -> ! {
			log.debug(prefix, message)
			default_assertion_failure_proc(prefix, message, loc)
		}
	}

	builder: aaudio.StreamBuilder
	status := aaudio.create_stream_builder(&builder)
	log.debug(status)

	// TODO: Find a better way to get data into android build
	context.user_ptr = app

	init()
	for step() {}
	shutdown()

	return 0
}
