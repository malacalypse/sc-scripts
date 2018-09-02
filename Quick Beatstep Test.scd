(

if (~pifx.isNil.not) {
    // clean up any old one hangin' around
    var pifx = ~pifx;
    ~pifx = nil;
    protect { pifx.freeUp };
};

MIDIClient.disposeClient;
MIDIClient.init;
MIDIIn.connectAll;
~cw = ClockWise();
~cw.midiDevice(\bs, "BeatStep");

~volBus = ~deviceIndex.collect { |index| "ccMatrixVol%".format(index).asSymbol };
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
~cw.saneAll;
~cw.syncAll;
)