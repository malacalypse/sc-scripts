(
MIDIClient.disposeClient;
MIDIClient.init;
MIDIIn.connectAll;

~fx = {
  arg dlyTime = 0.354, dlyDecay = 1.4;
  var sig = SoundIn.ar(0);
  Out.ar(0, sig + CombL.ar([sig, sig], 2.0, dlyTime, dlyDecay));
}.play;


~cw = ClockWise(~fx);
~cw.midiDevice(\bs, "BeatStep");

~cw.select(\ccMatrixVol, \deviceSelect, ~volBus);

// Maps device selection row (top pads, midi notes 44..)
(0..7).do { |index|
  var padNote = index + 44;
  ~cw.midiRadioButton(\deviceSelect, index, \bs, 15, note: padNote);
};

(0..7).do { |index|
  var padCC = index + 80;
  var padBus = "padBus%".format(index).asSymbol;
  ~cw.action(padBus, "Padbus triggered: %".format(index).postln; );

  ~cw.midiTriggerButton(padBus, \bs, ~bs_control_channel, cc: padCC);

  // Route pad to currently chosen device row in matrix
  ~ccPadRow = ~deviceIndex.collect { |n|
    var ccMatrix = "ccMatrix%pad%".format(n, index).asSymbol;
    ~cw.action(ccMatrix, "% triggered.".format(ccMatrix).postln; );
    ccMatrix;
  };
  ~cw.select(padBus, \deviceSelect, ~ccPadRow);
};

~cw.action(\deviceSelect, { |v| "Input device changed to %".format(v).postln });
~cw.saneValue(\deviceSelect, 0);

~cw.midiEncoder(\feedback, \bs, 15, 10, 1/127);
~cw.synthArg(\feedback, ControlSpec(0, 2000, \exponential, 2000/127), \dlyDecay);
~cw.action(\feedback, { |v| "Feedback is now %".format(v).postln; });
~cw.warp(\dtime, \dtime, \midi.asSpec);
~cw.midiEncoder(\dtime, \bs, 15, 74, 1/127);

~cw.synthArg(\dtime, nil, \dlyTime);
~cw.action(\dtime, { |v| "Delay time is now %".format(v).postln; });

~cw.saneAll;
~cw.syncAll;
)

