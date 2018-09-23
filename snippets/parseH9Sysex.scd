(
~h9 = Environment.make { |self|
  self.know = true;

  ~requestH9Program = {
    ~h9.cw.getMidiOut(\h9).sysex(Int8Array[ 0xF0, 0x1C, 0x70, 0, 0x4E, 0xF7]);
  };

  ~cw = {
    var cw = ClockWise({});

    var handleH9sysex = { |data|
      var matches = [], progAscii = "";
      var regex = "\\[[0-9]+\\] [0-9]+ [0-9]+ [0-9]+.?\n +([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+) ([0-9a-f]+)";
      data[5..data.size - 1].collect { |i| progAscii = progAscii ++ i.asAscii };
      matches = progAscii.findRegexp(regex);
      if (matches.size == 13) {
        "H9 Configuration Received!".postln;
        matches[1..matches.size].collect { |entry| ("0x" ++ entry[1]).interpret }.reverse.postln;
      } { "Sysex could not be parsed.".postln; };
    };

    cw.midiDevice(\h9, "H9 Pedal");
    cw.sysex(\h9, handleH9sysex);
    cw.midiProgram(\h9pc, \h9, 0, inOnly: true);
    cw.action(\h9pc, { |num| ~h9.requestH9Program.value; });
    cw;
  }.value;
}.value;
)

~h9.requestH9Program.value