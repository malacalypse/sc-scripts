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
			var sweep = sweepLo;

			// these feel better than the more severe BLowPass4 / BHiPass4
			// or the less sever LPF / HPF

			var gateRate = Select.kr(gateSelect, ~gateRates);
			var gateOn = Lag2UD.kr(gateSelect > 0, 0.05, 0.05);
			var gate = Lag2UD.ar((beat * gateRate).frac < 0.5, 0.005, 0.010);
			var gated = sweep * (gate * gateOn + (1 - gateOn));

			var sig = gated;

			var slowestTempo = 50/60;
			var slowest16th  = slowestTempo.reciprocal/4;
			var maxDelay     = 16*slowest16th;

			var time16th = Lag2.kr(tempo.reciprocal/4, 0.75);
			var dlyTime  =  Lag2.kr(dlyBeats*time16th,  0.75);

			var dlyFixL  = CombL.ar(sig[0], 3*slowest16th, 3*time16th, dlyDecay);
			var dlyFixR  = CombL.ar(sig[1], 5*slowest16th, 5*time16th, dlyDecay);
			var dlyVar   =  CombL.ar(sig,   16*slowest16th, dlyTime,    dlyDecay);
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
      cw.midiDevice(\intctl, "1-0"); // a "dummy" bus used to re-route internal controls to/from the matrix

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
      // cw.tempoClock(\tempo, \clock, ~metro);

      cw.midiClock(\clock, \rytm); // Can be master clock if it wants to.
      cw.midiClock(\clock, \dn, outOnly:true);
      cw.midiClock(\clock, \bs, outOnly:true);
      cw.midiClock(\clock, \ks, outOnly:true);
      cw.midiClock(\clock, \h9std, outOnly:true);
      cw.midiClock(\clock, \h9max, outOnly:true);
      cw.midiClock(\clock, \moog, outOnly: true);
      cw.midiClock(\clock, \prophet, outOnly: true);

      /* TODO : disentangle this stuff and figure out how to control the clock
      cw.synthArg(\tempo);
			cw.warp(\tempo, \bpm, mul:60);
			cw.midiEncoder(\bpm, \ff, 12, 120, 1, inOnly:true);
			cw.midiEncoder(\bpm, \ff, 12, 121, 0.1, inOnly:true);
			cw.warp(\bpm, \bpm10, mul:10);
			cw.midiBend(\bpm10, \ff, 12, unmapped:true, outOnly:true);

			cw.midiCC(\beat, \ff, 12, 122, unmapped:true, outOnly:true);
			cw.midiTriggerButton(\sendStart, \ff, 12, note:122);
			cw.midiTriggerButton(\sendStart, \lp, 0, cc:19);
			cw.action(\sendStart, {
				metro.playNextBar({
					cw.point(\clock).distribute(\start);
					nil;
				});
				"MIDI start queued up".postln;
			});

      // Timers

			{
				var t1running = false;

				var t2 = 0;
				var t2running = true;

				var setUpTime = { |sym, minCC, secCC|
					var minSym = (sym.asString ++ "min").asSymbol;
					var secSym = (sym.asString ++ "sec").asSymbol;

					cw.action(sym, { |t|
						if (t >= 0) {
							cw.set(minSym, (t / 60).floor);
							cw.set(secSym, t % 60);
						} {
							cw.set(minSym, 100);
							cw.set(secSym, 100);
						}
					});

					cw.midiCC(minSym, \ff, 12, minCC, unmapped:true, outOnly:true);
					cw.midiCC(secSym, \ff, 12, secCC, unmapped:true, outOnly:true);
				};

				var update = { |blink=false|
					cw.set(\t1,
						if(s.recorder.isRecording && (t1running || blink),
						   s.recorder.duration,
						   -1));
					cw.set(\t2,
						if(t2running || blink,
						t2,
						-1));
				};

				setUpTime.value(\t1, 124, 125);
				setUpTime.value(\t2, 126, 127);



				cw.midiTriggerButton(\t1reset, \ff, 12, 124, inOnly:true);
				cw.action(\t1reset, {
					s.stopRecording;
					t1running = false;
					update.value;
				});

				cw.midiTriggerButton(\t1run, \ff, 12, 125, inOnly:true);
				cw.action(\t1run, {
					t1running = t1running.not;
					if (t1running)
						{ s.record; }
						{ s.pauseRecording; };
					update.value;
				});

				cw.midiTriggerButton(\t2reset, \ff, 12, 126, inOnly:true);
				cw.midiProgram(\t2reset, \dt, 13, inOnly:true);
				cw.action(\t2reset, { t2 = 0; update.value; });

				cw.midiTriggerButton(\t2run, \ff, 12, 127, inOnly:true);
				cw.action(\t2run, { t2running = t2running.not; update.value; });

				SystemClock.sched(0, Routine({
					var blink = true;
					3.yield;

					loop {
						if (t2running) { t2 = t2 + 1 };
						blink = blink.not;
						update.value(blink);
						1.yield;
					}
				}));

				update.value;

			}.value;
       */

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
      // End of hardware init and core routing.

      // Set up synthArgs and Actions for internal controls
      cw.action(\resync, { cw.syncAll(); });

			// 3 Band Eq
			cw.synthArg(\loGainDb, \boostcut.asSpec);
			cw.synthArg(\midGainDb, \boostcut.asSpec);
			cw.synthArg(\hiGainDb, \boostcut.asSpec);
			cw.synthArg(\loFreq, \midfreq.asSpec);
			cw.synthArg(\hiFreq, ControlSpec(440, 10000, \exp));

			// Stutter Gate
			cw.synthArg(\gateSelect, ControlSpec(0, ~gateRates.size));

      // Reverb
			cw.synthArg(\revRoom);
			cw.synthArg(\revDamp);

      // Delay
			cw.synthArg(\dlyDecay, ControlSpec(0, 15));
      cw.synthArg(\dlyMix, \bipolar.asSpec);
			cw.synthArg(\dlyBeats, ControlSpec(1, 16, 'lin', 1));
			cw.synthArg(\dlyPos, \bipolar.asSpec);

      // Effects
			cw.synthArg(\hpSweep, \freq.asSpec);
			cw.synthArg(\lpSweep, \freq.asSpec);

      // Levels
			cw.synthArg(\dryLevel);  // \amp.asSpec might be more common here
			cw.synthArg(\revLevel);  // but it doesn't give as fine a control
			cw.synthArg(\dlyLevel);  // over the extreme end, which in this case
			cw.synthArg(\outLevel);  // is more useful

      // Map all the controls to Device 7

      // Eqish things
      cw.midiCC(\hiGainDb,   \intctl, 0, 22);  // knob 0
			cw.midiCC(\hiFreq,     \intctl, 0, 23);  // knob 1
      cw.midiCC(\loGainDb,   \intctl, 0, 30);  // knob 8
			cw.midiCC(\loFreq,     \intctl, 0, 31);  // knob 9
      cw.midiCC(\midGainDb,  \intctl, 0, 21);  // knob X -- unmapped for now, let's see if I need it.

      // Effects
			cw.midiCC(\revRoom,    \intctl, 0, 24); // knob 2
			cw.midiCC(\revDamp,    \intctl, 0, 25); // knob 3
			cw.midiCC(\dlyDecay,   \intctl, 0, 26); // knob 4
			cw.midiCC(\dlyMix,     \intctl, 0, 27); // knob 5
			cw.midiCC(\dlyBeats,   \intctl, 0, 28); // knob 6
			cw.midiCC(\dlyPos,     \intctl, 0, 29); // knob 7

      cw.midiCC(\hpSweep,    \intctl, 0, 32); // knob 10
			cw.midiCC(\lpSweep,    \intctl, 0, 33); // knob 11
			cw.midiCC(\gateSelect, \intctl, 0, 34); // knob 12

      // Mixing
			cw.midiCC(\dryLevel,   \intctl, 0, 35, ControlSpec(127, 0)); // knob 13
			cw.midiCC(\revLevel,   \intctl, 0, 36); // knob 14
			cw.midiCC(\dlyLevel,   \intctl, 0, 37); // knob 15
			cw.midiCC(\outLevel,   \intctl, 0, 7);  // master volume

      // Pad assignments for re-saning parameters
      cw.triggerSane(\eqSane, [\loGainDb, \midGainDb, \hiGainDb, \loFreq, \hiFreq]);
			cw.triggerSane(\revSane, [\revRoom, \revDamp]);
			cw.triggerSane(\dlySane, [\dlyDecay, \dlyMix, \dlyBeats]);
			cw.triggerSane(\efxSane, [\hpSweep, \lpSweep, \gateSelect]);
			cw.midiTriggerButton(\eqSane,  \intctl, 12, 38); // pad 8, far left
			cw.midiTriggerButton(\efxSane, \intctl, 12, 40); // pad 10
			cw.midiTriggerButton(\revSane, \intctl, 12, 41); // pad 11
			cw.midiTriggerButton(\dlySane, \intctl, 12, 42); // pad 12
			cw.midiTriggerButton(\resync,  \intctl, 12, 45); // pad 15, far right

      // TODO : Update this for DN and use the assignments.
			// DigiTone track volumes, CC #95 on each of the 8 channels
			(0..7).do { |i|
				var sym = "dtMix%".format(i).asSymbol;
				cw.midiCC(sym, \intctl, i, 95);
				cw.midiCC(sym, \dt, i, 95);
				cw.saneValue(sym, 100/127);
			};

      ~h9knobCCs = (22..31);
      ~h9padCCs = [71, 17, 16, 70];
      ~mapDevice.value(\h9std, 5, 0, 11, ~h9knobCCs, ~h9padCCs);
      ~mapDevice.value(\h9max, 6, 0, 11, ~h9knobCCs, ~h9padCCs);
      ~mapDevice.value(\intctl, 7, 0, 7, (22..37), (38..45));

      // TODO : Is this still needed?
      cw.saneAll();

			cw;
		}.value;

    1.sleep;
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
		self.cw.free;
		self.cw = nil;
		self.efx.free;
		self.efx = nil;
		self.metro.stop;
		self.metro = nil;
	}
};
)