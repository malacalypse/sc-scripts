/***
* pifx.scd : Effects stack and MIDI Router
*
* With deep appreciation to Mark Lentczner (https://github.com/mzero)
* A lot of this code is borrowed or outright stolen from his genius pbj script.
*
* Requires:
* https://github.com/mzero/crunch-clockwise
* At least one stereo input and one stereo output
* As many USB or DIN midi devices as you can jam into your pi.
*
* Todo:
*  - Test stereo behaviour (I think the delay is mono-summing)...
*  - Support recording
*  - Support MIDI clock in / beat sync to external clock source
*  - Filter MIDI clock but allow start/stop from clock slaves
*/
(
var main = {
  // MIDIClient.disposeClient;
  // MIDIClient.init;
  // MIDIIn.connectAll;
  s.latency = 0;
  s.recChannels = 2;
  s.recSampleFormat = "int24";
  e = 2.71828;
  // o = OSCresponderNode(s.addr, '/tr', { |time, resp, msg| msg.postln }).add;

  if (~pifx.isNil.not) {
    // clean up any old one hangin' around
    var pifx = ~pifx;
    ~pifx = nil;
    protect { pifx.freeUp };
  };

  ~pifx = Environment.make { |self|
    var metro;

    self.know = true;

    ~server = s;
    ~metro = metro = TempoClock(self.efx, 120/60);
    ~beatSyncBus = Bus.control(s, 1);

    Routine({
      SynthDef(\analogIn, { arg output; Out.ar(output, SoundIn.ar([0, 1])); }).add;

      ~server.sync;

      // inspired by MZero's kickass delay/reverb synched effects stack of the same name
      ~pbj = {
        // Core effects stack:
        // in -> chorus -> overdrive -> delay -> reverb -> amp simulator -> out
        //                                   `----------/
        //
        // Delay can send clean only, tails only, or clean + tails to reverb.
        // Amp simulator has it's own crunch it can add too.
        // Other ideas include:
        //   - Switchable reverb types (FreeVerb2, Greyhole, JPverb, c_plate_x2)
        //   - Switchable delay types (some kind of pingpong, a modulated delay, and maybe a tape.)
        //   - Switchable chorus into flanger or phaser or wah
        //   - Switchable chorus - before, in series with, or after overdrive.
        // A pluggable effects stack and audio mixer.

        // Set up some busses for routing
        ~inBus    = Bus.audio(s, 2);
        ~fxBus    = Bus.audio(s, 2);
        ~dlyIn    = Bus.audio(s, 2);
        ~dlyOut   = Bus.audio(s, 2);
        ~revIn    = Bus.audio(s, 2);
        ~distIn   = Bus.audio(s, 2);

        // And some control busses for the SynthDefs
        ~bpmBus   = Bus.control(s, 1);
        ~divBus   = Bus.control(s, 1);

        // Input Source Mixing and Sends
        ~sources  = Group.new;
        ~analogIn = Synth.new(\analogIn, [output: ~inBus], ~sources);
        ~analogIn = Synth.new(\m2sMixer, [input: ~inBus, output: ~fxBus], ~sources, \addToTail);

        // Effects Stack
        ~effects    = Group.after(~sources);
        ~chorus     = Synth.new(\chorus,        [input: ~fxBus, output: ~satIn], ~effects, \addToTail);
        ~saturation = Synth.new(\fastoverdrive, [input: ~satIn, output: ~dlyIn], ~effects, \addToTail);
        ~delay      = Synth.new(\delay_ppong,   [input: ~dlyIn, output: ~dlyOut, wetdry: 1], ~effects, \addToTail);
        ~delayMix   = Synth.new(\fxMixer,       [inOne: ~dlyIn, inTwo:  ~dlyOut,
          outThru: ~distIn, outSend: ~revIn], ~effects, \addToTail);
        ~reverb     = Synth.new(\jpverb,        [input: ~revIn, output: ~distIn], ~effects, \addToTail);
        ~heat       = Synth.new(\digitalheat,   [input: ~distIn, output: 0], ~effects, \addToTail);
      }.value;

      ~server.sync;

      ~cw = {
        var cw = ClockWise(~pbj);
        CmdPeriod.add(cw);
        cw.warp(\tempo, \bpm, mul:60);

        // Used to take the whole stack of knob, pad, and volume CCs and route
        //  the entire set to a new destination, sort of like a column switch on a
        //  crossbar matrix.

        // ~mapDevice.value(\destName, deviceNumber, channel, [array of knob CCs in order], [array of pad CCs in order]);
        //    destName : Symbol for midiDevice to route the data to/from
        //    deviceNumber : The crossbar allows for 8 devices to be routed between,
        //                   corresponding to the 8 pads on the top row of the BS.
        //                   This designates which device number should select this device.
        //                   E.g. a deviceNumber of 2 would mean that when the 3rd pad is selected,
        //                   the CCs sent by the BS would be routed to this device.
        //    channel : which channel to remap the CCs onto when sending to this device.
        //    [arrays] : The knobs (0..15) and pads (0..7) are mapped, in sequential order, to the CCs you specify here.
        //               For instance, if you specify [1, 2, 3, 4] for the knob CC array, then the first four knobs will send
        //               their values to CCs 1, 2, 3, and 4 respectively, the other knobs will be routed to nowhere.
        ~mknob = { |pos, knobNum| "ccMatrix%knob%".format(pos, knobNum).asSymbol };
        ~mpad  = { |pos, padNum| "ccMatrix%pad%".format(pos, padNum).asSymbol };
        ~mapDevice = {
          arg point, position, ch = 0, knobCCs, padCCs;
          knobCCs.do { |knobCC, knobNum| if (knobCC.isNil.not) { cw.midiCC(~mknob.value(position, knobNum), point, ch, knobCC) } };
          padCCs.do  { |padCC,  padNum| if (padCC.isNil.not) { cw.midiTriggerButton(~mpad.value(position, padNum), point, ch, cc: padCC) } };
        };

        // Drop in your own hardware initialization and core routing here
        // Initialize Devices
        cw.midiDevice(\mft,     "MIDI Fighter Twister");
        cw.midiDevice(\ks,      "keystep");
        cw.midiDevice(\din,     "pisound");
        cw.midiDevice(\h9std,   "H9 Standard");
        cw.midiDevice(\h9max,   "H9 Pedal");
        cw.midiDevice(\rytm,    "analog rytm");
        cw.midiDevice(\dn,      "digitone");
        cw.midiDevice(\moog,    "subsequent 37");
        cw.midiDevice(\prophet, "rev2");

        // RTP Midi Virtual MIDI ports
        // cw.midiDevice(\rtpin, "0-0", inOnly: true);
        // cw.midiDevice(\rtpout, "0-1", outOnly: true);

        // Very simple note routing for now
        cw.midiPerf(\keyBus, \ks, 0);
        cw.midiPerf(\keyBus, \din, 0);
        cw.midiPerf(\keyBus, \dn, 9); // Autochannel Digitone
        // cw.midiPerf(\keyBus, \rtpout, 0);
        // cw.midiPerf(\keyBus, \rtpin, 0);
        // Channel 5 is Moog - by default DN Trck Midi1 is also 5.
        cw.midiPerf(\gch5, \dn, 4);
        cw.midiPerf(\gch5, \moog, 4);
        // Channel 6 is Rev2
        cw.midiPerf(\gch6, \dn, 5);
        cw.midiPerf(\gch6, \prophet, 5);

        // TEMPO / CLOCK
        cw.tempoClock(\tempo, \clock, ~metro);

        cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
        cw.midiClock(\clock, \dn, outOnly:true);
        cw.midiClock(\clock, \mft, outOnly:true);
        cw.midiClock(\clock, \ks, outOnly:true);
        cw.midiClock(\clock, \din, outOnly:true);
        cw.midiClock(\clock, \h9std, outOnly:true);
        cw.midiClock(\clock, \h9max, outOnly:true);
        cw.midiClock(\clock, \moog, outOnly: true);
        cw.midiClock(\clock, \prophet, outOnly: true);

        cw.warp(\bpm, ~mknob.value(0, 0), mul: 1/127, add: -60/127);
        cw.synthArg(~mknob.value(0, 0), ControlSpec(60, 127, step: 1), \bpm, ~delay);

        cw.action(\sendStart, {
          metro.playNextBar({
            cw.point(\clock).distribute(\start);
            nil;
          });
          "MIDI start queued up".postln;
        });
        cw.action(\sendStop, {
          metro.playNextBar({
            cw.point(\clock).distribute(\stop);
            nil;
          });
          "MIDI stop triggered.".postln;
        });
        cw.action(\bpm, { |v| "BPM is now %".format(v).postln; });
        /* END OF TEMPO/CLOCK SECTION */

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

        // End of hardware init and core routing.

        // AUDIO PROCESSOR CONTROLS - Device 7
        //  Knob:    1           2           3             4
        //           input gain  chorus amt  overdrive amt overdrive dist
        //
        //  Knob:    5           6           7             8
        //           reverb size earlyref/dif hfdecay     reverb tails (rt60)
        //
        //  Knob:    9           10          11            12
        //           delay time  delay fdbk  rev send*     rev. mix
        //
        //  Knob:    13          14          15            16
        //           [unmapped waiting for crunch and tone controls]
        //
        //  Pads:  1 [Sane All] [Preset 1] [Preset 2] [Preset 3] 4
        //         5 [Preset 4] [Preset 5] [Mono Sum] [Sync All] 8
        //
        // Note: The delay reverb send is a bidirectional control AROUND the delay.
        //  -1 = only dry is sent to the reverb. Tails are sent past to the output directly.
        //   0 = dry + wet are fully sent only to the reverb. Nothing bypasses the reverb.
        //   1 = only wet (tails) is sent to the reverb, dry bypasses the reverb.
        // The delay is always set to full wet internally to allow this control.

        ~fx_position = 1;
        // Knobs: point, spec, symbol, node
        cw.synthArg(~mknob.value(~fx_position, 0), ControlSpec(1, 2, \db), \gain, ~analogIn);
        cw.synthArg(~mknob.value(~fx_position, 1), \lin.asSpec, \mix, ~chorus);
        cw.synthArg(~mknob.value(~fx_position, 2), \lin.asSpec, \mix, ~saturation);
        cw.synthArg(~mknob.value(~fx_position, 3), \lin.asSpec, \mix, ~heat);
        cw.synthArg(~mknob.value(~fx_position, 4), \lin.asSpec, \size, ~reverb);
        cw.synthArg(~mknob.value(~fx_position, 5), \lin.asSpec, \hfdecay, ~reverb);
        cw.synthArg(~mknob.value(~fx_position, 6), \lin.asSpec, \tail, ~reverb);
        cw.synthArg(~mknob.value(~fx_position, 7), \lin.asSpec, \mix, ~reverb);
        cw.synthArg(~mknob.value(~fx_position, 8), \lin.asSpec, \division, ~delay);
        cw.synthArg(~mknob.value(~fx_position, 9), \amp.asSpec, \feedback, ~delay);
        cw.synthArg(~mknob.value(~fx_position, 10), ControlSpec(0, 1, SegWarp([0, 1, 1])), \sendOne, ~delayMix);
        cw.synthArg(~mknob.value(~fx_position, 10), ControlSpec(1, 0, SegWarp([1, 1, 0])), \sendTwo, ~delayMix);
        cw.synthArg(~mknob.value(~fx_position, 11), \lin.asSpec, \mix, ~delay);
        cw.resane(~mknob.value(~fx_position, 12), 0);
        cw.resane(~mknob.value(~fx_position, 13), 0);
        cw.resane(~mknob.value(~fx_position, 14), 0);
        cw.resane(~mknob.value(~fx_position, 15), 0);
        // cw.synthArg(~mknob.value(~fx_position, 12), ControlSpec(0, 8, step: 1), \tonestack, ~amp);
        // cw.synthArg(~mknob.value(~fx_position, 13), \lin.asSpec, \crunch, ~heat);
        // cw.synthArg(~mknob.value(~fx_position, 14), \lin.asSpec, \punch, ~amp);
        // cw.synthArg(~mknob.value(~fx_position, 15), \lin.asSpec, \tone, ~amp);

        // Pads:
        cw.triggerSane(~mpad.value(~fx_position, 4)); // lower left switch
        // cw.synthArg(~mknob.value(~fx_position, 5), \lin.asSpec, \mono, ~analogIn);
        // cw.saneValue(~mknob.value(~fx_position, 5), 0);
        cw.action(~mpad.value(~fx_position, 4), { "Saning...".postln; });
        cw.action(~mpad.value(~fx_position, 5), { "Mono Sum is %".format().postln; });
        cw.action(~mpad.value(~fx_position, 7), { "Resyncing".postln; cw.syncAll(); });

        // Debug
        (0..15).do { |n|
          cw.action(~mknob.value(~fx_position, n), { |v| "Knob % is now %".format(n, v).postln; });
        };

        // Map H9 effects boxes to device columns 2 and 3 - top right two switches
        ~h9knobCCs = [nil, nil, nil, nil,
                       28,  29,  30,  31,
                       11, nil,  26,  27,
                       22,  23,  24,  25];
        ~h9padCCs  = [71, nil, nil, nil,
                      70,  17,  16, nil];
        ~mapDevice.value(\h9std, 2, 0, ~h9knobCCs, ~h9padCCs);
        ~mapDevice.value(\h9max, 3, 0, ~h9knobCCs, ~h9padCCs);

        cw;
      }.value;

      ~server.sync;
      "syncing...".postln;
      ~cw.syncAll;
    }).play;

    ~metro.playNextBar(Routine({
      loop {
        var beat = metro.beatInBar.floor;
        if (beat == 0) {
          ~beatSyncBus.set(1);   // doesn't matter what it is set to, just > 0
        };
        ~cw.set(\beat, beat + 1);  // humans count from 1

        1.yield;
      }
    }));

    ~freeUp = { | self |
      self.pbj.stop;
      self.pbj.free;
      self.pbj = nil;
      self.cw.free;
      self.cw = nil;
      self.efx.free;
      self.efx = nil;
      self.metro.stop;
      self.metro = nil;
    }
  }.value;

  true
};

"effects_stack.scd".loadRelative(main.value);
)
