#+build linux:android
package aaudio

import "core:c"

foreign import aaudio_lib "system:aaudio"

@(default_calling_convention = "c")
foreign aaudio_lib {
	@(link_name = "AAudio_createStreamBuilder")
	create_stream_builder :: proc(builder: ^StreamBuilder) -> c.int32_t ---

	stream_builder_set_direction :: proc(builder: ^StreamBuilder, direction: Direction) ---
	stream_builder_set_data_callback :: proc(builder: ^StreamBuilder, callback: DataCallback, user_data: rawptr) ---
}

DataCallback :: proc(stream: Stream, user_data: rawptr, audio_data: rawptr, num_frames: c.int) -> Callback_Result
Stream :: struct{}
StreamBuilder :: struct{}

Direction :: enum c.int {
	OUTPUT = 0,
	INPUT,
}
Callback_Result :: enum c.int {
	Continue = 0,
	Stop,
}
