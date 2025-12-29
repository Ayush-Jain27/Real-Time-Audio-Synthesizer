# Real-Time FPGA Audio Synthesizer & Visualizer

## Overview
This project implements a **real-time audio synthesizer and effects pipeline on an FPGA**, developed for **ECE 385 (Digital Systems Laboratory)**.  
The system records audio from the onboard microphone, processes it entirely in hardware using multiple audio effects, stores audio in BRAM, and renders a live **HDMI-based visualizer** driven by a MicroBlaze-controlled interface.

The design prioritizes **deterministic timing**, **modular SystemVerilog design**, and a clean separation between:
- time-critical audio processing
- memory/control logic
- video and visualization output

---

## High-Level Architecture

The design has three main paths that run in parallel:

1. **Audio capture + playback (real-time path)**
   - `mb_pdm_to_pcm.sv` converts the microphone’s PDM stream into PCM samples.
   - Audio can be routed through the effects chain and/or recorded/playbacked using BRAM via `mb_audio_looper.sv`.
   - `mb_pcm_to_pwm.sv` converts final PCM audio into PWM for speaker output.

2. **Effects processing (real-time hardware)**
   - Core effect routing lives in `simple_synth.sv`.
   - Ring modulation is implemented in `ring_modulator.sv`.
   - Bit-crushing and distortion are applied in the effects path (bit-depth reduction + clipping) and can be layered with modulation.

3. **HDMI visualization (separate video path)**
   - `mb_audio_visualizer_top.sv` drives the visualizer output.
   - `VGA_controller.sv` generates timing + pixel coordinates.
   - `Color_Mapper.sv` maps audio metrics/effect state to on-screen bars/graphics.
   - `mb_font_rom.sv` provides font bitmaps for text overlays (effect labels, status, etc.).

MicroBlaze is used for **high-level control and UI state** (what effect is enabled, what the overlay shows), while the audio datapath stays hardware-timed to avoid glitches.



---

## Audio Input & Output Pipeline

### PDM to PCM Conversion
**File:** `mb_pdm_to_pcm.sv`

Converts the high-frequency **PDM microphone input** into a signed PCM audio stream using accumulation and decimation.  
This module defines the effective audio sample rate and provides a stable digital signal for further processing.

---

### PCM to PWM Output
**File:** `mb_pcm_to_pwm.sv`

Converts processed PCM samples into a **PWM signal** suitable for audio output hardware.  
This stage is timing-critical and is isolated from visualization logic to prevent audio artifacts.

---

## Audio Effects

### Ring Modulation
**File:** `ring_modulator.sv`

Implements **amplitude modulation** by multiplying the incoming audio signal with a carrier waveform.  
This produces metallic, tremolo-like textures by introducing sum and difference frequency components.

**Key features:**
- Hardware multiplier–based modulation
- Adjustable modulation rate
- Fully real-time (no buffering or latency)

---

### Distortion
**File:** `mb_distortion.sv`

Implements a **hardware distortion effect** using amplitude boosting followed by hard clipping.  
The input PCM signal is first sign-extended and amplified, then limited to a fixed threshold to introduce non-linear distortion.

**Implementation details:**
- The 16-bit signed PCM input is sign-extended to 32 bits and amplified via a left shift.
- A fixed clipping threshold (`LIMIT`) bounds the signal to prevent overflow.
- When enabled, samples exceeding the threshold are clipped; otherwise, the signal passes through unchanged.

**Effect characteristics:**
- Produces higher-order harmonics via hard clipping
- Deterministic, real-time hardware behavior
- Enable-controlled bypass for clean routing

---

### Bit-Crushing
**File:** `mb_bitcrush.sv`

Implements a **bit-crushing effect** by reducing the effective bit depth of the PCM signal.  
This is achieved by masking out the lower significance bits, intentionally introducing quantization noise.

**Implementation details:**
- When enabled, the lower 12 bits of the 16-bit PCM signal are cleared.
- Only the upper 4 bits are preserved, significantly reducing resolution.
- When disabled, the signal bypasses the effect unchanged.

**Effect characteristics:**
- Produces a lo-fi, digitized sound texture
- Very low hardware cost
- Fully combinational and latency-free

---

## Audio Storage & Looping

### Audio Looper
**File:** `mb_audio_looper.sv`

Stores several seconds of PCM audio in **block RAM (BRAM)**, enabling playback, looping, and reprocessing.  
The looper supports real-time effect layering without disrupting audio timing.

---

## Visualization & HDMI Output

### Top-Level Visualizer
**File:** `mb_audio_visualizer_top.sv`

Coordinates video timing, audio metrics, and MicroBlaze-controlled state to generate real-time visual feedback.

---

### VGA Timing Controller
**File:** `VGA_controller.sv`

Generates VGA/HDMI timing signals, including horizontal/vertical sync and pixel coordinates.

---

### Color Mapping
**File:** `Color_Mapper.sv`

Maps visualization state (audio amplitude, pitch, active effects) to on-screen colors and bars.

---

### Font ROM
**File:** `mb_font_rom.sv`

Provides bitmap font data used for text overlays such as:
- active effects
- pitch indicators
- audio intensity bars

---

## Control & Software Integration

### Simple Synth Controller
**File:** `simple_synth.sv`

Acts as the core integration module for:
- enabling/disabling effects
- routing audio through the effect chain
- interfacing with MicroBlaze control signals

MicroBlaze is used for **high-level control and visualization state**, while all audio processing remains in dedicated hardware.

---

## Key Design Principles
- Fully hardware-based audio processing (no software DSP)
- Deterministic, real-time audio timing
- Modular SystemVerilog design
- Clear separation of audio, memory, and video domains
- Scalable architecture for additional effects or controls

---

## Possible Extensions
- Adjustable effect parameters via UART or switches
- Additional DSP effects (echo, filtering, pitch shifting)
- MIDI or keyboard-based input
- Frequency-domain visualizations

---

## Authors
`Alen Mathew Daniel`

`Ayush Jain`

ECE 385 – University of Illinois Urbana-Champaign
