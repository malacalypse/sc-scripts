(
"effects_stack.scd".loadRelative;
~inBus = Bus.audio(s, 2);
~dlyRevBus = Bus.audio(s, 2);
~revAmpBus = Bus.audio(s, 2);
~dly = Synth.new(\delay, [input: ~inBus, output: ~dlyRevBus]);
~rev = Synth.new(\reverb, [input: ~dlyRevBus, output: ~revAmpBus], ~dly, \addAfter);
~amp = Synth.new(\ampsim, [input: ~revAmpBus, output: 0], ~rev, \addAfter);
)
{ Out.ar(~inBus, SoundIn.ar([0, 1])) }.play;

{
~amp.set(\wetdry, 1);
~amp.set(\power, 1);
~amp.set(\oversampling, 1);

(
~fx = {
  arg bpm = 120,
      dlyDivide = e, dlyFdbk = 0.3, dlyDry = 0, dlyBlend = 1, dlyTune = 432, dlyMix = 0.5,
      bandwidth = 0.9, tail = 0.5, hfdecay = 0.25, revMix = 0.5,
      oversampling = 1, gain = 0.25, brightness = 0.75, power = 0.5,
        tonestack = 3, bass = 0.5, mid = 0.5, treble = 0.5,
        attack = 0.9, squash = 0.1, lowcut = 0, ampMix = 1;

  var dlyRevBus = Bus.audio(s, 2);
  var revAmpBus = Bus.audio(s, 2);


  // ~rev = Synth.new(\reverb, [outBus: revAmpBus, inBus: dlyRevBus, wetdry: revMix, bandwidth: bandwidth, tail: tail, hfdecay: hfdecay]);
  // ~ampsim = Synth.new(\ampsim, [outBus: 0, inBus: revAmpBus, wetdry: ampMix, oversampling: oversampling, gain: gain, brightness: brightness, power: power, tonestack: tonestack, bass: bass, mid: mid, treble: treble, attack: attack, squash: squash, lowcut: lowcut]);
}.play;
)
~fx.set(\wetdry, 0.5);

LADSPA.listPlugins
i = SoundIn.ar([0, 1]);

~stdSpec = ControlSpec.new(0, 1, \lin, 1/127);
~stdSpec.step

(
w = DbFaderWarp.asWarp;
(0..127).collect { |n|
  (n/127).sqrt;
}.plot;
)
w.map(0.5);

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