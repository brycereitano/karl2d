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
import "core:time"
import "core:sync"
import "log"
import "platform_bindings/android/aaudio"

AAudio_State :: struct {
	stream: ^aaudio.Stream,
	allocator: runtime.Allocator,
	previous_under_run_count: int,
	submitted_samples: int,

	buffer: []Audio_Sample,
	head: int,
	tail: int,
}

aaudio_buffer_mask :: proc() -> int { return len(s.buffer) - 1 }
aaudio_buffer_space :: proc() -> int { return aaudio_buffer_mask() - aaudio_buffer_length() }
aaudio_buffer_length :: proc() -> int {
	return int(sync.atomic_load(&s.tail) - sync.atomic_load(&s.head)) & aaudio_buffer_mask()
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
	aaudio.stream_builder_set_performance_mode(builder, .Low_Latency)
	aaudio.stream_builder_set_data_callback(builder, aaudio_data_callback, nil)

	ch(aaudio.stream_builder_open_stream(builder, &s.stream))
	aaudio.stream_builder_delete(builder)

	ch(aaudio.stream_request_start(s.stream))
	next_state: aaudio.Stream_State
	ch(aaudio.stream_wait_for_state_change(s.stream, .Starting, &next_state, i64(1000 * time.Millisecond)))

	log.debugf("Sample rate: %d", aaudio.stream_get_sample_rate(s.stream))
	log.debugf("Channel count: %d", aaudio.stream_get_channel_count(s.stream))
	log.debugf("Format: %v", aaudio.stream_get_format(s.stream))
	capacity := next_power_of_two(uint(aaudio.stream_get_buffer_capacity_in_frames(s.stream))*2)
	s.buffer = make([]Audio_Sample, capacity, allocator)
}

aaudio_data_callback :: proc(stream: ^aaudio.Stream, user_data: rawptr, audio_data: rawptr, num_frames: i32) -> aaudio.Callback_Result {
	audio_slice := ([^]Audio_Sample)(audio_data)[:num_frames]
	length := min(aaudio_buffer_length(), int(num_frames))
	i := sync.atomic_load(&s.head)
	if i + length > len(s.buffer) {
		written := copy(audio_slice[:len(s.buffer)-i], s.buffer[i:])
		audio_slice = audio_slice[written:]
		length -= written
		i = 0
	}
	copy(audio_slice, s.buffer[i:i+length])
	sync.atomic_store(&s.head, i + length)

	return .Continue
}


ch :: proc(result: i32, loc := #caller_location) {
	if result < 0 {
		log.errorf("aaudio error. Error code: %v", result, location = loc)
	}
}

aaudio_shutdown :: proc() {
	log.debug("Shutdown audio backend aaudio")
	aaudio.stream_close(s.stream)
	delete(s.buffer, s.allocator)
}

aaudio_set_internal_state :: proc(state: rawptr) {
	assert(state != nil)
	s = (^AAudio_State)(state)
}

aaudio_feed :: proc(samples: []Audio_Sample) {
	length := min(aaudio_buffer_space(), len(samples))
	i := sync.atomic_load(&s.tail)
	consumed := 0
	if i + length > len(s.buffer) {
		consumed = copy(s.buffer[i:], samples[:len(s.buffer)-i])
		length -= consumed
		i = 0
	}
	copy(s.buffer[i:], samples[consumed:])
	sync.atomic_store(&s.tail, i + length)
}

aaudio_remaining_samples :: proc() -> int {
	return aaudio_buffer_length()
}

next_power_of_two :: proc(x: uint) -> uint {
	p: uint
  for p = 1; p < x; p *= 2 {}
  return p
}

