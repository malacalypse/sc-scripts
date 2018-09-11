(
~effect = {
  arg crunch = 0.5;
  var source = SoundIn.ar([0, 1]);
  var envelope = EnvFollow.ar(source, (1 - (crunch / 10)));
  SoftClipAmp8.ar(source.madd(1, 0.1), pregain: ControlSpec(5, 1.5).map(envelope), add: -0.1);
}.scope
)
~effect.set(\dist, 0)

  // source.clip(-1 * cliphi, cliphi * 0.9) * ;


{ var in = SinOsc.ar(440, mul: SinOsc.ar(10) * SinOsc.ar(1)); var env = Lag2UD.kr(EnvFollow.kr(in, 0.9), 0.2, 0.1); [in,env] }.plot(1)

{ var in = SoundIn.ar([0, 1]); var env = Lag2UD.kr(EnvFollow.kr(Mix(in[0], in[1]), 0.9), 0.2, 0.1); [in,env] }.plot(1)

(
~inBus = Bus.audio(s, 2);
~debug = Bus.audio(s, 1);
s.scope;

SynthDef(\digitalheat,
  {
    arg output = 0, input, asymmetry = 0, crunch = 0, mix = 0;
    var in = In.ar(input, 1) ! 2;
    // var envelope = Lag2UD.ar(EnvFollow.ar(Mix.ar([in[0], in[1]]), 0.9), 0.2, 0.1);
    var pregain = ControlSpec(1, 10).map(crunch);
    // var asymmetry = ControlSpec(0.15, 0.05).map(envelope);

    var effect = SoftClipAmp4.ar(in.madd(add: asymmetry), pregain: pregain, mul: 0.8, add: -1 * pregain * asymmetry);
    Out.ar(output, LinXFade2.ar(in, effect, mix * 2 - 1));
  }
).add;

SynthDef(\ampsim,
  {
    arg output = 0, input, ingain = 1, mix = 1,
        tonestack = 3, gain = 0.5, power = 0.5, brightness = 0.5,
        bass = 0.5, mid = 0.5, treble = 0.5,
        attack = 0.1, squash = 0.1,
        lowcut = 0.05, outlevel = 1;
    var in = In.ar(input, 2) * ingain,
        oversampling = 1;

    var effect = LADSPA.ar(2, 2592,
          oversampling, gain, brightness, power, tonestack, bass, mid, treble,
          attack, squash, lowcut,
          in);

    Out.ar(output, LinXFade2.ar(in, effect * outlevel, mix * 2 - 1));
}).add;


~heat = Synth.new(\ampsim, [output: 0, input: ~inBus, debug: ~debug]);
{ Out.ar(~inBus, SoundIn.ar(0) ! 2) }.play;
)
~heat.set(\tonestack, 3);
~heat.set(\gain, 0.4);
~heat.set(\power, 0.4);
~heat.set(\ingain, 1);
~heat.set(\brightness, 1);
~heat.set(\mid, 0.7);
~heat.set(\treble, 0.5);
~heat.set(\lowcut, 0.3);
~heat.set(\mix, 0.95);

{ Out.ar(0, SoundIn.ar(0) ! 2) }.play;