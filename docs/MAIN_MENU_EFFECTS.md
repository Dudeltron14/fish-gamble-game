# Main Menu Effects

The main menu background effects are editor-placeable scenes. Open `src/scenes/ui/LoginScreen.tscn`, then drag effect presets from `src/scenes/ui/menu_effects/` into the `Ambience` node.

Available presets:

- `MenuLanternFlame.tscn`
- `MenuBrassGlint.tscn`
- `MenuCoinSparkle.tscn`
- `MenuDustMote.tscn`

For each effect instance:

1. Move it in the 2D editor until it lines up with the background.
2. Scale it visually in the inspector or with the editor handles.
3. Duplicate the instance when the same effect is needed in multiple places.
4. Change `start_frame` on duplicated instances so repeated effects do not animate in sync.
5. Adjust `alpha` if the effect is too strong.
6. Leave `remove_generated_background` enabled for generated sheets with fake white/checker backgrounds.

`MenuLanternFlame`, `MenuBrassGlint`, `MenuCoinSparkle`, and `MenuDustMote` are currently approved for use. The flame preset uses a cleaned 17-frame transparent strip made from a generated flame contact sheet. The brass glint preset uses a transparent 16-frame strip for small metal highlights. The generated soft glow and water shimmer sheets were removed from the editor presets because their motion does not line up well enough with the fixed background.

The `Ambience` node sits above the background image and below the dim layer/login UI, so effects should remain atmospheric and not block the form.
