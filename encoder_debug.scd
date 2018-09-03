(
var devname = "BeatStep", midiChannel = 15, enc1cc = 10, enc2cc = 74;

MIDIClient.disposeClient;
MIDIClient.init;
MIDIIn.connectAll;

o = OSCresponderNode(s.addr, '/tr', { |time, resp, msg| msg.postln }).add;

~fx = {
  arg dlyTime = 0.354, dlyDecay = 1.4;
  var sig = SoundIn.ar(0);
  SendTrig.kr(Impulse.kr(0.5), 1, dlyTime); // prints the dlyTime every two seconds
  SendTrig.kr(Impulse.kr(0.5), 2, dlyDecay); // same for dlyDecay
  Out.ar(0, sig + CombL.ar([sig, sig], 2.0, dlyTime, dlyDecay));
}.play;

~cw = ClockWise(~fx);
~cw.midiDevice(\midicc, devname); // choose your own device, as you like.

// Set up two midi encoders, these will step from 0 to 1 in 127ths
~cw.midiEncoder(\enc1, \midicc, midiChannel, enc1cc, ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);
~cw.midiEncoder(\enc2, \midicc, midiChannel, enc2cc, ControlSpec(0, 1, step: 0.01), mode: \offset, inOnly: true);

// Wire up two control points
// This works, but the node is allowed to have a value < 0, which means it can drift very far from the ends
~cw.synthArg(\enc1, ControlSpec(0, 2000, 10), \dlyTime);
~cw.synthArg(\enc2, \midi.asSpec, \dlyDecay);

// print some info
~cw.action(\enc1, { |v| "Encoder 1 is now %".format(v).postln; });
~cw.action(\enc2, { |v| "Encoder 2 is now %".format(v).postln; });

~cw.saneAll;
~cw.syncAll;
)

~cw.point(\enc1).performFirst(\sync)