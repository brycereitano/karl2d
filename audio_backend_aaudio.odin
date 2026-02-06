#+build linux:android
#+vet explicit-allocators
#+private file
package karl2d

@(private="package")
AUDIO_BACKEND_AAUDIO :: Audio_Backend_Interface {
	state_size = aaudio_state_size,
	init = aaudio_init,
	shutdown = aaudio_shutdown,
	set_internal_state = aaudio_set_internal_state,

	feed = aaudio_feed,
	remaining_samples = aaudio_remaining_samples,
}

import "base:runtime"
import "log"
import "platform_bindings/android/aaudio"
import "core:time"

AAudio_State :: struct {
	stream: ^aaudio.Stream,
	allocator: runtime.Allocator,
	previous_under_run_count: i32,
	submitted_samples: i64,
}

aaudio_state_size :: proc() -> int {
	return size_of(AAudio_State)
}

s: ^AAudio_State

aaudio_init :: proc(state: rawptr, allocator: runtime.Allocator) {
	assert(state != nil)
	s = (^AAudio_State)(state)
	s.allocator = allocator
	log.debug("Init audio backend aaudio")

	builder: ^aaudio.StreamBuilder
	ch(aaudio.create_stream_builder(&builder))
	aaudio.stream_builder_set_sample_rate(builder, 44100)
	aaudio.stream_builder_set_channel_count(builder, 2)
	aaudio.stream_builder_set_format(builder, .PCM_I16)

	ch(aaudio.stream_builder_open_stream(builder, &s.stream))
	aaudio.stream_builder_delete(builder)

	ch(aaudio.stream_request_start(s.stream))
	next_state: aaudio.Stream_State
	ch(aaudio.stream_wait_for_state_change(s.stream, .Starting, &next_state, i64(100 * time.Millisecond)))
}


ch :: proc(result: i32, loc := #caller_location) {
	if result < 0 {
		log.errorf("aaudio error. Error code: %v", result, location = loc)
	}
}

aaudio_shutdown :: proc() {
	log.debug("Shutdown audio backend aaudio")
	aaudio.stream_close(s.stream)
}

aaudio_set_internal_state :: proc(state: rawptr) {
	assert(state != nil)
	s = (^AAudio_State)(state)
}

aaudio_feed :: proc(samples: []Audio_Sample) {
	frames_per_burst := aaudio.stream_get_frames_per_burst(s.stream)
	buffer_size := aaudio.stream_get_buffer_size_in_frames(s.stream)
	buffer_capacity := aaudio.stream_get_buffer_capacity_in_frames(s.stream)


	submitted := aaudio.stream_write(s.stream, raw_data(samples), i32(len(samples)), i64(time.Millisecond))
	s.submitted_samples += i64(submitted/2) // Partial frame count, 2 samples per frame

	if buffer_size < buffer_capacity {
		underrun_count := aaudio.stream_get_x_run_count(s.stream)

		// Getting an underrun, increase buffer size
		if underrun_count > s.previous_under_run_count {
			s.previous_under_run_count = underrun_count
			buffer_size += frames_per_burst
			log.debugf("resizing buffer %d", buffer_size)
			aaudio.stream_set_buffer_size_in_frames(s.stream, buffer_size)
		}
	}
}

aaudio_remaining_samples :: proc() -> int {
	frame_pos, ns: i64
	ch(aaudio.stream_get_timestamp(s.stream, .Monotonic, &frame_pos, &ns))
	return int(s.submitted_samples - frame_pos)
}
