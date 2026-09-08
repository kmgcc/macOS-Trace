# Desktop Subsystem Optimization Notes (macOS)

Load this file when the profile attributes a bottleneck to a specific subsystem
(real-time audio, Metal/visual effects, WebKit/hybrid views, or UI & memory).
These are battle-tested optimization patterns for macOS.

## Real-Time Audio & DSP (CoreAudio / AVAudioEngine)

- **Zero heap allocation**: Code inside `AURenderCallback` or `AVAudioNodeTap` must not allocate heap memory (`malloc`, Swift `Array` reallocations, object creation) or acquire blocking locks (`os_unfair_lock` or mutexes that can priority-invert).
- **Buffer dispatch**: Copy audio data into a pre-allocated lock-free ring buffer. Push to background queues for FFT or level calculations.
- **UI meter throttling**: Throttle UI updates (e.g., visualizers, waveform views) to 30Hz or 60Hz. Never post UI updates on every audio buffer arrival.
- **Diagnosis**: Use `Allocations`. If allocation rate exceeds 500 events/sec during audio playback, inspect audio tap closures using `scripts/top_categories.py`.

## Metal & Visual FX

- **Retina pixel fill rate**: High-DPI screens render at 2x or 3x scale. A fullscreen fragment shader on a 4K display shades over 16 million pixels per frame. If GPU impact is elevated, render to an offscreen half-resolution texture before compositing, or reduce sample counts.
- **Window occlusion**: Observe `NSWindow.occlusionState`. When `contains(.visible)` is false (window minimized or covered), pause `CVDisplayLink` or set `isPaused = true` on `MTKView`.
- **Diagnosis**: Use `Power Profiler` (`GPU Impact` column) and `Metal System Trace`.

## WebKit & Hybrid Views

- **IPC message rate**: Calling `evaluateJavaScript` with large JSON payloads at high frequency saturates WebKit IPC and spikes CPU. Send sparse synchronization anchors (e.g., 1Hz) and let JavaScript interpolate smooth movement using `requestAnimationFrame`.
- **DOM layout thrashing**: Continuously changing properties like `top`, `margin`, or `height` in dynamic scroll or text views forces browser layout recalculation. Use CSS `transform: translateY()` or `opacity` instead.
- **Diagnosis**: Use `Time Profiler` and search for `WebCore::RenderLayer` or IPC serialization symbols.

## UI & Memory Management

- **Image downsampling**: Decoding high-resolution image assets (e.g., 3000x3000px or larger raw bitmaps) directly into `NSImage` allocates ~36MB of uncompressed bitmap memory per image. Downsample at decode time using `CGImageSourceCreateThumbnailAtIndex` with `kCGImageSourceThumbnailMaxPixelSize`.
- **SwiftUI body invalidation**: Root-level state changes trigger re-evaluation of downstream view bodies. Use `Time Profiler` to inspect repeated `View.body.getter` calls.
- **Diagnosis**: Use `Allocations` with `scripts/top_categories.py` to identify large transient buffer spikes.
