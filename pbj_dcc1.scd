/***
 *** crunch/ presets:
 ***
 ***       Peanut Butter Jam
 ***        - a beat sync'd effects sandwich for live performance
 ***/

/* === TO DO ===

[] Looper
[] MIDI looper

[] delay volume control, perhaps, send, not return?
[] Beat division display for stutter?
[] Digitakt delay setting, to be able to get triplets

[] Link

[] improve accuracy of beatSyncBus by having the sync routine trigger in advance n ms, then
   send the c_set command w/n ms lag.
*/

(
MIDIIn.connectAll;
s.latency = 0;
s.recChannels = 2;
s.recSampleFormat = "int24";

if (~pbj.isNil.not) {
	// clean up any old one hangin' around
	var pbj = ~pbj;
	~pbj = nil;
	protect { pbj.freeUp };
};

~pbj = Environment.make { |self|
	var metro;

	self.know = true;

	~server = s;
	~metro = metro = TempoClock(self.efx, 135/60);

	~gateRates = [0, 8, 6, 4, 3, 2, 1, 0.5];
		// divisions of a beat, 0 means none

	Routine({
		~beatSyncBus = Bus.control(s, 1);

		~pbj = {
			arg tempo = 2, beatsPerBar = 4,

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
			var slowest16th = slowestTempo.reciprocal/4;
			var maxDelay = 16*slowest16th;

			var time16th = Lag2.kr(tempo.reciprocal/4, 0.75);
			var dlyTime =  Lag2.kr(dlyBeats*time16th,  0.75);

			var dlyFixL = CombL.ar(sig[0], 3*slowest16th, 3*time16th, dlyDecay);
			var dlyFixR = CombL.ar(sig[1], 5*slowest16th, 5*time16th, dlyDecay);
			var dlyVar =  CombL.ar(sig,   16*slowest16th, dlyTime,    dlyDecay);
			var dly = LeakDC.ar(XFade2.ar([dlyFixL, dlyFixR], dlyVar, dlyMix)) * dlyLevel;
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

			cw.midiDevice(\bs, "BeatStep");
			cw.midiDevice(\dn, "Digitone");

			cw.action(\resync, { cw.syncAll(); });
			cw.midiTriggerButton(\resync, \bs, 0, 127);


			// 3 Band Eq

			cw.synthArg(\loGainDb, \boostcut.asSpec);
			cw.synthArg(\midGainDb, \boostcut.asSpec);
			cw.synthArg(\hiGainDb, \boostcut.asSpec);
			cw.midiCC(\loGainDb, \bs, 15, 82);
			cw.midiCC(\midGainDb, \bs, 15, 83);
			cw.midiCC(\hiGainDb, \bs, 15, 84);

			cw.synthArg(\loFreq, \midfreq.asSpec);
			cw.synthArg(\hiFreq, ControlSpec(440, 10000, \exp));
			cw.midiCC(\loFreq, \bs, 15, 86);
			cw.midiCC(\hiFreq, \bs, 15, 87);

			cw.triggerSane(\eqSane, [\loGainDb, \midGainDb, \hiGainDb, \loFreq, \hiFreq]);
			cw.midiTriggerButton(\eqSane, \bs, 15, 10);

			// Stutter Gate

			cw.synthArg(\gateSelect, ControlSpec(0, ~gateRates.size));
			cw.midiCC(\gateSelect, \bs, 15, 112);

			// Reverb

			cw.synthArg(\revRoom);
			cw.synthArg(\revDamp);
			cw.midiCC(\revRoom, \bs, 15, 100);
			cw.midiCC(\revDamp, \bs, 15, 101);

			cw.triggerSane(\revSane, [\revRoom, \revDamp]);
			cw.midiTriggerButton(\revSane, \bs, 15, 12);


			// Delay

			cw.synthArg(\dlyDecay, ControlSpec(0, 15));
			cw.midiCC(\dlyDecay, \bs, 15, 108);

			cw.synthArg(\dlyMix, \bipolar.asSpec);
			cw.midiCC(\dlyMix, \bs, 15, 109);

			cw.synthArg(\dlyBeats, ControlSpec(1, 16, 'lin', 1));
			cw.midiCC(\dlyBeats, \bs, 15, 110);

			cw.synthArg(\dlyPos, \bipolar.asSpec);
			cw.midiCC(\dlyPos, \bs, 15, 111);

			cw.triggerSane(\dlySane, [\dlyDecay, \dlyMix, \dlyBeats]);
			cw.midiTriggerButton(\dlySane, \bs, 15, 13);


			// Effects

			cw.synthArg(\hpSweep, \freq.asSpec);
			cw.synthArg(\lpSweep, \freq.asSpec);
			cw.midiCC(\hpSweep, \bs, 15, 114);
			cw.midiCC(\lpSweep, \bs, 15, 115);

			cw.triggerSane(\efxSane, [\hpSweep, \lpSweep, \gateSelect]);
			cw.midiTriggerButton(\efxSane, \bs, 15, 14);


			// Levels

			cw.synthArg(\dryLevel);  // \amp.asSpec might be more common here
			cw.synthArg(\revLevel);  // but it doesn't give as fine a control
			cw.synthArg(\dlyLevel);  // over the extreme end, which in this case
			cw.synthArg(\outLevel);  // is more useful
			cw.midiCC(\dryLevel,  \bs, 15, 11, ControlSpec(127, 0));
			cw.midiCC(\revLevel,  \bs, 15, 12);
			cw.midiCC(\dlyLevel,  \bs, 15, 13);
			cw.midiCC(\outLevel,  \bs, 15, 15);


			// Digitakt Track Volumes

			(0..7).do { |i|
				var sym = "dtMix%".format(i).asSymbol;
				cw.midiCC(sym, \bs, i, 95);
				cw.midiCC(sym, \dn, i, 95);
				cw.saneValue(sym, 100/127);
			};

			// MIDI Performance Router

			cw.midiDevice(\ar, "Analog Rytm");
			cw.midiDevice(\ks, "KeyStep");
			cw.midiDevice(\s37, "Subsequent 37");
			cw.midiDevice(\rev2, "Prophet Rev2");
			cw.midiDevice(\ps, "PiSound");

			cw.midiPerf(\perfIn, \ks);

			// Create a couple "busses" out of which we can output notes
			cw.midiPerf(\perfOut0, \dn,   9); // Auto-channel 10
			cw.midiPerf(\perfOut1, \s37,  4); // Channel 5
			cw.midiPerf(\perfOut2, \rev2, 5); // Channel 6

			// Map Digitone MIDI channel outputs to synths
			cw.midiPerf(\perfOut0, \dn, 4, inOnly:true); // dn MIDI channel 1
			cw.midiPerf(\perfOut1, \dn, 5, inOnly:true); // dn MIDI channel 2
			cw.midiPerf(\perfOut2, \dn, 6, inOnly:true); // dn MIDI channel 3
			cw.midiPerf(\perfOut3, \dn, 7, inOnly:true); // dn MIDI channel 4

			// Tempo & Clock

			// cw.tempoClock(\tempo, \clock, ~metro);
			cw.midiClock(\clock, \ar);                 // Can send clock if I want
			cw.midiClock(\clock, \bs);                 // Can send start/stop
			cw.midiClock(\clock, \dn);                 // Can also send start/stop
			cw.midiClock(\clock, \s37, outOnly:true);  // Not allowed to "chatter"
			cw.midiClock(\clock, \rev2, outOnly:true); // Not allowed to "chatter"

			/*
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
			*/

			// Timers

			(1..2).do { |i|
				var symMin = "t%min".format(i).asSymbol;
				var symSec = "t%sec".format(i).asSymbol;
				var symRst = "t%rst".format(i).asSymbol;
				var symRun = "t%run".format(i).asSymbol;

				var timer = 0;
				var running = true;

				var ffNum = 124 + (2 * (i - 1));

				var update = { |t|
					timer = t;
					cw.set(symMin, (timer / 60).floor);
					cw.set(symSec, timer % 60);
				};

				cw.midiCC(symMin, \ff, 12, ffNum, unmapped:true);
				cw.midiCC(symSec, \ff, 12, ffNum+1, unmapped:true);

				cw.midiTriggerButton(symRst, \ff, 12, ffNum);
				cw.action(symRst, { update.value(0); });

				cw.midiTriggerButton(symRun, \ff, 12, ffNum+1);
				cw.action(symRun, { running = running.not; });

				SystemClock.sched(0, Routine({
					loop {
						if (running) { update.value(timer + 1); };
						1.yield;
					}
				}));

				update.value(0);
			};

			cw.midiProgram(\t2rst, \dn, 9);

			cw.midiRadioButton(\recording, 0, \bs, 15, 6);
			cw.midiRadioButton(\recording, 1, \bs, 15, 7);
			cw.action(\recording, { |v|
				if (v == 1)
					{ s.record; }
					{ s.stopRecording; };
				"recording %, on %".format(s.isRecording, s.recorder.path).postln;
			});

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
