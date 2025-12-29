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
**Integrated in:** `simple_synth.sv`

Applies **non-linear clipping** to the waveform by limiting the signal beyond a fixed threshold.  
This introduces higher-order harmonics, producing a saturated and aggressive sound similar to analog distortion.

**Key features:**
- Threshold-based hard clipping
- Deterministic hardware behavior
- Can be layered with other effects

---

### Bit-Crushing
**Integrated in:** `simple_synth.sv`

Reduces effective **bit depth** by truncating lower-significance bits of the PCM signal.  
This introduces quantization noise and a characteristic “lo-fi” digital texture.

**Key features:**
- Configurable bit-depth reduction
- Low hardware overhead
- Stackable with modulation and distortion

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
Ayush Jain  
ECE 385 – University of Illinois Urbana-Champaign
