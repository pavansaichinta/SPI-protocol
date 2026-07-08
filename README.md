# SPI (Serial Peripheral Interface) Controller

A fully synthesizable, parameterized SPI Controller implemented in Verilog HDL. This design features a configurable Master and Slave architecture capable of handling multi-mode data transmission (SPI Modes 0, 1, 2, 3) for high-speed synchronous serial communication with peripheral devices.

## Key Features
- **Multi-Mode Support:** Configurable CPOL (Clock Polarity) and CPHA (Clock Phase) to support all 4 standard SPI modes.
- **Parameterized Word Length:** Supports adjustable data widths (default is 8-bit, easily scalable to 16-bit or 32-bit).
- **Full-Duplex Communication:** Simultaneous data transmission (MOSI) and reception (MISO) synchronized to the serial clock (SCK).
- **Robust Clock Generation:** Integrated clock divider to derive the targeted SPI SCK frequency from the main system clock.

## Interface & Port Signals

### SPI Master Ports
| Port Name  | Direction | Width | Description |
|------------|-----------|-------|-------------|
| `clk`      | Input     | 1     | System Clock |
| `rst_n`    | Input     | 1     | Active-Low Asynchronous Reset |
| `start`    | Input     | 1     | Strobe to initiate full-duplex transfer |
| `tx_data`  | Input     | [N-1:0]| Parallel data byte to be transmitted |
| `rx_data`  | Output    | [N-1:0]| Parallel data byte received |
| `busy`     | Output    | 1     | High when a transfer is actively running |
| `sck`      | Output    | 1     | Serial Clock driven by Master |
| `mosi`     | Output    | 1     | Master Output Slave Input line |
| `miso`     | Input     | 1     | Master Input Slave Output line |
| `ss_n`     | Output    | 1     | Active-Low Slave Select |

---

## Design Architecture
The architecture utilizes two shift registers (one for transmitting, one for receiving) alongside a central Finite State Machine (FSM) that controls data shifting on the appropriate SCK edges:
1. **IDLE:** Initializes control lines; waits for the `start` token while maintaining `sck` at the configured `CPOL` level.
2. **LOAD:** Latches parallel `tx_data` into the internal transmit shift register and asserts `ss_n` low.
3. **TRANSFER:** Toggles `sck` and shifts bits out onto `mosi` while sampling incoming bits from `miso` based on the specified `CPHA` timing.
4. **DONE:** De-asserts `ss_n`, pulses a completion flag, and transfers the gathered shift register data to the parallel `rx_data` output bus.

---

## Verification & Simulation
Functional verification was carried out via a self-checking testbench looping the Master MOSI directly to a simulated SPI Slave device inside Xilinx Vivado. 

### Simulation Waveform
*The waveform below confirms zero-bit data corruption during back-to-back full-duplex transactions:*
