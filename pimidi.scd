(
if (~cw.isNil.not) {
    // clean up any old one hangin' around
    var cw = ~cw;
    ~cw = nil;
    protect { cw.free };
};

~metro = TempoClock(120/60);

~cw = {
  var cw = ClockWise({});
  cw.warp(\tempo, \bpm, mul:60);

  ~mknob = { |pos, knobNum| "ccMatrix%knob%".format(pos, knobNum).asSymbol };
  ~mpad  = { |pos, padNum| "ccMatrix%pad%".format(pos, padNum).asSymbol };

  ~mapDevice = {
    arg point, position, ch = 0, knobCCs, padCCs;
    knobCCs.do { |knobCC, knobNum| if (knobCC.isNil.not) { cw.midiCC(~mknob.value(position, knobNum), point, ch, knobCC) } };
    padCCs.do  { |padCC,  padNum| if (padCC.isNil.not) { cw.midiTriggerButton(~mpad.value(position, padNum), point, ch, cc: padCC) } };
  };

  MIDIClient.init;
  CmdPeriod.add(c);

  // Initialize Devices
  cw.midiDevice(\mft,     "MIDI Fighter Twister");
  cw.midiDevice(\ks,      "keystep");
  cw.midiDevice(\h9std,   "H9 Standard");
  cw.midiDevice(\h9max,   "H9 Pedal");
  cw.midiDevice(\rytm,    "analog rytm");
  cw.midiDevice(\dn,      "digitone");
  cw.midiDevice(\moog,    "subsequent 37");
  cw.midiDevice(\prophet, "rev2");
  cw.midiDevice(\rtpout,  "0-0");
  cw.midiDevice(\rtpin,   "0-1");

  // Very simple note routing for now
  cw.midiPerf(\keyBus, \ks, 0);
  cw.midiPerf(\keyBus, \dn, 9); // Autochannel Digitone
  cw.midiPerf(\keyBus, \rtpout, 0);
  cw.midiPerf(\keyBus, \rtpin, 0);
  // Channel 5 is Moog - by default DN Trck Midi1 is also 5.
  cw.midiPerf(\gch5, \dn, 4);
  cw.midiPerf(\gch5, \moog, 4);
  // Channel 6 is Rev2
  cw.midiPerf(\gch6, \dn, 5);
  cw.midiPerf(\gch6, \prophet, 5);

  // Set up clocking
  cw.tempoClock(\tempo, \clock, ~metro);
  cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
  cw.midiClock(\clock, \dn, outOnly:true);
  cw.midiClock(\clock, \mft, outOnly:true);
  cw.midiClock(\clock, \ks, outOnly:true);
  cw.midiClock(\clock, \h9std, outOnly:true);
  cw.midiClock(\clock, \h9max, outOnly:true);
  cw.midiClock(\clock, \moog, outOnly: true);
  cw.midiClock(\clock, \prophet, outOnly: true);

  // Set up MIDI Fighter Twister as a matrix CC controller. 0 is top left, 3 is top right, 15 is bottom right.
  // MFT Setup: Stock. Only bank 0 is used. Other banks are available for custom mappings or other uses.
  //  - Switches 0-7 choose output routing to device 0-7
  //  - Switches 8-15 send CC values to CC matrix Pad points 0-7
  //  - Encoders 0-15 are routed to the CC matrix Knob points 1-16 for the selected device 0-7
  // Connections are to a ccMatrix symbol:
  //  - ccMatrixXpadY (X = 0..7, Y=0..7) connect device X to switch Y.
  //  - ccMatrixXknobY (X = 0..7, Y = 0..15) connect device X to knob Y on the BeatStep.
  ~encoder_ch = 0;
  ~switch_ch = 1;  // send 0 to set to "off" colour, 127 to set to "on" colour, and 1-126 to set to custom colour.
                   // NOTE: does NOT affect actual value (or toggle state) of switch. Switch is purely physical.
                   //       Thus, on/off state of toggle needs to be handled in SW and sent to switch.
  ~animation_ch = 2;
  ~bank_btn_ch = 3;
  ~alt_switch_ch = 4;
  ~ring_ch = 5;
  ~flash_quarter_note = 6;
  ~steady = 0;

  // top row of switches (0-7) = cc 0-7, channel 2
  (0..7).do { |cc| cw.midiRadioButton(\deviceSelect, cc, \mft, ~switch_ch, cc: cc) };
  cw.saneValue(\deviceSelect, 0);
  cw.action(\deviceSelect, { |v| "Input device changed to %".format(v).postln });

  // bottom row of switches (8-15) = cc 8-15, channel 2
  (0..7).do { |padNum|
    var padBus = "padBus%".format(padNum).asSymbol;
    cw.midiTriggerButton(padBus, \mft, ~switch_ch, cc: padNum + 8);
    cw.select(padBus, \deviceSelect, (0..7).collect { |position| ~mpad.value(position, padNum) } );
  };

  (0..15).do { |knobNum|
    var knobBus = "knobBus%".format(knobNum).asSymbol;

    cw.midiCC(knobBus, \mft, ~encoder_ch, knobNum);
    cw.saneValue(knobBus, 0.5); // middle of the range
    cw.select(knobBus, \deviceSelect, (0..7).collect { |position| ~mknob.value(position, knobNum) } );
  };
  (0..15).do { |cc| cw.midiCC("animation%".format(cc).asSymbol, \mft, ~animation_ch, cc) };
  (0..15).do { |cc|
    var ring = "ring%".format(cc).asSymbol;

    cw.midiCC(ring, \mft, ~ring_ch, cc);
    cw.saneValue(ring, 87/127);
  };
  cw.saneValue(\animation0, 15/127);

  // Map device 0 to system parameters
  cw.warp(\bpm, ~mknob.value(0, 0), mul: 1/127, add: -60/127);

  ~h9knobCCs = [nil, nil, nil, nil,
                 28,  29,  30,  31,
                 11, nil,  26,  27,
                 22,  23,  24,  25];
  ~h9padCCs  = [71, nil, nil, nil,
                70,  17,  16, nil];
  ~mapDevice.value(\h9std, 2, 0, ~h9knobCCs, ~h9padCCs);
  ~mapDevice.value(\h9max, 3, 0, ~h9knobCCs, ~h9padCCs);

  cw.saneAll();
  cw
}.value;
)
