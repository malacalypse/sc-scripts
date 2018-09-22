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

  MIDIClient.init;
  CmdPeriod.add(c);

  // Initialize Devices
  cw.midiDevice(\mft,      "MIDI Fighter Twister");

  // TEMPO / CLOCK
  cw.tempoClock(\tempo, \clock, ~metro);
  cw.midiClock(\clock, \mft, outOnly:true);

  // Set up MIDI Fighter Twister as a matrix CC controller. 0 is top left, 3 is top right, 15 is bottom right.
  // MFT Setup: Encoder 0 on bank 0 is dual purpose: tempo/volume. Push and turn for tempo, turn normally for volume.
  //            This is accomplished by setting it up as a secondary encoder on push (channel 4 gets tempo updates).
  //  - Switches 0-7 choose output routing to device 0-7
  //  - Switches 8-15 send CC values to CC matrix Switch points 0-7
  //  - Encoders 0-15 are routed to the CC matrix patch points 1-16 for the selected device 0-7
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
  (0..7).do { |index|
    var padBus = "padBus%".format(index).asSymbol;
    cw.midiTriggerButton(padBus, \mft, ~switch_ch, cc: index + 8);
    cw.select(padBus, \deviceSelect, (0..7).collect { |n| "ccMatrix%pad%".format(n, index).asSymbol } );
  };

  // Encoder 0 is always tempo. Map other encoders to matrix points.
  (1..15).do { |cc|
    var knobBus = "knobBus%".format(cc).asSymbol;

    cw.midiCC(knobBus, \mft, ~encoder_ch, cc);
    cw.saneValue(knobBus, 0.5); // middle of the range
    cw.select(knobBus, \deviceSelect, (0..7).collect { |device| "ccMatrix%knob%".format(device, cc).asSymbol } );
  };
  (0..15).do { |cc| cw.midiCC("animation%".format(cc).asSymbol, \mft, ~animation_ch, cc) };
  (0..15).do { |cc|
    var ring = "ring%".format(cc).asSymbol;
    cw.midiCC(ring, \mft, ~ring_ch, cc);
    cw.saneValue(ring, 80/127);
  };
  cw.saneValue(\animation0, 15/127);

  cw.midiCC(\ccMatrix0, \mft, ~encoder_ch, 0);
  cw.warp(\tempo, \bpm, mul:60);
  cw.warp(\bpm, \ccMatrix0, mul: 1/127, add: -60/127);
  cw.saneValue(\ccMatrix0, 0.5);

  cw.saneAll();
  cw
}.value;
)
