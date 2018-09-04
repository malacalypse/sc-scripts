(
e = 2.71828;

// # 1209 Valve saturation
// > k: Distortion level (0 to 1)
// > k: Distortion character (0 to 1)
// > a: Input
// < a: Output
SynthDef(\saturation,
  {
    arg output = 0, input, wetdry = 0.5,
        distortion = 0.5, character = 0.5;
    var in = In.ar(input, 2);

    var effect = LADSPA.ar(2, 1209, distortion, character, in);
    Out.ar(output, XFade2.ar(in, effect, wetdry * 2 - 1));
  }
).add;

// # 1201 Multivoice Chorus
// > k: Number of voices (1 to 8)
// > k: Delay base (ms) (10 to 40)
// > k: Voice separation (ms) (0 to 2)
// > k: Detune (%) (0 to 5)
// > k: LFO frequency (Hz) (2 to 30)
// > k: Output attenuation (dB) (-20 to 0)
// > a: Input
// < a: Output
SynthDef(\chorus,
  {
    arg output = 0, input, wetdry = 0.5,
        numVoices = 4, predelay = 15, separation = 0.5,
        detune = 1, lfoFreq = e, vol = 0;
    var in = In.ar(input, 2);

    var effect = LADSPA.ar(2, 1201, numVoices, predelay, separation, detune, lfoFreq, vol, in);
    Out.ar(output, XFade2.ar(in, effect, wetdry * 2 - 1));
  }
).add;

// # 2588 C* Scape - Stereo delay with chromatic resonances
// > k: bpm (30 to 164)
// > k: divider (2 to 4)
// > k: feedback (0 to 1)
// > k: dry (0 to 1)
// > k: blend (0 to 1)
// > k: tune (Hz) (415 to 467)
// > a: in (0 to 0)
// < a: out.l
// < a: out.r
SynthDef(\delay,
  {
    arg output = 0, input, wetdry = 0.5, bpm = 120,
        dlyDivide = e, dlyFdbk = 0.3, dlyDry = 0, dlyBlend = 1, dlyTune = 432;
    var in = In.ar(input, 2);

    var effect = LADSPA.ar(2, 2588, bpm, dlyDivide, dlyFdbk, dlyDry, dlyBlend, dlyTune, in);
    Out.ar(output, XFade2.ar(in, effect, wetdry * 2 - 1));
}).add;

// # 1795 C* PlateX2 - Versatile plate reverb, stereo inputs
// > k: bandwidth (0 to 1)
// > k: tail (0 to 1)
// > k: damping (0 to 1)
// > k: blend (0 to 1)
// > a: in.l (0 to 0)
// > a: in.r (0 to 0)
// < a: out.l
// < a: out.r
SynthDef(\reverb,
  {
    arg output = 0, input, wetdry = 0.5,
        bandwidth = 0.9, tail = 0.5, hfdecay = 0.25, revMix = 1;
    var in = In.ar(input, 2);

    var effect = LADSPA.ar(2, 1795, bandwidth, tail, hfdecay, revMix, in);
    Out.ar(output, XFade2.ar(in, effect, wetdry * 2 - 1));
}).add;

// # 2592 C* AmpVTS - Idealised guitar amplification
// > k: over (0 to 2)
// > k: gain (0 to 1)
// > k: bright (0 to 1)
// > k: power (0 to 1)
// > k: tonestack (0 to 8)
// > k: bass (0 to 1)
// > k: mid (0 to 1)
// > k: treble (0 to 1)
// > k: attack (0 to 1)
// > k: squash (0 to 1)
// > k: lowcut (0 to 1)
// > a: in (0 to 0)
// < a: out
// ====================
// tonestack
// 0	 basswoman
// 1	 stanford
// 2	 wookie
// 3	 DC 30
// 4	 juice 800
// 5	 twin
// 6	 AK 20
// 7	 nihon ace
// 8	 porky
// TODO : Create composite controls for compression (blend attack and squash), tone (blend brightness, bass, mid, treble), and crunch (blend gain and power, maybe tweak brightness).
// Possible TODO: Map some of the controls against an envelope follower to turn down the crunch when it's really loud?
SynthDef(\ampsim,
  {
    arg output = 0, input, wetdry = 0.5,
        oversampling = 1, gain = 0.25, brightness = 0.75, power = 0.5,
        tonestack = 3, bass = 0.5, mid = 0.5, treble = 0.5,
        attack = 0.9, squash = 0.1, lowcut = 0;
    var in = In.ar(input, 2);

    var effect = LADSPA.ar(2, 2592,
          oversampling, gain, brightness, power, tonestack, bass, mid, treble,
          attack, squash, lowcut,
          in
        );

    Out.ar(output, XFade2.ar(in, effect, wetdry * 2 - 1));
}).add;
)
