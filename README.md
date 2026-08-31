# FPGA Multi-Game Arcade — Nexys A7-100T

A modular arcade system in Verilog for the Digilent Nexys A7-100T (Xilinx Artix-7,
`xc7a100tcsg324-1`). Three games share one VGA timing engine and one input/scoring
path; each game is a self-contained state machine that owns only its own logic and
pixel colouring.

Built by a team of four for a digital design course, November–December 2025.

## What it does

Boot to a game-select screen, pick one of three games with the directional buttons,
play it on a 640×480 @ 60 Hz VGA monitor with the score on the 7-segment display.

| Game | Module | Idea |
|---|---|---|
| Road Cross | `crossy_game.v` | Cross a 20×15 grid of grass / road / river lanes without being hit or drowned |
| Snake | `snake_game.v` | Grid-based snake with growth and self-collision |
| Pong | `pong_game.v` | Paddle-and-ball with angle-dependent bounce |

## Architecture

```
                 CLK100MHZ (100 MHz)
                        │
                   ÷4 clock divider
                        │
                  clk_pix (25 MHz)
                        │
                   ┌────▼─────┐
                   │ vga_sync │  640×480@60 timing, pixel_x/pixel_y,
                   └────┬─────┘  display_en, frame_tick
                        │
        ┌───────────────┼───────────────┐
        │               │               │
   ┌────▼────┐    ┌─────▼────┐    ┌─────▼────┐
   │ crossy  │    │  snake   │    │   pong   │      arcade_top muxes
   │  _game  │    │  _game   │    │  _game   │      RGB + score by
   └────┬────┘    └─────┬────┘    └─────┬────┘      selected game
        └───────────────┼───────────────┘
                        │
              ┌─────────▼──────────┐
              │ sevenseg_driver_8dig│  time-multiplexed score display
              └────────────────────┘
```

The design is deliberately split so the timing engine is written once. `vga_sync`
owns all horizontal/vertical counters and porch constants and exposes a clean
`pixel_x` / `pixel_y` / `display_en` / `frame_tick` interface; games never touch
sync generation. Adding a fourth game means writing one module and one mux arm.

**`frame_tick`** is the other load-bearing piece: it pulses for exactly one clock at
the end of each frame (16.67 ms), and every game advances its state on that pulse
rather than on the pixel clock. Game logic is therefore frame-rate-locked and
independent of resolution or pixel-clock changes.

### VGA timing (`vga_sync.v`)

| | Visible | Front porch | Sync pulse | Back porch | Total |
|---|---|---|---|---|---|
| Horizontal | 640 | 16 | 96 | 48 | 800 |
| Vertical | 480 | 10 | 2 | 33 | 525 |

25 MHz pixel clock from a ÷4 divide of the 100 MHz board oscillator (25.175 MHz is
the nominal standard; 25 MHz is within tolerance for every monitor tested).

## Layout

```
rtl/                    synthesizable sources
  arcade_top.v            top level: clocking, game select, RGB/score mux
  vga_sync.v              640×480@60 timing generator
  crossy_game.v           Road Cross
  snake_game.v            Snake
  pong_game.v             Pong
  sevenseg_driver.v       single-digit 7-seg decode
  sevenseg_driver_8dig.v  8-digit time-multiplexed driver
  top_crossy.v            standalone Road Cross top (bring-up / debug)
sim/                    testbenches, one per module
constraints/
  nexys_a7_crossy.xdc     pin + timing constraints
scripts/
  create_project.tcl      regenerates the Vivado project from source
```

## Build

Requires Vivado 2025.1 or newer.

```bash
git clone git@github.com:csgomez25/FPGA-Multi-Game.git
cd FPGA-Multi-Game
vivado -mode batch -source scripts/create_project.tcl
```

That writes `build/arcade.xpr`. Open it in the GUI, or continue in batch:

```tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

`build/` is gitignored — the project is a derived artifact, and `rtl/` +
`constraints/` + the Tcl script are the source of truth.

## Simulation

Seven testbenches, one per significant module:

| Testbench | Covers |
|---|---|
| `tb_vga_sync.v` | counter rollover, sync polarity, `frame_tick` timing |
| `tb_crossy_game.v` | lane generation, collision, goal detection |
| `tb_snake_game.v` | growth and self-collision |
| `tb_pong_game.v` | paddle/wall bounce, scoring |
| `tb_sevenseg_driver.v` | segment decode |
| `tb_top_crossy.v` | standalone Road Cross integration |
| `tb_arcade_top.v` | full-system smoke test |

Run one from the Vivado GUI, or in batch:

```tcl
set_property top tb_vga_sync [get_filesets sim_1]
launch_simulation
```

## Controls

| Input | Function |
|---|---|
| `btnU` / `btnD` / `btnL` / `btnR` | Movement, paddle, menu navigation |
| `btnC` | Select / start |
| `CPU_RESETN` | Reset (active-low on the board, inverted internally) |

## Results

Post-route timing on the 100 MHz board clock, all constraints met with zero
failing endpoints:

| Metric | Value |
|---|---|
| Worst negative slack (setup) | **+8.161 ns** |
| Worst hold slack | **+0.440 ns** |
| Worst pulse-width slack | **+4.500 ns** |
| Failing endpoints | **0** of 2 |

Resource usage on the XC7A100T — the design fits with room to spare, which is
what makes adding a fourth game cheap:

| Resource | Used | Available | % |
|---|---|---|---|
| Slice LUTs | 2,899 | 63,400 | 4.6% |
| Slice registers | 1,579 | 126,800 | 1.2% |
| Block RAM | 0 | 135 | 0% |
| Bonded IOB | 37 | 210 | 17.6% |

Zero block RAM is deliberate: every game renders procedurally from its state
registers rather than from a framebuffer, so there is no frame memory to fill or
tear. Timing was verified in simulation and confirmed on-board on real hardware.
Buttons are debounced in hardware and game state advances only on `frame_tick`,
so no input is double-registered across a frame boundary.

## Team

Built by a team of four as part of an FPGA design course at Cal Poly Pomona.

## Notes

`top_crossy.v` predates `arcade_top.v` — it was the single-game bring-up target used
to validate the VGA path before the multi-game mux existed. It is kept because it is
still the fastest way to isolate a rendering bug to either the timing engine or the
game logic.
