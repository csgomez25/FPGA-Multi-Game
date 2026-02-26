# FPGA Multi-Game Console

A collection of three classic arcade-style games implemented on the **Digilent Nexys A7 FPGA** using **Verilog** and developed in **Vivado**. This was a collaborative project built by a team of 4.

## Games

- **Snake** — Classic snake game where the player grows by eating food while avoiding walls and itself
- **Pong** — Two-player paddle game with real-time ball physics and collision detection
- **Frogger / Crossy Road** — Navigate your character across moving obstacles to reach the other side

## Hardware

| Component | Details |
|-----------|---------|
| Board | Digilent Nexys A7 |
| Display | VGA Monitor |
| Input | Onboard buttons and switches |
| Score/Info | 7-segment display |

## Project Structure
```
fpga-multigame/
├── README.md
├── .gitignore
├── src/
│   ├── snake/
│   ├── pong/
│   └── frogger/
├── constraints/
│   └── nexys_a7.xdc
└── docs/
    └── (block diagrams, report)
```

## How to Run

1. Clone the repo
2. Open Vivado and create a new project targeting the **Nexys A7 (xc7a100tcsg324-1)**
3. Add the source files from `src/` and the constraint file from `constraints/`
4. Run Synthesis → Implementation → Generate Bitstream
5. Program the board via Vivado Hardware Manager

## Team

Built by a team of 4 as part of an FPGA design course.

## Tools Used

- Xilinx Vivado
- Verilog HDL
- Digilent Nexys A7
