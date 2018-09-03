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
*/
(
// MIDIClient.disposeClient;
// MIDIClient.init;
// MIDIIn.connectAll;
s.latency = 0;
s.recChannels = 2;
s.recSampleFormat = "int24";

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
  ~metro = metro = TempoClock(self.efx, 111/60);

  ~gateRates = [0, 8, 6, 4, 3, 2, 1, 0.5];
  // divisions of a beat, 0 means none

  Routine({
    ~beatSyncBus = Bus.control(s, 1);

    // MZero's kickass delay/reverb synched effects stack
    ~pbj = {
      arg tempo = 2,
      beatsPerBar = 4,
      gateSelect = 0,
      hpSweep = 20, lpSweep = 20000,
      dlyLevel = 0.0, dlyMix = -0.75, dlyBeats = 8, dlyDecay = 1.4, dlyPos = -0.3,
      revLevel = 0.2, revRoom = 0.6, revDamp = 0.7,
      dryLevel = 0.8,
      loGainDb = 0.0, midGainDb = 0.0, hiGainDb = 0.0, loFreq = 80, hiFreq = 2000,
      outLevel = 0.7
      ;

      var beat = Phasor.ar(InTrig.kr(~beatSyncBus.index), tempo / s.sampleRate, 0, beatsPerBar);
      // a useful ar signal that is the beat within the bar

      var in = SoundIn.ar([0,1]);

      var sweepHi = BHiPass.ar(in,       Lag2UD.kr(hpSweep, 0.05, 0.01));
      var sweepLo = BLowPass.ar(sweepHi, Lag2UD.kr(lpSweep, 0.05, 0.01));
      var sweep   = sweepLo;

      // these feel better than the more severe BLowPass4 / BHiPass4
      // or the less sever LPF / HPF

      var gateRate = Select.kr(gateSelect, ~gateRates);
      var gateOn   = Lag2UD.kr(gateSelect > 0, 0.05, 0.05);
      var gate     = Lag2UD.ar((beat * gateRate).frac < 0.5, 0.005, 0.010);
      var gated    = sweep * (gate * gateOn + (1 - gateOn));

      var sig = gated;

      var slowestTempo = 50/60;
      var slowest16th  = slowestTempo.reciprocal/4;
      var maxDelay     = 16*slowest16th;

      var time16th = Lag2.kr(tempo.reciprocal/4, 0.75);
      var dlyTime  = Lag2.kr(dlyBeats*time16th,  0.75);

      var dlyFixL  = CombL.ar(sig[0], 3*slowest16th, 3*time16th, dlyDecay);
      var dlyFixR  = CombL.ar(sig[1], 5*slowest16th, 5*time16th, dlyDecay);
      var dlyVar   = CombL.ar(sig,   16*slowest16th, dlyTime,    dlyDecay);
      var dly      = LeakDC.ar(XFade2.ar([dlyFixL, dlyFixR], dlyVar, dlyMix)) * dlyLevel;
      var splitDly = Pan2.ar(dly, dlyPos);
      var dlyToMix = [splitDly[0][0], splitDly[1][0]];
      var dlyToRev = [splitDly[0][1], splitDly[1][1]];

      var rev = FreeVerb2.ar(
        sig[0] + dlyToRev[0],
        sig[1] + dlyToRev[1],
        mix:1, room:revRoom, damp:revDamp,
        mul: revLevel);

      var dry = sig * dryLevel;

      var sum = Mix.new([dry, rev, dlyToMix]);

      var eqL = sum * midGainDb.dbamp;
      var eqM = BLowShelf.ar(eqL, loFreq, db:(loGainDb - midGainDb));
      var eqH = BHiShelf.ar(eqM, hiFreq, db:(hiGainDb - midGainDb));

      var eqAll = eqH;

      Out.ar(0,  eqAll * outLevel);
    }.play;

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

      // Set up clocking
      cw.tempoClock(\tempo, \clock, ~metro);

      cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
      cw.midiClock(\clock, \dn, outOnly:true);
      cw.midiClock(\clock, \bs, outOnly:true);
      cw.midiClock(\clock, \ks, outOnly:true);
      cw.midiClock(\clock, \h9std, outOnly:true);
      cw.midiClock(\clock, \h9max, outOnly:true);
      cw.midiClock(\clock, \moog, outOnly: true);
      cw.midiClock(\clock, \prophet, outOnly: true);

      /* TODO : disentangle this stuff and figure out how to control the clock */
      cw.synthArg(\tempo);
      cw.warp(\tempo, \bpm, mul:60);
      cw.warp(\bpm, \ccMatrixVol7, mul: 1/127, add: -60/127);

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
      //  - Lower row of pads (9-16) send CC 80-87, gate mode +
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

      // Set up synthArgs and Actions for internal controls, all on device 7
      cw.action(\ccMatrix7pad7, { "Resyncing".postln; cw.syncAll(); });

      // 3 Band Eq
      cw.synthArg(\ccMatrix7knob8, \boostcut.asSpec, \loGainDb);
      cw.synthArg(\midGainDb, \boostcut.asSpec); // unmapped for now
      cw.synthArg(\ccMatrix7knob0, \boostcut.asSpec, \hiGainDb);
      cw.synthArg(\ccMatrix7knob9, \midfreq.asSpec, \loFreq);
      cw.synthArg(\ccMatrix7knob1, ControlSpec(440, 10000, \exp), \hiFreq);

      // Stutter Gate
      cw.synthArg(\ccMatrix7knob12, ControlSpec(0, ~gateRates.size), \gateSelect);

      // Reverb
      cw.synthArg(\ccMatrix7knob2, \lin.asSpec, \revRoom);
      cw.synthArg(\ccMatrix7knob3, \lin.asSpec, \revDamp);

      // Delay
      cw.synthArg(\ccMatrix7knob4, \decay.asSpec, \dlyDecay);
      cw.synthArg(\ccMatrix7knob5, \bipolar.asSpec, \dlyMix);
      cw.synthArg(\ccMatrix7knob6, \rate.asSpec, \dlyBeats);
      cw.synthArg(\ccMatrix7knob7, \bipolar.asSpec, \dlyPos);

      // Effects
      cw.synthArg(\ccMatrix7knob10, \freq.asSpec, \hpSweep);
      cw.synthArg(\ccMatrix7knob11, \freq.asSpec, \lpSweep);

      // Levels
      cw.synthArg(\ccMatrix7knob13, \amp.asSpec, \dryLevel);
      cw.synthArg(\ccMatrix7knob14, \amp.asSpec, \revLevel);
      cw.synthArg(\ccMatrix7knob15, \amp.asSpec, \dlyLevel);

      // cw.synthArg(\outLevel, nil, \outLevel);   // unmapped

      // Pad assignments for re-saning parameters
      cw.triggerSane(\ccMatrix7pad0, [\loGainDb, \midGainDb, \hiGainDb, \loFreq, \hiFreq]); // pad 8, far left
      cw.triggerSane(\ccMatrix7pad2, [\revRoom, \revDamp]); // pad 11
      cw.triggerSane(\ccMatrix7pad3, [\dlyDecay, \dlyMix, \dlyBeats]); // pad 12
      cw.triggerSane(\ccMatrix7pad1, [\hpSweep, \lpSweep, \gateSelect]); // pad 10

      // Debug output
      cw.action(\ccMatrix7pad0, { "EQ saning...".postln; });
      cw.action(\ccMatrix7pad2, { "Reverb saning...".postln; });
      cw.action(\ccMatrix7pad3, { "Delay saning...".postln; });
      cw.action(\ccMatrix7pad1, { "FX saning...".postln; });

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
};
)
