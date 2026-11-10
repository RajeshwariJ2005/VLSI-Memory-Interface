# Memory Interface with SECDED ECC (Verilog HDL)

This folder replaces the placeholder `ecc_encode()` and `ecc_decode()` calls with working Extended Hamming SECDED logic.

## Design
- Data width: 8 bits
- Memory depth: 16 words
- Stored codeword: 13 bits
- Hamming parity positions: 1, 2, 4, 8
- Overall parity position: 13
- Data positions: 3, 5, 6, 7, 9, 10, 11, 12

## Behaviour
- Normal read: returns the stored data; both error flags are low.
- Single-bit error: corrects the bit and raises `single_error`.
- Double-bit error: raises `double_error`. Do not rely on `rdata` for that read.
- Read data and error flags update on the rising clock edge when `re` is high.

## Simulation with Icarus Verilog
Run in this folder:

```bash
iverilog -g2012 -o sim.out memory_interface.v tb_memory_interface.v
vvp sim.out
```

A waveform file named `memory_interface.vcd` is generated. Open it with GTKWave:

```bash
gtkwave memory_interface.vcd
```

The testbench checks normal read/write, all 13 single-bit error locations, and a double-bit error.

**Important:** SECDED guarantees correction of one-bit errors and detection of two-bit errors. It does not guarantee detection/correction of every three-bit or higher error pattern. The simulation should be run in a Verilog simulator before reporting measured results.
