(
SynthDef(\sound,{arg freq=440, amp=0.1;
    var saw, filter, env;

    saw= Saw.ar(freq);
    filter= Resonz.ar(saw,1000,0.1)*amp;
    env= EnvGen.ar(Env([0,1,0],[0.01,0.1]),doneAction:2);

    //dup(2) duplicates the mono signal onto two channels, giving instant stereo middle panned output
    Out.ar(0,(filter*env).dup(2))
}).add;

MIDIIn.connectAll;

//create one Synth for every new note, Synths will be of finite duration because of the envelope
MIDIIn.noteOn = { arg src,chan, midinote, velocity;   Synth(\sound,[\freq,midinote.midicps,\amp,velocity/127.0]) };

)