# calcvr: Multivariable Calculus in VR

A virtual-reality app for seeing **multivariable calculus** in 3D. You type a function, and the
app draws it so you can walk around it, grab it and probe it. It has four topics:

1. **Surface plot**: f(x, y) with a movable point, its **tangent plane** and its **gradient** ∇f.
2. **Solid of revolution**: y = f(x) on [0, 4] rotated about the x-axis, with a sliding
   cross-section disk and the **volume** integral.
3. **Vector field**: F(x, y, z) as arrows colored by |F|, flow particles, and a probe that
   reads **div F** and **curl F**.
4. **Parametric curve**: r(t) as a tube, with a point moving along it that shows the
   **velocity** r′(t), the **acceleration** r″(t) and the **arc length**.

It runs on a PC (keyboard and mouse) and on a **Meta Quest** headset. The app's name on the
headset is **calcvr**.

---

## At a glance

| | |
|---|---|
| **Language** | GDScript (Godot's Python-like scripting language), plus one shader (`shaders/grid.gdshader`) |
| **Engine** | Godot 4.7.2, OpenXR for VR |
| **Platforms** | Linux desktop (also works without a headset), Meta Quest (Android APK, package `com.example.vrcalculus`) |
| **Addons** | Godot XR Tools 4.5.1 (patched for Godot 4.7, see `patches/`), Godot OpenXR Vendors 5.1.0 |
| **Tests** | windowed self-test (29 checks) + function-parser test |

---

## Where do the numbers come from?

**Short answer:** everything is **computed numerically from the function you type**, live,
with standard numerical-analysis methods. Nothing is pre-recorded, and no physics engine is
involved.

| Quantity | Method | Code |
|---|---|---|
| Your function | Typed text is parsed by a small recursive-descent parser (`MathExpr`) into a Godot `Expression`, then evaluated at each point | `scripts/core/math_expr.gd` |
| Partial derivatives, gradient ∇f, tangent plane | central differences, h = 0.001: ∂f/∂x ≈ (f(x+h, y) − f(x−h, y)) / 2h | `scripts/topics/surface_plot.gd` |
| Volume of a solid of revolution | disk method, V = ∫₀ˣ π f(t)² dt, by the **trapezoid rule** with 800 steps | `scripts/topics/solid_of_revolution.gd` |
| div F, curl F | central differences on each component, h = 0.001 | `scripts/topics/vector_field.gd` |
| Flow particles | dp/dt = F(p), integrated with a **midpoint (RK2)** step | `scripts/topics/vector_field.gd` |
| Velocity r′(t), acceleration r″(t) | central differences: first derivative (dt = 10⁻³) and second derivative (dt = 10⁻²) | `scripts/topics/parametric_curve.gd` |
| Arc length | sum of the straight segments between 600 samples on t ∈ [0, 6π] | `scripts/topics/parametric_curve.gd` |

These are approximations, so expect agreement with the exact answer to about 3 decimal
places. For example, the self-test types a circle of radius R and gets an arc length of
26.462, against an exact 6πR = 26.463. Very tall functions are squashed vertically and
wide ones radially so they fit in view (the scale is applied to the drawing only; the
numbers shown are always the true values). Values are clamped to ±10⁴ for drawing, so
functions with poles stay displayable.

**Writing functions:** `^` for powers, implicit multiplication (`2x`, `x y`, `3sin(x)`),
`sin cos tan asin acos atan sinh cosh tanh sqrt exp ln abs floor ceil sign min max atan2`,
and the constants `pi`, `e` and `tau`. Vector fields and
curves take three components: `(-y, x, 0)`. Curves may use the parameters `R` and `w` (ω),
which the sliders and sticks change. Mistakes are reported under the input box, e.g.
"Need 3 components separated by commas".

---

## How to use it

### Start it
- **On the PC:** double-click **`run.godotapp`** in this folder (or run `./run.godotapp`).
  Without a headset it starts in desktop mode.
- **From the Godot editor:** open the project and press **F5**.
- **On the Quest:** see [Install on the Quest](#install-on-the-quest).

### Desktop controls

| Input | Action |
|---|---|
| 1 2 3 4 | switch topic (surface, solid, vector field, curve) |
| W A S D, Q / E, Shift | fly the camera, down / up, faster (keys by position, so Z Q S D and A / E on AZERTY) |
| hold the right mouse button | look around |
| arrow keys | move the point / slice / probe, or change ω and R on the curve |
| mouse wheel | slice position, probe height, or animation speed |
| Space | the topic's action (toggle particles, pause the curve) |
| click / drag | select an arrow, click the surface, drag the white sphere, probe or blue plane |
| H | show / hide help |
| F12 | screenshot to `screenshots/` |

Type a new function in the box at the bottom of the screen. The on-screen hint for each
topic lists its controls.

### VR controls (Quest)

| Input | Action |
|---|---|
| left stick | walk |
| right stick | snap turn / fly |
| hold grip | the sticks drive the topic instead (move the point, slice, probe...) |
| trigger + laser | press buttons, grab objects |
| B / Y | reset position |

In VR, functions are typed on a 3D keypad.

---

## How it was built (process)

1. Started from the Godot VR starter project (`~/godot-vr-starter`): OpenXR plus XR Tools,
   with a Quest export preset.
2. One base class, `CalcTopic` (`scripts/core/calc_topic.gd`), gets the same input hooks
   from the keyboard and from the controllers, so every topic works on the PC and in VR.
3. Each topic (`scripts/topics/`) builds its meshes in code from the sampled function and
   recomputes them when the function or a parameter changes.
4. Added typed functions (`MathExpr` parser), the 3D keypad, XR walking and turning, and
   custom functions for all four topics.
5. A windowed self-test (`tests/autotest.gd`) drives every topic like a user would, checks
   the numbers against exact answers (e.g. div of (x, y, z) = 3, curl = 0, circle arc length
   = 6πR) and saves screenshots for visual review.

### Code layout

```
scripts/main.gd           sets up the scene, the camera / XR rig and the topic switching
scripts/core/             CalcTopic base, MathExpr parser, math helpers, HUD, input, XR pointer and locomotion, 3D keypad
scripts/topics/           surface_plot, solid_of_revolution, vector_field, parametric_curve
tests/autotest.gd         windowed end-to-end self-test
tests/parser_test.gd      function parser test
patches/                  XR Tools fixes for Godot 4.7 (see patches/README.md)
```

---

## Tests

```bash
godot --path . -- --autotest                    # windowed self-test: 29 checks, screenshots to screenshots/
godot --headless --path . -s tests/parser_test.gd   # function parser test
```

---

## Install on the Quest

You need the Godot Android export setup (JDK 17, Android SDK) and the headset connected by USB
with developer mode on.

```bash
godot --headless --path . --export-debug "Quest" build/vr-calculus-quest.apk
adb install -r build/vr-calculus-quest.apk
adb shell monkey -p com.example.vrcalculus -c android.intent.category.LAUNCHER 1
```

On the headset, the app is under **Library → Unknown sources → calcvr**.
