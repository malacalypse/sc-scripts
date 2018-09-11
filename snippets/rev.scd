(
{
    var fast = SinOsc.kr(12) * 2;      // +/- 2 semitones at 12Hz
    var slow = SinOsc.kr(0.2) * 24;    // +/- 2 octaves at 1/5Hz
    var center = 60;                   // around middle C
    var filtFreq = (fast + slow + center).midicps;

    var input = SoundIn.ar();
    var resonated = Resonz.ar(input, filtFreq, bwr:0.15);
    var reverbed = FreeVerb.ar(resonated, room:0.8);

    reverbed   // last thing returned is played out
}.play;
)
