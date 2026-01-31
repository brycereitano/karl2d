// This file is a just a wrapper that takes care of context setup and provides an entry for the
// Odin runtime to call into. `android_main` will run on start and on app restore.
package karl2d_android_entry

import ex "../.."
import "base:runtime"
import "core:log"


// rawptr here is android.App from the bindings, but avoiding the import.
@(export)
android_main :: proc "c" (app: rawptr) -> int {
	// Make sure we set a context first thing in the main function
	context = runtime.default_context()
	when ODIN_DEBUG {
		context.logger = android.create_logger()
		context.assertion_failure_proc = proc(
			prefix, message: string,
			loc: runtime.Source_Code_Location,
		) -> ! {
			log.debug(prefix, message, loc)
			runtime.default_assertion_failure_proc(prefix, message, loc)
		}
	}

	// TODO: Find a better way to get data into android build
	context.user_ptr = app

	ex.init()
	for ex.step() {}
	ex.shutdown()

	return 0
}
