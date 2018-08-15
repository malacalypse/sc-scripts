(
if (~cw.isNil.not) {
    // clean up any old one hangin' around
    var cw = ~cw;
    ~cw = nil;
    protect { cw.free };
};

~cw = {
  var cw = ClockWise({});

  ~mapDevice = {
    arg device, deviceNumber, ch = 0, volCC = 7, knobCCs, padCCs;

    var ccMatrixVol = "ccMatrixVol%".format(deviceNumber).asSymbol;

    knobCCs.do { |knobCC, index|
      var ccMatrix = "ccMatrix%knob%".format(deviceNumber, index).asSymbol;
      cw.midiCC(ccMatrix, device, ch, knobCC);
    };
    padCCs.do { |padCC, index|
      var ccMatrix = "ccMatrix%pad%".format(deviceNumber, index).asSymbol;
      cw.midiTriggerButton(ccMatrix, device, ch, cc: padCC);
    };
    cw.midiCC(ccMatrixVol, device, ch, volCC);
  };

  MIDIIn.connectAll;
  CmdPeriod.add(c);

  // Initialize Devices
  cw.midiDevice(\bs,      "beatstep");
  cw.midiDevice(\ks,      "keystep");
  cw.midiDevice(\h9std,   "H9 Standard");
  cw.midiDevice(\h9max,   "H9 Pedal");
  cw.midiDevice(\rytm,    "analog rytm");
  cw.midiDevice(\dn,      "digitone");
  cw.midiDevice(\moog,    "subsequent 37");
  cw.midiDevice(\prophet, "rev2");
  cw.midiDevice(\rtpmidi, "Virtual Raw MIDI 1-0"); // for the pi, this is the raveloxmidi rtp midi port.

  // Very simple note routing for now
  cw.midiPerf(\keyBus, \ks, 0);
  cw.midiPerf(\keyBus, \dn, 9); // Autochannel Digitone
  cw.midiPerf(\keyBus, \rtpmidi, 0); // Also send keyboard on channel 1 out the network
  // Channel 5 is Moog - by default DN Trck Midi1 is also 5.
  cw.midiPerf(\gch5, \dn, 4);
  cw.midiPerf(\gch5, \moog, 4);
  // Channel 6 is Rev2
  cw.midiPerf(\gch6, \dn, 5);
  cw.midiPerf(\gch6, \prophet, 5);

  // Set up clocking
  cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
  cw.midiClock(\clock, \dn, outOnly:true);
  cw.midiClock(\clock, \bs, outOnly:true);
  cw.midiClock(\clock, \ks, outOnly:true);
  cw.midiClock(\clock, \h9std, outOnly:true);
  cw.midiClock(\clock, \h9max, outOnly:true);
  cw.midiClock(\clock, \moog, outOnly: true);
  cw.midiClock(\clock, \prophet, outOnly: true);

  // Set up BeatStep as a matrix CC controller:
  //  - buttons 0-7 choose output routing
  //  - buttons 8-15 send their note values to the note matrix
  //  - knobs   0-15 are routed to the CC matrix patch points 1-16 for the selected device 0-7
  // Beatstep configuration:
  //  - Factory defaults (control pads send MIDI notes) +
  //  - All knobs relative encoding type 1 with no speedup.
  //  - Lower row of pads (9-16) send CC 80-87. Undecided on whether toggle or gate is best yet.
  //  - Control channel: 0 = MIDI 1
  //  - Sequence channel: 1 = MIDI 2
  // Connections are to a ccMatrix symbol:
  //  - ccMatrixXpadY (X = 0..7, Y=0..7) connect device X to pad Y on the BeatStep.
  //  - ccMatrixXknobY (X = 0..7, Y = 0..15) connect device X to knob Y on the BeatStep.
  // Right now I'm leaving the main volume knob (CC #7) unmapped. It is set to absolute on the BS.
  ~bs_control_channel = 15;
  ~deviceIndex = (0..7);

  // Volume knob (or expr)
  cw.midiCC(\ccMatrixVol, \bs, ~bs_control_channel, 7);
  ~volBus = ~deviceIndex.collect { |index| "ccMatrixVol%".format(index).asSymbol };
  cw.select(\ccMatrixVol, \deviceSelect, ~volBus);

  // top row of buttons (1-8 / 0-7) = notes 44-51
  (0..7).do { |index|
    var padNote = index + 44;
    cw.midiRadioButton(\deviceSelect, index, \bs, ~bs_control_channel, note: padNote);
  };
  cw.saneValue(\deviceSelect, 0);
  cw.action(\deviceSelect, { |v| "Input device changed to %".format(v).postln });

  // bottom row of buttons (9-16 / 8-15) = cc 80-87
  // TODO: This could perhaps use cw.midiCC instead, if we want to pass the beatstep behaviours through.
  (0..7).do { |index|
    var padCC = index + 80;
    var padBus = "padBus%".format(index).asSymbol;

    cw.midiTriggerButton(padBus, \bs, ~bs_control_channel, cc: padCC);

    // Route pad to currently chosen device row in matrix
    ~ccPadRow = ~deviceIndex.collect { |n|
      var ccMatrix = "ccMatrix%pad%".format(n, index).asSymbol;
      ccMatrix;
    };
    cw.select(padBus, \deviceSelect, ~ccPadRow);
  };

  // Map stock CCs for knobs to knob matrix points
  [10, 74, 71, 76, 77, 93, 73, 75, 114, 18, 19, 16, 17, 91, 79, 72].do { |cc, index|
    var knobBus = "knobBus%".format(index).asSymbol;

    cw.midiEncoder(knobBus, \bs, ~bs_control_channel, cc, 1 / 127, mode: \offset, inOnly: true);
    cw.saneValue(knobBus, 0.5); // middle of the range

    // Route point to currently chosen device row in matrix
    ~ccPatchRow = ~deviceIndex.collect { |p|
      var ccMatrix = "ccMatrix%knob%".format(p, index).asSymbol;
      ccMatrix;
    };
    cw.select(knobBus, \deviceSelect, ~ccPatchRow);
  };

  ~h9knobCCs = (22..31);
  ~h9padCCs = [71, 17, 16, 70];
  ~mapDevice.value(\h9std, 6, 0, 11, ~h9knobCCs, ~h9padCCs);
  ~mapDevice.value(\h9max, 7, 0, 11, ~h9knobCCs, ~h9padCCs);

  cw.saneAll();
  cw
}.value;
)
