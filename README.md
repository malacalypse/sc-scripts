# sc-scripts
A collection of SuperCollider scripts for doing various things.

## Dependencies
To run most of this, you'll need [my version](https://github.com/malacalypse/crunch-clockwise) of [MZero's ClockWise Quark](https://github.com/mzero/crunch-clockwise). If you install his version (as of 2 October 2018) you'll be missing the `resane` and `switch` synchronization features which are fundamental to the MIDI Fighter Twister operations in the core scripts.

## Core Scripts:
### effects_stack.scd
This is a set of SynthDefs which let me easily use LADSPA audio plugins and custom SuperCollider code to process audio.

Much like a guitar pedal, each SynthDef here has one main function, e.g. chorus, overdrive, reverb, etc. This collection grows as I have need for an effect or utility module.

It's useful for swapping out various effects and seeing how they compare - most have a mix (dry-wet) control which lets you turn them on or off like a stompbox, or blend them like the send control on a mixer board. All of them should work perfectly fine in stereo.

The ones named `c_<something>` utilize the [C*Audio Plugin Suite](http://quitte.de/dsp/caps.html#) LADSPA plugins, so be sure you have those compiled and available on your system first. You'll also need the LADSPA UGen, which is part of the SC3-Plugins project.

All others which use the LADSPA Ugen are from the normal [plugin.org.uk](http://plugin.org.uk) LADSPA distribution.

### pifx.scd
Inspired and borrowing heavily from [MZero's pbj.scd](https://github.com/mzero/crunch-clockwise/blob/master/pbj.scd), this builds an internal audio routing between effects in the `Effects Stack`, and combines that with a custom MIDI routing setup using a [MIDI Fighter Twister](https://store.djtechtools.com/products/midi-fighter-twister) as a central controller. (For a previous version using a customized Arturia Beatstep, [see this version](https://github.com/malacalypse/sc-scripts/commit/280a7e18e5e3a295e3f1e78b8ace27e1ec6d9bac))

The Pi thus becomes a clock source or distributor, a 2-in 2-out stereo effects processor, and a highly advanced and customizable MIDI router, allowing me to interconnect, via USB (or DIN MIDI, using the PiSound hat) a variety of synths, controllers, and effects pedals.

The bulk of what's going on in the [ClockWise](https://github.com/mzero/crunch-clockwise) section sets up this mapping, but you might notice the heavy bit of code in the middle - that's setting up a custom routing for all sixteen encoders and the lower 8 encoder pushbuttons on the MIDI Fighter Twister, switched to 8 different destinations via the top row of 8 encoder pushbuttons. Each time I switch a destination, the knobs and pads switch their MIDI mapping to match the needs of that device.

### pimidi.scd
A stripped-down version of what's going on in `pifx.scd`, not always kept equivalent (and sometimes having more or newer features). This is used to develop the MIDI ideas implemented elsewhere, and is suitable to run on a Pi Zero or other super-slim hardware as a MIDI-only router/controller map. It doesn't need `jackd`, realtime audio, or the `scsynth` engine, since it does no audio processing whatsoever, so it can run efficiently on low-power units. I use this mostly as a USB-MIDI router, so I don't need to drag a mittful of MIDI mergers and cables everywhere. Plug everything in here and go. Tempo defaults to 120bpm, and controller knob 0 changes it from 60 to 187 in 1 BPM increments. If you need a wider range of BPM you need to skip tempos (e.g. go by 2 BPM increments for a range of 256 BPM) or you need something higher resolution than 7 bit MIDI affecting the control point.

I'm working on allowing external clock sync, but I haven't finished it yet. Right now this little pupper's the clock master.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
