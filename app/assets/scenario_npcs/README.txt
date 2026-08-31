NPC character sprites, layered over scenario_background/ during the
interaction scene (transparent background recommended).

Naming convention: one subfolder per scenario, {assetPrefix}/npc.{ext}
  e.g. foa_supervisor/npc.png

One folder per scenario (not flat files) so each can hold more than one
NPC-related file later (e.g. alternate poses/expressions) without a
naming scheme change. Flutter asset folder declarations aren't
recursive, so every subfolder is listed individually in pubspec.yaml.

See scenario_background/README.txt for what assetPrefix means and the
full key -> prefix table (short theme abbreviation for every scenario
except foa_supervisor/foa_classroom, which keep their full key).

foa_supervisor/npc.png is real, in-use art (a static image). The other
six folders hold empty npc.riv placeholders (0 bytes, not valid Rive
files — just naming/folder-structure stand-ins) — those scenarios
don't have a bespoke NPC sprite wired up in code yet
(scene3_interaction.dart renders full-bleed background only when a
scenario's spriteAsset is null).

New NPC art is expected to be Rive (.riv) animations, not static
images — export from the Rive editor, replace the empty placeholder
keeping the exact filename, then set that scenario's spriteAsset in
scenario_models.dart to 'assets/scenario_npcs/{assetPrefix}/npc.riv'.
scene3_interaction.dart already branches on the .riv extension and
renders it via RiveAnimation.asset instead of Image.asset — no other
code changes needed.

Scenario keys currently in use (-> assetPrefix):
  foa_supervisor -> foa_supervisor
  foa_classroom  -> foa_classroom
  fsn_seat       -> fsn
  fbop_spotlight -> fbop
  fsg_party      -> fsg
  fne_stage      -> fne
  phys_jeepney   -> phys
