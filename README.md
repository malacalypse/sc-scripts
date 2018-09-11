# sc-scripts
A collection of SuperCollider scripts for doing various things.

# Notes:
# effects_stack.scd
This is a set of SynthDefs which let me easily use LADSPA audio plugins and custom SuperCollider code to process audio.

Much like a guitar pedal, each SynthDef here has one main function, e.g. chorus, overdrive, reverb, etc. This collection grows as I have need for an effect or utility module.

It's useful for swapping out various effects and seeing how they compare - most have a mix (dry-wet) control which lets you turn them on or off like a stompbox, or blend them like the send control on a mixer board. All of them should work perfectly fine in stereo.

The ones named `c_<something>` utilize the [C*Audio Plugin Suite](http://quitte.de/dsp/caps.html#) LADSPA plugins, so be sure you have those compiled and available on your system first. You'll also need the LADSPA UGen, which is part of the SC3-Plugins project.

All others which use the LADSPA Ugen are from the normal [plugin.org](http://plugin.org) LADSPA distribution.

## pifx.scd
Inspired and borrowing heavily from [MZero's pbj.scd](https://github.com/mzero/crunch-clockwise/blob/master/pbj.scd), this builds an internal audio routing between effects in the `Effects Stack`, and combines that with a custom MIDI routing setup using my Arturia BeatStep as a central controller.

The Pi thus becomes a clock source or distributor, a 2-in 2-out stereo effects processor, and a highly advanced and customizable MIDI router, allowing me to interconnect, via USB (or DIN MIDI, using the PiSound hat) a variety of synths, controllers, and effects pedals.

The bulk of what's going on in the [ClockWise](https://github.com/mzero/crunch-clockwise) section sets up this mapping, but you might notice the heavy bit of code in the middle - that's setting up a custom routing for all seventeen encoders and the lower 8 pads on the Beatstep, switched to 8 different destinations via the top row of 8 pads. Each time I switch a destination, the knobs and pads switch their MIDI mapping to match the needs of that device.

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.
