# LANDER64

This sample is a moon lander game. It is a port of Lander64 by rosdec, a C64
BASIC V2 game written for a Retroprogramming Italia contest.

The original is at `https://github.com/rosdec/lander64`, file
`contest/lander64.bas`. It is licensed under the GNU GPL version 3. This port
is licensed under the same terms. `LICENSE` holds the full text.

## Files

| File | What | Runs in |
|---|---|---|
| `LANDER64.SRC.PRG` | `LANDER64.BASL`, tokenised by BASLOAD. | ROM BASIC |
| `LANDER64.PRG` | `LANDER64.BASL`, compiled by GPC. | GPC |
| `LANDER64.BASL` | Source. Plain X16 BASIC. | ROM BASIC, GPC |
| `LICENSE` | The GNU GPL version 3. | |
| `README.md` | This file. | |

`LANDER64.PRG` is compiled EMBEDDED. It carries its own runtime, so no
runtime file is needed beside it. It has no `.OVL`.

## Run it

Start in the release root.

| Step | Type | Result |
|---|---|---|
| 1 | `DOS"CD:SAMPLES"` | Changes to `SAMPLES`. |
| 2 | `DOS"CD:LANDER64"` | Changes to `SAMPLES/LANDER64`. |
| 3 | `LOAD "LANDER64.PRG",8` | Loads the compiled version. |
| 4 | `RUN` | Shows the title page. |

Load `LANDER64.SRC.PRG` the same way to run it in ROM BASIC. The title page
names the one running. The game runs at the same speed in both.

## Play

Land the ship on the pad. The pad is the two green blocks.

| Control | Keyboard | Joystick |
|---|---|---|
| Fire the jet | Cursor up | Up |
| Push down | Cursor down | Down |
| Steer | Cursor left and right | Left and right |
| Quit | `Q` | |

The joystick is the SNES controller in port 1.

Row 1 shows the level, the column and row under the ship, and the vertical
speed. The speed is green when a landing is safe and red when it is not.

| Event | Result |
|---|---|
| The ship touches the pad below speed 150 | The next level starts. |
| The ship touches the pad at speed 150 or more | `TOO FAST`. |
| The ship touches the ground | `CRASHED`. |

After `TOO FAST` or `CRASHED`, press `Y` to play again. Any other key exits.
The exit puts back the screen mode, colours and charset.

## Changes from the original

| C64 | X16 |
|---|---|
| A 40x25 screen. | `SCREEN 3`, 40x30. |
| Sprite registers at 53248. | `SPRITE`, `SPRMEM` and `MOVSPR`. |
| Sprite data at 832. | VRAM at $13000. The `DATA` bytes are the |
| | original's, turned into 4-bit pixels at run time. |
| Joystick at 56320. | `JOY(0)` and `JOY(1)`. |
| A click from the SID volume register. | A noise on PSG voice 0. |
| `PEEK` of screen RAM at 1024. | `VPEEK` of the layer 1 map. |
| `POKE 781,1:SYS 59903` clears a line. | `LOCATE` places the status line. |
| Ground across 31 of 40 columns. | Ground across all 40 columns. |
| The game loop runs as fast as it can. | One tick every 4 jiffies. |

The original tried to stop the ship at the screen edges, but it set two
variables nothing read. This port stops the ship at the left, right and top
edges.

The port adds the level number, the speed colours, the `Q` key, the crash
sound and the play-again question.

## Rebuilding

The sample cannot be rebuilt in `SAMPLES/LANDER64/`, because the compiler is
not there. See the release root's `README.md`, section "Compiling a program".

<!-- release: the rest is for the source tree -->

## In the repository

### Build

From the repository root:

```
python source\gpc\samplesbuild.py LANDER64
```

The build leaves `LANDER64.SRC.PRG`, `LANDER64.PRG` and `LANDER64.MAP` in
this folder.
