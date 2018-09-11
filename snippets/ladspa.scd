(
  // A pluggable effects stack and audio mixer.
  ~audioProcessor = {
    arg inGain = 1, monoSum = 0;

    // Set up some busses for routing
    ~inBus    = Bus.audio(s, 2);
    ~fxBus    = Bus.audio(s, 2);
    ~dlyIn    = Bus.audio(s, 2);
    ~dlyOut   = Bus.audio(s, 2);
    ~revIn    = Bus.audio(s, 2);
    ~ampIn    = Bus.audio(s, 2);

    // Input Source Mixing and Sends
    ~sources  = Group.new;
    ~analogIn = Synth.new(\m2sMixer, [input: ~inBus, output: ~fxBus, mono: monoSum, gain: inGain], ~sources);

    // Effects Stack
    ~effects    = Group.after(~sources);
  // ~chorus     = Synth.new(\chorus,      [input: ~fxBus, output: ~dlyIn], ~effects, \addToTail);
  // ~overdrive  = Synth.new(\valvesat,    [input: ~fxBus, output: ~dlyIn], ~effects, \addToTail);
  // ~delay      = Synth.new(\delay_ppong, [input: ~dlyIn, output: ~revIn], ~effects, \addToTail);
  // ~delayMix   = Synth.new(\fxMixer,     [inOne: ~dlyIn, inTwo: ~dlyOut, outThru: ~ampIn, outSend: ~revIn], ~effects, \addToTail);
  // ~rev        = Synth.new(\jpverb,      [input: ~revIn, output: ~ampIn], ~effects, \addToTail);
    ~distortion = Synth.new(\digitalheat, [input: ~fxBus, output: 0], ~effects, \addToTail);

    ~chorus.set(\mix, 0); // Turn it off by default
    ~delay.set(\mix, 1); // max it out.
    ~delayMix.set(\sendTwo, 0.5);
    ~delayMix.set(\sendOne, 0.5);
    ~amp.set(\tone, 0.5);
    // Pipe the analogue input into the input bus
    { Out.ar(~inBus, Balance2.ar(SoundIn.ar(0), SoundIn.ar(0), 0)); }.play;

    // Make loadRelative happy
    true;
  };

  "effects_stack.scd".loadRelative(~audioProcessor.value);
  s.scope;
)
~audioProcessor.set(\ingain, 1)
s.options.input.sampleRate = 44100
s.plotTree;
s.meter
;

~distortion.set(\mix, 0.5)

{ Pan2.ar(SinOsc.ar(440) ! 2, Line.kr(-1, 1, 5)) }.play

s.meter;
(
s.waitForBoot({ s.scope; b = Bus.audio(s, 2); b.scope; });
)

if (s.sampleRate.isNil) { 48000 * 2 } { s.sampleRate * 2 }

e
(
s = Server.local;
s.waitForBoot({
  SynthDef(\pingpong,
    {
      var in = SoundIn.ar([0, 1]);
      var buffer = Buffer.alloc(s, s.sampleRate * 2, 2);
      var effect = PingPong.ar(buffer.bufnum, [Mix(in[0], in[1]), Bus.audio(s, 1).index], 1, 0.1, 1);
      Out.ar(0, XFade2.ar(in, effect, 0.5));
    }
  ).play(s);
});
)

s.sampleRate
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

ControlSpec.new(0.1, 60).map(1);

(
~blerp = Environment.new { |self|
  self.know = true;
  ~map = {
    arg value;
    ControlSpec(0, 1).map(value * 2);
  };
};
(
(0..127).collect { |n|
  ControlSpec(1, 0.5, \exp).map(n * (1/127));
}.plot;
)
w.map(0.5);
Quarks.gui

    SegWarp([0.5, 0.5, 1]).map(0.5)
ControlSpec(0.5, 1, \exp).map(1)
SineWarp(0, 1).map(1)
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

    ControlSpec(1, 0.5, \amp)
~delayDivisions = [25, 8, 6, 4, 3, e, 2, e/2, 1, 0.5];
~delayDivisions[1]
(0..127).collect { |n| ~delayDivisions[ControlSpec(0, ~delayDivisions.size, step: 1).map(n * (1/127) ).asInteger] };

// Debugging
    OSCresponderNode(s.addr, '/tr', { |time, resp, msg| msg.postln }).add
        SendTrig.kr(Impulse.kr(1), 0, dlyTime);
