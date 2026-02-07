#+build linux:android
package aaudio

import "core:c"

foreign import aaudio_lib "system:aaudio"

@(default_calling_convention = "c")
foreign aaudio_lib {
	@(link_name = "AAudio_createStreamBuilder")
	create_stream_builder :: proc(builder: ^^StreamBuilder) -> c.int32_t ---

	@(link_name = "AAudioStreamBuilder_setDirection")
	stream_builder_set_direction :: proc(builder: ^StreamBuilder, direction: Direction) ---
	@(link_name = "AAudioStreamBuilder_setDataCallback")
	stream_builder_set_data_callback :: proc(builder: ^StreamBuilder, callback: DataCallback, user_data: rawptr) ---
	@(link_name = "AAudioStreamBuilder_setChannelCount")
	stream_builder_set_channel_count :: proc(builder: ^StreamBuilder, channel_count: c.int) ---
	@(link_name = "AAudioStreamBuilder_setSampleRate")
	stream_builder_set_sample_rate :: proc(builder: ^StreamBuilder, sample_rate: c.int) ---
	@(link_name = "AAudioStreamBuilder_setFormat")
	stream_builder_set_format :: proc(builder: ^StreamBuilder, format: Format) ---
	@(link_name = "AAudioStreamBuilder_setBufferCapacityInFrames")
	stream_builder_set_buffer_capacity_in_frames :: proc(builder: ^StreamBuilder, frames: c.int) ---
	@(link_name = "AAudioStreamBuilder_setPerformanceMode")
	stream_builder_set_performance_mode :: proc(builder: ^StreamBuilder, mode: Performance_Mode) ---
	@(link_name = "AAudioStreamBuilder_openStream")
	stream_builder_open_stream :: proc(builder: ^StreamBuilder, stream: ^^Stream) -> c.int32_t ---
	@(link_name = "AAudioStreamBuilder_delete")
	stream_builder_delete :: proc(builder: ^StreamBuilder) ---

	@(link_name = "AAudioStream_write")
	stream_write :: proc(stream: ^Stream, buffer: rawptr, frames: c.int32_t, timeout_nanoseconds: c.int64_t) -> c.int32_t ---
	@(link_name = "AAudioStream_requestStart")
	stream_request_start :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_waitForStateChange")
	stream_wait_for_state_change :: proc(stream: ^Stream, from: Stream_State, next: ^Stream_State, timeout_nanoseconds: c.int64_t) -> c.int32_t ---
	@(link_name = "AAudioStream_getFramesWritten")
	stream_get_frames_written :: proc(stream: ^Stream) -> c.int64_t ---
	@(link_name = "AAudioStream_getBufferSizeInFrames")
	stream_get_buffer_size_in_frames :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getBufferCapacityInFrames")
	stream_get_buffer_capacity_in_frames :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getFramesPerBurst")
	stream_get_frames_per_burst :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getSamplesPerFrame")
	stream_get_samples_per_frame :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getSampleRate")
	stream_get_sample_rate :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getChannelCount")
	stream_get_channel_count :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_getFormat")
	stream_get_format :: proc(stream: ^Stream) -> Format ---
	@(link_name = "AAudioStream_getTimestamp")
	stream_get_timestamp :: proc(stream: ^Stream, clock_id: Clock_ID, frame_position: ^c.int64_t, time_nanoseconds: ^c.int64_t) -> c.int32_t ---
	@(link_name = "AAudioStream_getXRunCount")
	stream_get_x_run_count :: proc(stream: ^Stream) -> c.int32_t ---
	@(link_name = "AAudioStream_setBufferSizeInFrames")
	stream_set_buffer_size_in_frames :: proc(stream: ^Stream, frames: c.int32_t) -> c.int32_t ---
	@(link_name = "AAudioStream_close")
	stream_close :: proc(stream: ^Stream) ---
}

DataCallback :: proc(stream: ^Stream, user_data: rawptr, audio_data: rawptr, num_frames: c.int) -> Callback_Result
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
Format :: enum c.int {
	Invalid = -1,
	Unspecified,
	PCM_I16 = 1,
	PCM_Float = 2
}

Clock_ID :: enum c.int {
	Monotonic = 1,
	Boot_Time = 7,
}

Stream_State :: enum c.int {
	Uninitialized = 0,
	Unknown,
	Open,
	Starting,
	Started,
	Pausing,
	Paused,
	Flushing,
	Flushed,
	Stopping,
	Stopped,
	Closing,
	Closed,
	Disconnected,
}

Performance_Mode :: enum c.int {
    None = 10,
    Power_Saving = 11,
    Low_Latency = 12,
}
