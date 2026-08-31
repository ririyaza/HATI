Placeholder/thumbnail art for each scenario, used for the scenario card
on the Modules screen (as opposed to scenario_background/, which is the
full-screen art shown during scenario play).

Naming convention: {assetPrefix}_placeholder.png
  e.g. fbop_placeholder.png

PNG only — not SVG. Export a single FLATTENED image (all layers merged
into one raster, background + any character art composited together).
Layered/masked SVG exports from design tools render unreliably in
flutter_svg (some layers can silently fail or show as a flat
silhouette instead of the real art) — a flattened PNG has no such risk.

See scenario_background/README.txt for what assetPrefix means and the
full key -> prefix table (short theme abbreviation for every scenario
except foa_supervisor/foa_classroom, which keep their full key).

Wired into the app already — modules_screen.dart renders these via
Image.asset for each scenario's grid thumbnail (letterboxed with
BoxFit.contain, since this art isn't necessarily square) — so adding a
file just means using the exact filename above and hot-restarting.

Scenario keys currently in use (-> assetPrefix):
  foa_supervisor -> foa_supervisor
  foa_classroom  -> foa_classroom
  fsn_seat       -> fsn
  fbop_spotlight -> fbop
  fsg_party      -> fsg
  fne_stage      -> fne
  phys_jeepney   -> phys
