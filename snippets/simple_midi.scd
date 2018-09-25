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

  cw.midiDevice(\key, "keystep");    // put your keyboard here
  cw.midiDevice(\syn, "digitone");   // put a hardware synth here
  cw.midiDevice(\din, "pisound");    // DIN I/O

  // Very simple note routing for now
  cw.midiPerf(\keyBus, \key, 0);
  cw.midiPerf(\keyBus, \syn, 9); // Autochannel Digitone
  cw.midiPerf(\keyBus, \din, 0);

  cw.tempoClock(\tempo, \clock, ~metro);
  cw.midiClock(\clock, \syn, outOnly:true);
  cw.midiClock(\clock, \key, outOnly:true);
  cw
}.value;
)
