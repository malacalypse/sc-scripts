s.waitForBoot({ { SinOsc.ar([400, 401], 0, 0.1) * Saw.ar([11, 33], 1) * EnvGen.kr(Env.sine(10)) }.play });
