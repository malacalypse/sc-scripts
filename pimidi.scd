(
if (~cw.isNil.not) {
    // clean up any old one hangin' around
    var cw = ~cw;
    ~cw = nil;
    protect { cw.free };
};

~defaultTempo = 120;
~metro = TempoClock(~defaultTempo/60);

// basic setup
~fx_device_number = 1;
~h9_std_device_number = 2;
~h9_max_device_number = 3;
~h9knobCCs = [nil, nil, nil, nil,
               28,  29,  30,  31,
               11, nil,  26,  27,
               22,  23,  24,  25];
~h9padCCs  = [ 71, nil, nil, nil,
               70,  17,  16, nil];

~cw = {
  var cw = ClockWise({});
  var h9ccMap = {
    var cc = [];
    ~h9knobCCs.do { |i| if (i.isNil.not) { cc = cc.add(i) } };
    cc.sort;
    cc.collect { |i| ~h9knobCCs.indexOf(i) };
  }.value;
  var handleH9sysex = { |device_number, data|
    var cc_values = [], progAscii = "";
    var regex = "^\\[[^\\]]+\\][ 0-9]+\r\n +([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+)";
    // Only respond if it's an H9 program dump
    if (data[0..2] == Int8Array[0xF0, 0x1C, 0x70] && data[4] == 0x4F) {
      data[5..data.size - 1].collect { |i| progAscii = progAscii ++ i.asAscii };
      cc_values = progAscii.findRegexp(regex);
      if (cc_values.size == 13) {
        cc_values = cc_values[1..cc_values.size].collect { |entry| ("0x" ++ entry[1]).interpret }.reverse.swap(7, 10).swap(8, 9);
        h9ccMap.do { |cc, index|
          var point = ~mknob.(device_number, cc),
              value = (cc_values[index]/32768.0);
          cw.set(point, value);
          if (cw.point(point).hasResponder(\resane)) {
            cw.point(point).performFirst(\resane, value);
          } {
            cw.saneValue(point, value);
          }
        };
      } { "H9 program dump for % could not be parsed.".format(device_number).postln };
    };
  };
  ~requestH9Program = { |device| cw.getMidiOut(device).sysex(Int8Array[ 0xF0, 0x1C, 0x70, 0, 0x4E, 0xF7]) };

  cw.warp(\tempo, \bpm, mul:60);

  ~mknob = { |pos, knobNum| "ccMatrix%knob%".format(pos, knobNum).asSymbol };
  ~mpad  = { |pos, padNum| "ccMatrix%pad%".format(pos, padNum).asSymbol };
  ~mapDevice = {
    arg point, position, ch = 0, knobCCs, padCCs;
    knobCCs.do { |knobCC, knobNum| if (knobCC.isNil.not) { cw.midiCC(~mknob.(position, knobNum), point, ch, knobCC) } };
    padCCs.do  { |padCC,  padNum| if (padCC.isNil.not) { cw.midiTriggerButton(~mpad.(position, padNum), point, ch, cc: padCC) } };
  };

  MIDIClient.init;
  CmdPeriod.add(c);

  // Initialize Devices
  cw.midiDevice(\mft,     "MIDI Fighter Twister");
  cw.midiDevice(\ks,      "keystep");

  cw.midiDevice(\h9_std,   "H9 Standard");
  cw.sysex(\h9_std, handleH9sysex.(~h9_std_device_number, _));
  cw.midiProgram(\h9_std_pch, \h9_std, 0, inOnly: true);
  cw.action(\h9_std_pch, { |num| ~requestH9Program.(\h9_std); });

  cw.midiDevice(\h9_max,   "H9 Pedal");
  cw.sysex(\h9_max, handleH9sysex.(~h9_max_device_number, _));
  cw.midiProgram(\h9_max_pch, \h9_max, 0, inOnly: true);
  cw.action(\h9_max_pch, { |num| ~requestH9Program.(\h9_max); });

  cw.midiDevice(\rytm,    "analog rytm");
  cw.midiDevice(\dn,      "digitone");
  cw.midiDevice(\moog,    "subsequent 37");
  cw.midiDevice(\prophet, "rev2");
  // cw.midiDevice(\rtpout,  "0-0");
  // cw.midiDevice(\rtpin,   "0-1");
  cw.midiDevice(\din,     "pisound");

  // Very simple note routing for now
  cw.midiPerf(\keyBus, \ks, 0);
  cw.midiPerf(\keyBus, \din, 0);
  cw.midiPerf(\keyBus, \dn, 9); // Autochannel Digitone

  // Set up clocking
  cw.tempoClock(\tempo, \clock, ~metro);
  cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
  cw.midiClock(\clock, \dn, outOnly:true);
  cw.midiClock(\clock, \mft, outOnly:true);
  cw.midiClock(\clock, \ks, outOnly:true);
  cw.midiClock(\clock, \din, outOnly:true);
  cw.midiClock(\clock, \h9_std, outOnly:true);
  cw.midiClock(\clock, \h9_max, outOnly:true);
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
  cw.action(\deviceSelect, { |v|
    if (v == ~h9_std_device_number) {
        ~requestH9Program.(\h9_std);
    };
    if (v == ~h9_max_device_number) {
        ~requestH9Program.(\h9_max);
    };
  });

  // bottom row of switches (8-15) = cc 8-15, channel 2
  (0..7).do { |padNum|
    var padBus = "padBus%".format(padNum).asSymbol;
    cw.midiTriggerButton(padBus, \mft, ~switch_ch, cc: padNum + 8);
    cw.select(padBus, \deviceSelect, (0..7).collect { |position| ~mpad.(position, padNum) } );
  };

  (0..15).do { |knobNum|
    var knobBus = "knobBus%".format(knobNum).asSymbol;

    cw.midiCC(knobBus, \mft, ~encoder_ch, knobNum);
    cw.select(knobBus, \deviceSelect, (0..7).collect { |position|
        var point = ~mknob.(position, knobNum);
        if ((position != ~h9_std_device_number) && (position != ~h9_max_device_number)) {
          cw.saneValue(point, 0)
        };
        point
    } );
  };
  (0..15).do { |cc| cw.midiCC("animation%".format(cc).asSymbol, \mft, ~animation_ch, cc) };
  (0..15).do { |cc|
    var ring = "ring%".format(cc).asSymbol;

    cw.midiCC(ring, \mft, ~ring_ch, cc);
    cw.saneValue(ring, 87/127);
  };
  cw.saneValue(\animation0, 15/127);

  // Map device 0 to system parameters
  cw.resane(~mknob.(0,0), (~defaultTempo + 60)/127);
  cw.warp(\bpm, ~mknob.(0, 0), mul: 1/127, add: -60/127);

  // Pads:
  // cw.synthArg(~mknob.value(~fx_position, 5), \lin.asSpec, \mono, ~analogIn);
  // cw.saneValue(~mknob.value(~fx_position, 5), 0);
  cw.action(~mpad.(~fx_device_number, 4), { "Saning...".postln; cw.saneAll(); });
  cw.action(~mpad.(~fx_device_number, 7), { "Resyncing".postln; cw.syncAll(); });

  ~mapDevice.(\h9_std, ~h9_std_device_number, 0, ~h9knobCCs, ~h9padCCs);
  ~mapDevice.(\h9_max, ~h9_max_device_number, 0, ~h9knobCCs, ~h9padCCs);

  cw.syncAll;
  cw
}.value;
)
