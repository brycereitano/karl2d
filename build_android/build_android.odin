// This program builds a Karl2D game as an android version.
//
// Usage:
//    odin run build_android -- directory_name 
//
// For example:
//    odin run build_android -- examples/minimal_android
#+feature dynamic-literals
package karl2d_build_android_tool

import "core:fmt"
import "core:path/filepath"
import os "core:os/os2"
import "core:strings"

ANDROID_TARGET :: 34 // TODO: turn into parameter

main :: proc() {
	print_usage: bool

	if len(os.args) < 2 {
		print_usage = true
	}

	dir: string
	compiler_params: [dynamic]string

	for a in os.args {
		if a == "-help" || a == "--help" {
			print_usage = true
		} else if strings.has_prefix(a, "-") {
			append(&compiler_params, a)
		} else {
			dir = a
		}
	}

	if dir == "" {
		print_usage = true
	}

	if print_usage {
		fmt.eprintfln("Usage: odin run build_android -- directory_name -extra -parameters' Any extra parameters that start with a dash will be passed on to the Odin compiler.\nExample: 'odin run build_android -- examples/minimal_android -debug'")
		return
	}

	android_sdk_dir := os.get_env("ODIN_ANDROID_SDK", context.allocator)
	android_ndk_dir := os.get_env("ODIN_ANDROID_NDK", context.allocator)
	fmt.ensuref(android_sdk_dir != "", "ANDROID_HOME environment variable is not set!")
	fmt.ensuref(android_ndk_dir != "", "ODIN_ANDROID_NDK environment variable is not set!")

	ANDROID_ENTRY_TEMPLATE :: #load("android_entry_templates/android_entry_template.odin")

	dir_handle, dir_handle_err := os.open(dir)
	fmt.ensuref(dir_handle_err == nil, "Failed finding directory %v. Error: %v", dir, dir_handle_err)

	dir_stat, dir_stat_err := os.fstat(dir_handle, context.allocator)
	fmt.ensuref(dir_stat_err == nil, "Failed checking status of directory %v. Error: %v", dir, dir_stat_err)
	fmt.ensuref(dir_stat.type == .Directory, "%v is not a directory!", dir)

	dir_name := dir_stat.name

	bin_dir := filepath.join({dir, "bin"})
	os.make_directory(bin_dir, 0o755)
	bin_android_dir := filepath.join({bin_dir, "android"})
	os.make_directory(bin_android_dir, 0o755)

	build_dir := filepath.join({dir, "build"})
	os.make_directory(build_dir, 0o755)
	build_android_dir := filepath.join({build_dir, "android"})
	os.make_directory(build_android_dir, 0o755)

	build_android_object_dir := filepath.join({build_android_dir, "objects"})
	os.make_directory(build_android_object_dir, 0o755)

	entry_odin_file_path := filepath.join({build_android_dir, fmt.tprintf("%v_android_entry.odin", dir_name)})
	write_entry_odin_err := os.write_entire_file(entry_odin_file_path, ANDROID_ENTRY_TEMPLATE)
	fmt.ensuref(write_entry_odin_err == nil, "Failed writing %v. Error: %v", entry_odin_file_path, write_entry_odin_err)

	_, odin_root_stdout, _, odin_root_err := os.process_exec({
		command = { "odin", "root" },
	}, allocator = context.allocator)

	ensure(odin_root_err == nil, "Failed fetching 'odin root' (Odin in PATH needed!)")
	odin_root := string(odin_root_stdout)

	// TODO: windows and osx paths
	when ODIN_OS == .Linux {
		ndk_toolchain_dir := filepath.join({android_ndk_dir, "toolchains", "llvm", "prebuilt", "linux-x86_64"})
	} else {
		panic(fmt.tprintf("Android builds not supported on %s", ODIN_OS))
	}

	object_out_path := filepath.join({build_android_object_dir, "libmain.o"})

	build_command: [dynamic]string
	append(&build_command, ..[]string{
		"odin",
		"build",
		build_android_dir,
		fmt.tprintf("-out:%v", object_out_path),
		"-target:linux_arm64",
		"-subtarget:android",
		"-build-mode:object",
	})
	append(&build_command, ..compiler_params[:])
	ensure_run_command(build_command)

	// Compile native app glue
	glue_build_command: [dynamic]string
	append(&glue_build_command, ..[]string{
		filepath.join({ndk_toolchain_dir, "bin", "clang"}),
		fmt.tprintf("--target=aarch64-linux-android%d", ANDROID_TARGET),
		"-c", filepath.join({android_ndk_dir, "sources", "android", "native_app_glue", "android_native_app_glue.c"}),
		"-o", filepath.join({build_android_object_dir, "android_native_app_glue.o"}),
		"--sysroot", filepath.join({ndk_toolchain_dir, "sysroot"}),
		fmt.tprintf("-I%s", filepath.join({ndk_toolchain_dir, "sysroot", "usr", "include"})),
		fmt.tprintf("-I%s", filepath.join({ndk_toolchain_dir, "sysroot", "usr", "include", "aarch64-linux-android"})),
		"-Wno-macro-redefined",
	})
	ensure_run_command(glue_build_command)

	glue_shared_path := filepath.join({build_android_object_dir, "android_native_app_glue.a"})
	glue_archive_command: [dynamic]string
	append(&glue_archive_command, ..[]string{
		filepath.join({ndk_toolchain_dir, "bin", "llvm-ar"}),
		"rcs", 
		glue_shared_path,
		filepath.join({build_android_object_dir, "android_native_app_glue.o"}),
	})
	ensure_run_command(glue_archive_command)

	// Comile truetype
	truetype_build_command: [dynamic]string
	append(&truetype_build_command, ..[]string{
		filepath.join({ndk_toolchain_dir, "bin", "clang"}),
		fmt.tprintf("--target=aarch64-linux-android%d", ANDROID_TARGET),
		"-c", filepath.join({odin_root, "vendor", "stb", "src", "stb_truetype.c"}),
		"-o", filepath.join({build_android_object_dir, "stb_truetype.o"}),
		"--sysroot", filepath.join({ndk_toolchain_dir, "sysroot"}),
		fmt.tprintf("-I%s", filepath.join({ndk_toolchain_dir, "sysroot", "usr", "include"})),
		fmt.tprintf("-I%s", filepath.join({ndk_toolchain_dir, "sysroot", "usr", "include", "aarch64-linux-android"})),
		"-Wno-macro-redefined",
	})
	ensure_run_command(truetype_build_command)

	truetype_shared_path := filepath.join({build_android_object_dir, "stb_truetype.a"})
	truetype_archive_command: [dynamic]string
	append(&truetype_archive_command, ..[]string{
		filepath.join({ndk_toolchain_dir, "bin", "llvm-ar"}),
		"rcs", 
		truetype_shared_path,
		filepath.join({build_android_object_dir, "stb_truetype.o"}),
	})
	ensure_run_command(truetype_archive_command)

	// Link shared lib
	shared_build_command: [dynamic]string
	append(&shared_build_command, 
		filepath.join({ndk_toolchain_dir, "bin", "clang"}),
		fmt.tprintf("--target=aarch64-linux-android%d", ANDROID_TARGET),
		glue_shared_path,
	)

	android_out_dir := filepath.join({build_android_dir, "apk", "lib", "lib", "arm64-v8a"})
	os.make_directory_all(android_out_dir, 0o755)
	f, open_build_android_object_dir_err := os.open(build_android_object_dir)
	defer os.close(f)
	fmt.ensuref(open_build_android_object_dir_err == nil, "Failed opening %v. Error: %v", build_android_object_dir, open_build_android_object_dir_err)

	fis, read_dir_err := os.read_dir(f, -1, context.allocator)
	fmt.ensuref(read_dir_err == nil, "Failed reading directory %v. Error: %v", build_android_object_dir, read_dir_err)

	for fi in fis {
		is_main := strings.starts_with(fi.name, "libmain-")
		is_object := filepath.ext(fi.name) == ".o"
		if is_main && is_object {
			append(&shared_build_command, filepath.join({build_android_object_dir, fi.name}))
		}
	}
	truetype_shared_path_abs, _ := filepath.abs(truetype_shared_path)
	append(&shared_build_command,
		"-o", filepath.join({android_out_dir, "libmain.so"}),
    fmt.tprintf("-L%s", filepath.join({ndk_toolchain_dir, "sysroot", "usr", "lib", "aarch64-linux-android", fmt.tprintf("%d", ANDROID_TARGET)})),
		"-landroid", "-llog",
    fmt.tprintf("--sysroot=%s", filepath.join({ndk_toolchain_dir, "sysroot"})),
    "-L/", "-landroid", "-laaudio", "-lEGL",
		fmt.tprintf("-l:%s", truetype_shared_path_abs),
		"-lm", "-lc", "-shared", "-Wl,-init,'main'", "-u", "ANativeActivity_onCreate",
	)
	ensure_run_command(shared_build_command)

	copy_command: [dynamic]string
	append(&copy_command, ..[]string{
		"cp",
		filepath.join({dir, "AndroidManifest.xml"}),
		filepath.join({build_android_dir, "apk"}),
	})
	ensure_run_command(copy_command)

	// TODO: params
	bundle_command: [dynamic]string
	append(&bundle_command, ..[]string{
		"odin",
		"bundle",
		"android",
		filepath.join({build_android_dir, "apk"}),
		fmt.tprintf("-android-keystore:%s", filepath.join({build_android_dir, ".keystore"})),
		fmt.tprintf("-android-keystore-password:%s", "android"),
	})
	ensure_run_command(bundle_command)

	bins := [dynamic]string{"test.apk", "test.apk-build", "test.apk.idsig"}
	for bin in bins {
		copy_command: [dynamic]string
		append(&copy_command, ..[]string{
			"mv",
			bin,
			bin_android_dir,
		})
		ensure_run_command(copy_command)
	}
}

ensure_run_command :: proc(command: [dynamic]string) {
	status, std_out, std_err, _ := os.process_exec({ command = command[:] }, allocator = context.allocator)

	if len(std_out) > 0 {
		fmt.println(string(std_out))
	}

	if len(std_err) > 0 {
		fmt.println(string(std_err))
	}

	if status.exit_code > 0 {
		os.exit(status.exit_code)
	}
}
