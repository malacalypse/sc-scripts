(
MIDIClient.init;
MIDIIn.connectAll;
MIDIClient.destinations;
m = MIDIOut.newByName("Elektron Digitone", "Elektron Digitone MIDI 1");

d = Dictionary.new;
d= ();
MIDIdef.noteOn(\noteOnTest, {
  arg vel, nn, chan, src;
  [vel, nn, chan, src].postln;
c=0;
for (0, 7, {
  arg i;
  if (d.at(i)== nil, {
    c=i;
  });
});
d.put(c, nn);
  m.noteOn(c, nn, vel);
});

MIDIdef.noteOff(\noteOffTest, {
  arg vel, nn, chan, src;
  [vel, nn, chan, src].postln;
  l = d.findKeyForValue(nn);
  m.noteOff(l, nn, vel);
  m.allNotesOff(l);
  d.removeAt(l);
});
)
