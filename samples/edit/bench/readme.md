# The editor's benchmarks

Four programs that are not the editor. Each holds the old code and the new code in **one** program,
runs both against the same fixture, and times them off `TI` inside the machine.

| File | Measures | Result |
| --- | --- | --- |
| `BENCHROWS.BASL` | the BASIC row renderer against the `GP.ASM` one | see `../readme.md` |
| `LOADBEN.BASL` | the `GET#` loader against the `LINPUT#` one | 10.5x |
| `SLOTBEN.BASL` | the line table, old against new | 87x |
| `SLOTTST.BASL` | the line table, correctness — 2,100 entries, every slot checked | — |

> **WARNING** — run these at real speed. Under `-warp` the jiffy IRQ is decoupled from the CPU and
> every number here is meaningless.

Each builds the way `EDITOR.BASL` does: `python source/gpc/build_basl.py <name>.BASL <name>.PRG`,
then compile the `.PRG` with `GPC.BIN`.
