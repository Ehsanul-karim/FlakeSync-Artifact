# Wasp Result

Status: completed and repaired.

- Stage times: 142.264 s / 143.355 s / 262.351 s.
- First successful critical candidate: line 308, rank 1/3.
- Successful barrier: line 87, rank 23/23.
- Strong source signal: line 308 updates shared executor state; line 87 is an assertion immediately after a polling/sleep loop.

`raw/` contains the three stage logs, generated result rows, candidate order, failure excerpt, and relevant source excerpt.

