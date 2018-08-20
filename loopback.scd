(
~cw = {
  var cw = ClockWise({});

  MIDIClient.init;
  MIDIIn.connectAll;
  CmdPeriod.add(cw);

  "Adding devices...".postln;
  cw.midiDevice(\pimidiout, "0-0" );
  cw.midiDevice(\pimidiin, "0-1");
  "Devices added.".postln;

  "Setting up performances...".postln;
  cw.midiPerf(\lb, \pimidiout, 0);
  cw.midiPerf(\lb, \pimidiin, 0);
  "Performances complete.".postln;
  
  MIDIdef.noteOn(\print, {arg val, num, chan, src; [src,chan, num, val].postln});

  cw.saneAll();
  cw
}.value;
)
