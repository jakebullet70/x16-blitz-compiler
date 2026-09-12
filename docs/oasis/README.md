# OASIS BBS -- porting notes

Review and conversion planning for the OASIS BBS, an X16 BASIC application being moved from
interpreted BASLOAD to GPC. The application itself lives in `OASIS/` at the repository root; this
folder holds only the analysis.

`docs/blitz/` is the compiler's own documentation. Application ports go here.

| document | covers |
|---|---|
| `FULL-SOURCE.PLAN.md` | `OASIS/OASIS_FULL_SOURCE` -- the whole application, ten programs, and the two-stage port |
| `MSGPOST.PLAN.md` | one unit end to end: every blocker, every free win, and the steps |

`OASIS/OASIS_MSGPOST` is a byte-identical flattened copy of the MSGPOST unit from
`OASIS_FULL_SOURCE`, so the two documents do not disagree about that unit.

Both are reviews. Neither contains code, and nothing in `OASIS/` has been modified.
