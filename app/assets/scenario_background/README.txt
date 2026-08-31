Full-screen background art for each scenario, shown during scenario play.

Naming convention: {assetPrefix}_background.png
  e.g. fbop_background.png

All 7 files here are currently PNG.

assetPrefix is the same as the scenario's key (see
scenario_models.dart's ScenarioConfig/kScenarioConfigs), except for the
Fear of Authority theme, which has two scenarios (foa_supervisor and
foa_classroom) — those two keep their full key in the filename so they
don't collide. Every other theme currently has one scenario, so its
prefix is just the short theme abbreviation:
  fbop, fsn, fsg, fne, phys

To swap in new art, replace the file in place keeping the exact same
filename (including extension) so no code changes are needed. After
replacing a file, hot-restart (not hot-reload) the app, or rebuild, to
see the change — Flutter caches bundled images.

Scenario keys currently in use (-> assetPrefix):
  foa_supervisor -> foa_supervisor
  foa_classroom  -> foa_classroom
  fsn_seat       -> fsn
  fbop_spotlight -> fbop
  fsg_party      -> fsg
  fne_stage      -> fne
  phys_jeepney   -> phys
