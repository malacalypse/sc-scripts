(
s.options.memSize_(65536 * 4);
s.waitForBoot {
  "pifx.scd".loadRelative;
  "Hail Satan and rock on!".postln;
}
)
