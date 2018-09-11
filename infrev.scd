~infrev = {
  arg feedback = 1;
  var sig, local;

  sig = SoundIn.ar(0);
  local = LocalIn.ar(2) + sig.dup;

  1.do { 
   local = AllpassN.ar(local, 1, 1, 0.001);
  };

  LocalOut.ar(local*0);

  Out.ar(0, sig+local);
}.play;
