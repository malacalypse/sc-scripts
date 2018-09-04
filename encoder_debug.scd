(
var devname = "BeatStep", midiChannel = 15;
var encCC = #[10, 74, 71, 76, 77, 93, 73, 75, 114, 18, 19, 16, 17, 91, 79, 72];

var setUpBusses = {
  "Initializing effects busses".postln;

  ~fxBus = Bus.audio(s, 2);
  ~choInBus = Bus.audio(s, 2);
  ~dlyInBus = Bus.audio(s, 2);
  ~revInBus = Bus.audio(s, 2);
  ~ampInBus = Bus.audio(s, 2);
  ~ovd = Synth.new(\saturation, [input: ~fxBus, output: ~choInBus]);
  ~cho = Synth.new(\chorus, [input: ~choInBus, output: ~dlyInBus], ~ovd, \addAfter);
  ~dly = Synth.new(\delay,  [input: ~dlyInBus, output: ~revInBus], ~cho, \addAfter);
  ~rev = Synth.new(\reverb, [input: ~revInBus, output: ~ampInBus], ~dly, \addAfter);
  ~amp = Synth.new(\ampsim, [input: ~ampInBus, output: 0], ~rev, \addAfter);

  { Out.ar(~fxBus, SoundIn.ar([0, 1])); }.play;

  initMidi.value;
  true;
};

var initMidi = {
  MIDIClient.disposeClient;
  MIDIClient.init;
  MIDIIn.connectAll;

  "Initializing MIDI".postln;

  ~cw = ClockWise(~fx);
  ~cw.midiDevice(\midicc, devname); // choose your own device, as you like.

  // Set up two midi encoders, these will step from 0 to 1 in 127ths
  ~cw.midiEncoder(\enc1, \midicc, midiChannel, encCC[0], ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);
  ~cw.midiEncoder(\enc2, \midicc, midiChannel, encCC[1], ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);
  ~cw.midiEncoder(\enc3, \midicc, midiChannel, encCC[2], ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);
  ~cw.midiEncoder(\enc4, \midicc, midiChannel, encCC[3], ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);

  // Wire up two control points
  ~cw.synthArg(\enc1, nil, \dlyFdbk, ~dly);
  ~cw.synthArg(\enc2, nil, \wetdry, ~dly);
  ~cw.synthArg(\enc3, nil, \distortion, ~ovd);
  ~cw.synthArg(\enc4, nil, \wetdry, ~cho);

  // print some info
  ~cw.action(\enc1, { |v| "Encoder 1 is now %".format(v).postln; });
  ~cw.action(\enc2, { |v| "Encoder 2 is now %".format(v).postln; });

  // When this runs, the encoders reset to 0... why?
  ~cw.syncAll;
};

"effects_stack.scd".loadRelative(true, Routine({ s.sync; setUpBusses.value; }));
)