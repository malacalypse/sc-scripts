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
*  - Use pluggable effects stack
*  - Support recording
*  - Support gallop mode (delay divisions by multiples and fractions of e)
*  - Support MIDI clock in / beat sync to external clock source
*  - Filter MIDI clock but allow start/stop from clock slaves
*  - Implement Mono-Sum mode on input
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
        ~server.sync;

        // inspired by MZero's kickass delay/reverb synched effects stack of the same name
        ~pbj = {
          arg tempo = 2;

          // Core effects stack:
          // in -> overdrive -> delay -> reverb -> amp simulator -> out
          //   `-> chorus    /       `----------/
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
          ~ampIn    = Bus.audio(s, 2);

          // And some control busses for the SynthDefs
          ~bpmBus   = Bus.control(s, 1);
          ~divBus   = Bus.control(s, 1);

          // Input Source Mixing and Sends
          ~sources  = Group.new;
          ~analogIn = Synth.new(\m2sMixer, [input: ~inBus, output: ~fxBus], ~sources);

          // Effects Stack
          ~effects    = Group.after(~sources);
          ~chorus     = Synth.new(\chorus,      [input: ~fxBus, output: ~dlyIn], ~effects, \addToTail);
          ~overdrive  = Synth.new(\overdrive,   [input: ~fxBus, output: ~dlyIn], ~effects, \addToTail);
          ~delay      = Synth.new(\delay_ppong, [input: ~dlyIn, output: ~dlyOut, wetdry: 1], ~effects, \addToTail);
          ~delayMix   = Synth.new(\fxMixer,     [inOne: ~dlyIn, inTwo:  ~dlyOut, outThru: ~ampIn, outSend: ~revIn], ~effects, \addToTail);
          ~reverb     = Synth.new(\greyhole,    [input: ~revIn, output: ~ampIn], ~effects, \addToTail);
          ~amp        = Synth.new(\ampsim,      [input: ~ampIn, output: 0], ~effects, \addToTail);

          // Pipe the analogue input into the input bus
          { Out.ar(~inBus, Balance2.ar(SoundIn.ar(0), SoundIn.ar(1), 0)); }.play;
        }.value;

        ~server.sync;

        ~cw = {
          var cw = ClockWise(~pbj);
          CmdPeriod.add(cw);

          // Used to take the whole stack of knob, pad, and volume CCs and route
          //  the entire set to a new destination, sort of like a column switch on a
          //  crossbar matrix.

          // ~mapDevice.value(\destName, deviceNumber, channel, volCC, [array of knob CCs in order], [array of pad CCs in order]);
          //    destName : Symbol for midiDevice to route the data to/from
          //    deviceNumber : The crossbar allows for 8 devices to be routed between,
          //                   corresponding to the 8 pads on the top row of the BS.
          //                   This designates which device number should select this device.
          //                   E.g. a deviceNumber of 2 would mean that when the 3rd pad is selected,
          //                   the CCs sent by the BS would be routed to this device.
          //    channel : which channel to remap the CCs onto when sending to this device.
          //    volCC : which CC you wish to handle the volume control's output on your device.
          //    [arrays] : The knobs (0..15) and pads (0..7) are mapped, in sequential order, to the CCs you specify here.
          //               For instance, if you specify [1, 2, 3, 4] for the knob CC array, then the first four knobs will send
          //               their values to CCs 1, 2, 3, and 4 respectively, the other knobs will be routed to nowhere.
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

          // Drop in your own hardware initialization and core routing here
          // Initialize Devices
          cw.midiDevice(\bs,      "beatstep");
          cw.midiDevice(\ks,      "keystep");
          cw.midiDevice(\h9std,   "H9 Standard");
          cw.midiDevice(\h9max,   "H9 Pedal");
          cw.midiDevice(\rytm,    "analog rytm");
          cw.midiDevice(\dn,      "digitone");
          cw.midiDevice(\moog,    "subsequent 37");
          cw.midiDevice(\prophet, "rev2");

          // RTP Midi Virtual MIDI ports
          cw.midiDevice(\rtpin, "0-0", inOnly: true);
          cw.midiDevice(\rtpout, "0-1", outOnly: true);

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

          // TEMPO / CLOCK
          cw.tempoClock(\tempo, \clock, ~metro);

          cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
          cw.midiClock(\clock, \dn, outOnly:true);
          cw.midiClock(\clock, \bs, outOnly:true);
          cw.midiClock(\clock, \ks, outOnly:true);
          cw.midiClock(\clock, \h9std, outOnly:true);
          cw.midiClock(\clock, \h9max, outOnly:true);
          cw.midiClock(\clock, \moog, outOnly: true);
          cw.midiClock(\clock, \prophet, outOnly: true);

          cw.synthArg(\tempo);
          cw.warp(\tempo, \bpm, mul:60);
          cw.warp(\bpm, \ccMatrixVol7, mul: 1/127, add: -60/127);
          cw.synthArg(\ccMatrixVol7, ControlSpec(60, 127, step: 1), \bpm, ~delay);

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
          cw.midiTriggerButton(\sendStart, \bs, note: 119);
          cw.midiTriggerButton(\sendStop, \bs, note: 118);
          cw.action(\bpm, { |v| "BPM is now %".format(v).postln; });
          /* END OF TEMPO/CLOCK SECTION */

          // Set up BeatStep as a matrix CC controller:
          //  - buttons 0-7 choose output routing (devices 0..7, 7 is the internal effects stack)
          //  - buttons 8-15 send cc to pad matrix.
          //  - knobs   0-15 are routed to knob matrix.
          // Beatstep configuration:
          //  - Factory defaults (control pads send MIDI notes) +
          //  - All knobs except volume: relative encoding type 1 with no speedup +
          //  - Control channel: 15 = MIDI 16 / set as default global channel +
          //  - Sequence channel: 0 = MIDI 1.
          // Connections are to a ccMatrix symbol:
          //  - ccMatrixXpadY (X = 0..7, Y=0..7) connect device X to pad Y on the BeatStep.
          //  - ccMatrixXknobY (X = 0..7, Y = 0..15) connect device X to knob Y on the BeatStep.
          // Right now I'm leaving the main volume knob (CC #7) unmapped. It is set to absolute on the BS.
          ~bs_control_channel = 15;
          ~deviceIndex = (0..7);

          // Volume knob (or expr)
          cw.midiCC(\ccMatrixVolIn, \bs, ~bs_control_channel, 7);
          ~volBus = ~deviceIndex.collect { |index| "ccMatrixVol%".format(index).asSymbol };
          cw.select(\ccMatrixVolIn, \deviceSelect, ~volBus);

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
            var padBus = "ccMatrix%padIn".format(index).asSymbol;

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
            var knobBus = "ccMatrix%knobIn".format(index).asSymbol;

            cw.midiEncoder(knobBus, \bs, ~bs_control_channel, cc, mode: \offset, inOnly: true);
            cw.saneValue(knobBus, 0.5); // middle of the range

            // Route point to currently chosen device row in matrix
            ~ccPatchRow = ~deviceIndex.collect { |p|
              var ccMatrix = "ccMatrix%knob%".format(p, index).asSymbol;
              ccMatrix;
            };
            cw.select(knobBus, \deviceSelect, ~ccPatchRow);
          };
          // End of hardware init and core routing.

          // AUDIO PROCESSOR CONTROLS - Device 7
          //  Knob:    1           2           3             4
          //           input gain  chorus amt  overdrive amt [unmapped]
          //
          //  Knob:    9           10          11            12
          //           delay time  delay fdbk  rev send*     rev. mix
          //
          //  Knob:    5           6           7             8
          //           reverb size earlyref/dif hfdecay     reverb tails (rt60)
          //
          //  Knob:    13          14          15            16
          //           amp type    amp crunch  compressor    tone
          //
          //  Pads:  1 [Sane All] [Preset 1] [Preset 2] [Preset 3] 4
          //         5 [Preset 4] [Preset 5] [Mono Sum] [Sync All] 8
          //
          // Note: The delay reverb send is a bidirectional control AROUND the delay.
          //  -1 = only dry is sent to the reverb. Tails are sent past to the output directly.
          //   0 = dry + wet are fully sent only to the reverb. Nothing bypasses the reverb.
          //   1 = only wet (tails) is sent to the reverb, dry bypasses the reverb.
          // The delay is always set to full wet internally to allow this control.

          // Knobs: point, spec, symbol, node
          cw.synthArg(\ccMatrix7knob0, \lin.asSpec, \gain, ~analogIn);
          cw.synthArg(\ccMatrix7knob1, \lin.asSpec, \wetdry, ~chorus);
          cw.synthArg(\ccMatrix7knob2, \lin.asSpec, \wetdry, ~overdrive);
          cw.synthArg(\ccMatrix7knob3, \lin.asSpec, \distortion, ~overdrive);
          cw.synthArg(\ccMatrix7knob4, \lin.asSpec, \size, ~reverb);
          cw.synthArg(\ccMatrix7knob5, \lin.asSpec, \diffusion, ~reverb);
          cw.synthArg(\ccMatrix7knob6, \lin.asSpec, \hfdecay, ~reverb);
          cw.synthArg(\ccMatrix7knob7, \lin.asSpec, \tail, ~reverb);
          cw.synthArg(\ccMatrix7knob8, \lin.asSpec, \division, ~delay);
          cw.synthArg(\ccMatrix7knob9, \amp.asSpec, \feedback, ~delay);
          cw.synthArg(\ccMatrix7knob10, ControlSpec(0, 1, SegWarp([0, 1, 1])), \sendOne, ~delayMix);
          cw.synthArg(\ccMatrix7knob10, ControlSpec(1, 0, SegWarp([1, 1, 0])), \sendTwo, ~delayMix);
          cw.synthArg(\ccMatrix7knob11, \lin.asSpec, \wetdry, ~reverb);
          cw.synthArg(\ccMatrix7knob12, ControlSpec(0, 8, step: 1), \tonestack, ~amp);
          cw.synthArg(\ccMatrix7knob13, \lin.asSpec, \crunch, ~amp);
          cw.synthArg(\ccMatrix7knob14, \lin.asSpec, \punch, ~amp);
          cw.synthArg(\ccMatrix7knob15, \lin.asSpec, \tone, ~amp);

          // Pads:
          cw.triggerSane(\ccMatrix7pad0, [\loGainDb, \midGainDb, \hiGainDb, \loFreq, \hiFreq]); // pad 8, far left
          cw.synthArg(\ccMatrix7pad6, \lin.asSpec, \mono, ~analogIn);
          cw.saneValue(\ccMatrix7pad6, 0);
          cw.action(\ccMatrix7pad0, { "Saning...".postln; });
          cw.action(\ccMatrix7pad6, { "Mono Sum is %".format().postln; });
          cw.action(\ccMatrix7pad7, { "Resyncing".postln; cw.syncAll(); });

          // Debug
          (0..15).do { |n|
            cw.action("ccMatrix7knob%".format(n).asSymbol, { |v| "Knob % is now %".format(n, v).postln; });
          };

          // Map H9 effects boxes to device columns 5 and 6
          ~h9knobCCs = (22..31);
          ~h9padCCs = [71, 17, 16, 70];
          ~mapDevice.value(\h9std, 5, 0, 11, ~h9knobCCs, ~h9padCCs);
          ~mapDevice.value(\h9max, 6, 0, 11, ~h9knobCCs, ~h9padCCs);

          cw;
        }.value;

        2.sleep;
        // ~cw.saneAll;
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
