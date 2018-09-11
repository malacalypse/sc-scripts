(
e = 2.71828;
~delayDivisions = [25, 8, 6, 4, 3, e, 2, e/2, 1, 0.5];

/*
 * DISTORTION
 */

// # 1209 Valve saturation
// > k: Distortion level (0 to 1)
// > k: Distortion character (0 to 1)
// > a: Input
// < a: Output
// Mix controls both bypass and total distortion amount, Elektron style.
SynthDef(\valvesat,
  {
    arg output = 0, input, mix = 0.5, crunch = 0.1;

    var in = In.ar(input, 2);
    var distortion = mix;
    var character = mix;
    var effect = LADSPA.ar(2, 1209, distortion, character, in);

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

// Custom soft-clip based distortion/overdrive with compression on input and output.
// Mix controls both bypass and total distortion amount, Elektron style.
// Todo:
//  - Tune mapping of offset, and wetdry for proper feeling across input range.
//  - Combine with a compressor of some sort to even out distortion?
//  - Add harmonics, tube-style, as you crank it.
//  - Add some hard clipping towards the top of the range.
//  - Some sort of volume/overall loudness compensation (re-map based on input envelope again to track dynamics?)
//  - Add an EQ/Filter, Analog-heat style?
SynthDef(\digitalheat,
  {
    arg output = 0, input, mix = 0, ratio = 1/3, attack = 0.01, release = 0.1;

    var in = In.ar(input, 2);
    var asymmetry = ControlSpec(0, 0.1).map(mix);
    var pregain = Lag.kr(ControlSpec(1, 10).map(mix));
    var threshold = ControlSpec(1, 0.4).map(mix);

    // Processing
    var comp = CompanderD.ar(in: in, thresh: threshold, slopeBelow: 1, slopeAbove: ratio, clampTime: attack, relaxTime: release, mul: 1, add: 0);
    var effect = SoftClipAmp4.ar(comp.madd(add: asymmetry), pregain: pregain, add: -1 * pregain * asymmetry);
    var outcomp = CompanderD.ar(in: effect, thresh: 0.7, slopeBelow: 1, slopeAbove: ratio, clampTime: attack, relaxTime: release, mul: 1, add: 0);

    Out.ar(output, LinXFade2.ar(in, outcomp, mix * 2 - 1));
  }
).add;

// # 1196 Fast overdrive
// > k: Drive level (0..1) => (1 to 3)
// > a: Input
// < a: Output
SynthDef(\fastoverdrive,
  {
    arg output = 0, input, mix = 0;

    var in = In.ar(input, 2),
        drive = ControlSpec(1, 3).map(mix);
    var effect = LADSPA.ar(2, 1196, drive, in);

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

// # 1771 C* Saturate - Various static nonlinearities, 8x oversampled
// > k: mode (0 to 11)
// > k: gain (dB) (-24 to 72)
// > k: bias (0 to 1)
// > a: in (0 to 0)
// < a: out
SynthDef(\c_saturate,
  {
    arg output = 0, input, mix = 1, mode = 1, gain = 0.25, bias = 0.5;

    var in = In.ar(input, 2),
        m_mode = ControlSpec(0, 11, step: 1).map(mode),
        m_gain = ControlSpec(-24, 72).map(gain);
    var effect = LADSPA.ar(2, 1771, m_mode, m_gain, bias, in);

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

/*
 * Pitch effects: CHORUS, FLANGER, PHASER, etc...
 */

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
    arg output = 0, input, mix = 0,
        numVoices = 8, predelay = 15, separation = 0.5,
        detune = 1, lfoFreq = e, vol = -9;

    var in = In.ar(input, 2);
    var effect = LADSPA.ar(2, 1201, numVoices, predelay, separation, detune, lfoFreq, vol, in);

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

/*
 * DELAYS
 */

// # 2588 C* Scape - Stereo delay with chromatic resonances
// > k: bpm (30 to 164)
// > k: divider (2 to 4) // (0..1) is mapped to a pleasant range of divisions.
// > k: feedback (0 to 1)
// > k: dry (0 to 1)
// > k: blend (0 to 1)
// > k: tune (Hz) (415 to 467) (modulation param mod)
// > a: in (0 to 0)
// < a: out.l
// < a: out.r
SynthDef(\c_scape,
  {
    arg output = 0, input, mix = 0.5, bpm = 120,
        divider = 0.5, feedback = 0.3, dry = 0, mod = 0.5;

    var in = In.ar(input, 2),
        tune = ControlSpec(415, 467).map(mod),
        division = Select.kr(ControlSpec(0, ~delayDivisions.size).map(divider), ~delayDivisions);
    var effect = LADSPA.ar(2, 2588, bpm, division, feedback, dry, mix, tune, in);

    Out.ar(output, effect);
}).add;

// a modified stereo ping-pong delay
SynthDef(\delay_ppong,
  {
    arg output = 0, input, mix = 1, bpm = 120,
        division = 0.5, feedback = 0.3, mod = 0;

    // flows
    var in = In.ar(input, 2);
    var divider = Select.kr(ControlSpec(0, ~delayDivisions.size, step: 1).map(division), ~delayDivisions);

    // calcs
    var tempo       = 60.0 / bpm;
    var dlyTime     = Lag2.kr(tempo / divider,  0.75);
    var rt60        = ControlSpec(0, 60, \amp).map(feedback);
    var fbratio     = 0.001 ** (dlyTime / rt60.abs) * rt60.sign; // permits negative feedback which changes harmonics

    var effect = PingPong.ar(Buffer.alloc(s, s.sampleRate * 2, 2).bufnum, [in[0],in[1]], dlyTime, fbratio, 1);

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

/*
 * REVERBS
 */

// # 1795 C* PlateX2 - Versatile plate reverb, stereo inputs
// > k: bandwidth (0 to 1) (size)
// > k: tail (0 to 1)
// > k: damping (0 to 1) (hfdecay)
// > k: blend (0 to 1) (mix)
// > a: in.l (0 to 0)
// > a: in.r (0 to 0)
// < a: out.l
// < a: out.r
// NOTE: diffusion is added here for compatibility but it does nothing in this reverb algorithm.
SynthDef(\c_plate_x2,
  {
    arg output = 0, input, mix = 0.5,
        size = 0.9, tail = 0.5, hfdecay = 0.25, diffusion = 0;

    var in = In.ar(input, 2);
    var effect = LADSPA.ar(2, 1795, size, tail, hfdecay, mix, in[0], in[1], output, output + 1);
}).add;


// in: input to the reverb. Either an array of two audio signals (stereo), or a mono audiosignal.
// t60:  (tail)         (0..1) => (0.1..60) approximate reverberation time in seconds (0.1..60 sec) (T60 - the time for the reverb to decay by 60db when damp == 0 ). Does not affect early reflections.
// damp: (hfdecay)      (0..1) controls damping of high-frequencies as the reverb decays. 0 is no damping, 1 is very strong damping. Values should be between (0..1). argumentsize scales size of delay-lines within the reverberator, producing the impression of a larger or smaller space. Values below 1 can sound metallic. Values should be between (0.5..5).
// size:                -- undocumented --
// earlyDiff:           (0..1) controls shape of early reflections. Values of 0.707 or more produce smooth exponential decay. Lower values produce a slower build-up of echoes. Values should be between (0..1).
// modDepth: depth      (0..1) of delay-line modulation. Use in combination with modFreq to set amount of chorusing within the structure.
// modFreq: frequency   (0..10 Hz) of delay-line modulation. Use in combination with modDepth to set amount of chorusing within the structure.
// low: multiplier      (0..1) for the reverberation time within the low band.
// mid: multiplier      (0..1) for the reverberation time within the mid band.
// high: multiplier     (0..1) for the reverberation time within the high band.
// lowcut: frequency    (100..6000 Hz) at which the crossover between the low and mid bands of the reverb occurs.
// highcut: frequency   (1000..10000 Hz) at which the crossover between the mid and high bands of the reverb occurs.
SynthDef(\jpverb,
  {
    arg output = 0, input, mix = 0.5,
        tail = 0.1, hfdecay = 0, size = 0.8, diffusion = 0.707,
        modDepth = 5, modFreq = 2,
        lowMult = 1, midMult = 1, highMult = 1,
        lowcut = 500, highcut = 4000;

    var in = In.ar(input, 2);
    var rt60 = ControlSpec.new(0.1, 60).map(tail);
    var effect = JPverb.ar(
      in, rt60, hfdecay, size, diffusion,
      modDepth, modFreq,
      lowMult, midMult, highMult,
      lowcut, highcut
      );

    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
}).add;


// in: either an array of two audio signals (stereo), or a mono audiosignal.
// delayTime: (tail)  (0..1) => (0.1..60) approximate reverberation time in seconds (0.1..60 sec).
// damp: (hfdecay)    (0..1) controls damping of high-frequencies as the reverb decays. 0 is no damping, 1 is very strong damping. Values should be between (0..1). argumentsize scales size of delay-lines within the diffusion unit, producing the impression of a larger or smaller space. Values below 1 can sound metallic. Values should be between (0.5..5).
// size:              -- undocumented --
// diff:              (0..1) controls pattern of echoes produced by the diffuser. At very low values, the diffuser acts like a delay-line whose length is controlled by the 'size' parameter. Medium values produce a slow build-up of echoes, giving the sound a reversed-like quality. Values of 0.707 or greater than produce smooth exponentially decaying echoes. Values should be in the range (0..1).
// feedback:          (0..1) amount of feedback through the system. Sets the number of repeating echoes. A setting of 1.0 produces infinite sustain. Values should be in the range (0..1).
// modDepth:          (0..1) depth of delay-line modulation. Use in combination with modFreq to produce chorus and pitch-variations in the echoes.
// modFreq:           (0..10 Hz) frequency of delay-line modulation. Use in combination with modDepth to produce chorus and pitch-variations in the echoes.
SynthDef(\greyhole,
  {
    arg output = 0, input, mix = 0.5,
        tail = 1, hfdecay = 0, size = 1, diffusion = 1,
        feedback = 0.1, modDepth = 0.5, modFreq = 5;

    var in = In.ar(input, 2);
    var rt60 = ControlSpec.new(0.1, 60).map(tail);
    var effect = Greyhole.ar([in[0], in[1]], rt60, hfdecay, size, diffusion, feedback, modDepth, modFreq);

    Out.ar(output, LinXFade2.ar(in, [effect[0], effect[1]], mix * 2 - 1));
}).add;

// mix:   (0..1) dry/wet balance
// room:  (0..1) room size
// damp:  (0..1) hfdecay
SynthDef(\freeverb,
  {
    arg output = 0, input, mix = 0.5, size = 1, hfdecay = 0, level = 1;

    var in = In.ar(input, 2);
    var effect = FreeVerb2.ar(in[0], in[1], mix:1, room: size, damp: hfdecay, mul: level);

    Out.ar(output, LinXFade2.ar(in, [effect[0], effect[1]], mix * 2 - 1));
}).add;

/*
 * AMP, CABINET, AND SPEAKER EMULATIONS
 */

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
//
// Custom controls:
//   tonestack => passthrough to the plugin
//   crunch => A synthesis of gain, power, and other controls for overdrive
//   punch => compression as a single control
//   tone => eq and brightness as a single control
SynthDef(\c_ampsim,
  {
    arg output = 0, input, mix = 1,
        tonestack = 3, crunch = 0.1, punch = 0.1, tone = 0.5;

    var in = In.ar(input, 2),
        oversampling = 1,
        gain = ControlSpec(0, 1).map(crunch),
        brightness = ControlSpec(0.4, 1, 4).map(tone),
        power = 0.5, // ControlSpec(0.2, 0.9).map(crunch),
        bass = ControlSpec(0.7, 0.3).map(tone),
        mid = 0.5,
        treble = ControlSpec(0.3, 0.7).map(tone),
        attack = ControlSpec(0.1, 0.3).map(punch),
        squash = ControlSpec(0, 1).map(punch),
        lowcut = 0.05,
        outlevel = ControlSpec(1, 0.3, \amp).map(crunch)
        ;
    var effect = LADSPA.ar(2, 2592,
          oversampling, gain, brightness, power, tonestack, bass, mid, treble,
          attack, squash, lowcut,
          in);

    Out.ar(output, LinXFade2.ar(in, effect * outlevel, mix * 2 - 1));
}).add;

/*
 * EQ AND COMPRESSION
 */

// DJ style HP and LP filters from MZero
SynthDef(\paraeq,
  {
    arg output = 0, input, hpFreq, lpFreq;

    var in = In.ar(input, 2);
    var hpfkr = Lag2UD.kr(hpFreq, 0.05, 0.01);
    var lpfkr = Lag2UD.kr(lpFreq, 0.05, 0.01);

    Out.ar(output, BLowPass.ar(BHiPass.ar(in, hpfkr), lpfkr));
  }
).add;

/*
 * MIXERS AND SIGNAL UTILITIES
 */

// Simple stereo routing mixer with input gain and stereo send
//   Routes two stereo signals (usually a dry signal and an effected signal)
//   between two stereo outputs (usually a through and an effect)
// inOne   = the first input
// inTwo   = the second input
// inGain  = a gainstage control to adjust the overall input level of both inputs before thru and send.
// outThru = the default output if send values are 0;
// outSend = secondary output - send values > 0 increase the amount of that input at this output.
// sendOne / sendTwo = respective sends for each input. 0 = 100% thru, 0% send, 1 = 100% send, 0% thru.
SynthDef(\fxMixer,
  {
    arg inOne, inTwo, inGain = 1, outThru, outSend, sendOne = 0, sendTwo = 0;

    var inA = In.ar(inOne, 2),
        inB = In.ar(inTwo, 2),
        thruA = (1 - sendOne) * inGain,
        thruB = (1 - sendTwo) * inGain,
        sendA = sendOne * inGain,
        sendB = sendTwo * inGain
        ;

    Out.ar(outThru, Mix([[inA[0] * thruA, inA[1] * thruA], [inB[0] * thruB, inB[1] * thruB]]));
    Out.ar(outSend, Mix([[inA[0] * sendA, inA[1] * sendA], [inB[0] * sendB, inB[1] * sendB]]));
  }
).add;

// Simple stereo->stereo panning mixer with input gain and mono summing
// Mono summing (0..1) is linear sum from 0 (full stereo) to 1 (both inputs summed to both outputs)
SynthDef(\m2sMixer,
  {
    arg input, output, mono = 0, gain = 1;

    var in = In.ar(input, 2) * gain;

    Out.ar(output, Mix.ar([Balance2.ar(in[0], in[0], mono - 1), Balance2.ar(in[1], in[1], 1 - mono)]));
  }
).add;

// MZero's gate algo
// rate is a control rate signal containing the clock division of the gate, e.g. 8, 4, 2, 0.5. 0 turns the gate effect off.
// beat is a phasor or other control rate signal from 0 to the number of beats per bar, used to sync the gate.
//   ex: Phasor.ar(InTrig.kr(~beatSyncBus.index), tempo / s.sampleRate, 0, beatsPerBar);
SynthDef(\gate,
  {
    arg output = 0, input, rate, beat;

    var k_rate = In.kr(rate);
    var gateOn = Lag2UD.kr(k_rate > 0, 0.05, 0.05);
    var gate   = Lag2UD.ar((In.ar(beat) * k_rate).frac < 0.5, 0.005, 0.010);

    Out.ar(output, input * (gate * gateOn + (1 - gateOn)));
  }
).add;
)
