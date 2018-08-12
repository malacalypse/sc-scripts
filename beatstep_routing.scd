(
var mapDevice = { |device, deviceNumber, ch, volCC, knobCCs, padCCs|
  var ccMatrixVol = "ccMatrixVol%".format(deviceNumber).asSymbol;

  knobCCs.do { |knobCC, index|
    var ccMatrix = "ccMatrix%knob%".format(deviceNumber, index).asSymbol;
    c.midiCC(ccMatrix, device, ch, knobCC);
  };
  padCCs.do { |padCC, index|
    var ccMatrix = "ccMatrix%pad%".format(deviceNumber, index).asSymbol;
    c.midiTriggerButton(ccMatrix, device, ch, padCC);
  };
  c.midiCC(ccMatrixVol, device, ch, volCC);
};

MIDIIn.connectAll;
c = ClockWise({});
CmdPeriod.add(c);

// Set up BeatStep as a matrix CC controller:
//  - buttons 0-7 choose output routing
//  - buttons 8-15 send their note values to the note matrix
//  - knobs   0-15 are routed to the CC matrix patch points 1-16 for the selected device 0-7
// Beatstep configuration:
//  - Factory defaults (control pads send MIDI notes) +
//  - All knobs relative encoding type 1 with no speedup.
//  - Lower row of pads (9-16) send CC 80-87. Undecided on whether toggle or gate is best yet.
//  - Control channel: 0
//  - Seq. 1 channel: 1
//  - Seq. 2 channel: 2
// Connections are to a ccMatrix symbol:
//  - ccMatrixXpadY (X = 0..7, Y=0..7) connect device X to pad Y on the BeatStep.
//  - ccMatrixXknobY (X = 0..7, Y = 0..15) connect device X to knob Y on the BeatStep.
// Right now I'm leaving the main volume knob (CC #7) unmapped. It is set to absolute on the BS.
c.midiDevice(\bs, "beatstep");
c.midiDevice(\h9std, "H9 Standard");
c.midiDevice(\h9max, "H9 Pedal");

~deviceIndex = (0..7);

// Volume knob (or expr)
c.midiCC(\ccMatrixVol, \bs, 0, 7);
~volBus = ~deviceIndex.collect { |index| "ccMatrixVol%".format(index).asSymbol };
c.select(\ccMatrixVol, \deviceSelect, ~volBus);

// top row of buttons (1-8 / 0-7) = notes 44-51
~deviceIndex.do { |index|
  var padNote = index + 44;
  c.midiRadioButton(\deviceSelect, index, \bs, 0, note: padNote);
};
c.saneValue(\deviceSelect, 0);
c.action(\deviceSelect, { |v| "Input device changed to %".format(v).postln });

// bottom row of buttons (9-16 / 8-15) = cc 80-87
// TODO: This could perhaps use c.midiCC instead, if we want to pass the beatstep behaviours through.
~deviceIndex.do { |index|
  var padCC = index + 80;
  var padBus = "padBus%".format(index).asSymbol;

  c.midiTriggerButton(padBus, \bs, 0, cc: padCC);

  // Route pad to currently chosen device row in matrix
  ~ccPadRow = ~deviceIndex.collect { |n|
    var ccMatrix = "ccMatrix%pad%".format(index, n).asSymbol;
    c.action(ccMatrix, { "Pad % (BS pad %) triggered for device %".format(index, index + 9, n).postln });
    ccMatrix;
  };
  c.select(padBus, \deviceSelect, ~ccPadRow);
};

// Map stock CCs for knobs to knob matrix points
[10, 74, 71, 76, 77, 93, 73, 75, 114, 18, 19, 16, 17, 91, 79, 72].do { |cc, index|
  var knobBus = "knobBus%".format(index).asSymbol;
  // c.action(knobBus, { |v| "Bus % INPUT: %".format(index, v).postln });

  // "Mapping cc % to knob %".format(cc, index).postln;
  c.midiEncoder(knobBus, \bs, 0, cc, 1 / 127, mode: \offset, inOnly: true);
  c.saneValue(knobBus, 0.5); // middle of the range
  // c.action(knobBus, { |v| "Received value % for knob %".format(v, index + 1).postln });

  // Route point to currently chosen device row in matrix
  ~ccPatchRow = ~deviceIndex.collect { |p|
    var ccMatrix = "ccMatrix%knob%".format(p, index).asSymbol;
    c.action(ccMatrix, { |v| "Received value % for device %, knob %".format(v, p, index + 1).postln });
    ccMatrix;
  };
  c.select(knobBus, \deviceSelect, ~ccPatchRow);
};

~h9knobCCs = (22..31);
~h9padCCs = [71];
mapDevice.value(\h9std, 6, 0, 11, ~h9knobCCs, ~h9padCCs);
mapDevice.value(\h9max, 7, 0, 11, ~h9knobCCs, ~h9padCCs);

c.saneAll();
c
)
