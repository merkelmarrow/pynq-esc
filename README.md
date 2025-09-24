# PYNQ-Z2 3-Phase Motor Controller
_Status_: Solo hobby project, in progress.

_Tech Stack_: EasyEDA (4-layer PCB), Xilinx Vivado, Verilog, AXI protocol, PYNQ (Python Productivity for Zynq), Zynq 7020, SPI, precision analogue design (references, amps, filters), power electronics (hot-swap, MOSFET inverter), Python, JLCPCB and hand assembly.

### Intro

Field Oriented Control (FOC) is the dominant approach for high performance PMSM/BLDC motor control. It’s an algorithm that mathematically transforms the stator currents into a rotating reference frame aligned with the rotor’s magnetic field, allowing near-independent control of torque and flux. However, achieving this in practice demands tightly synchronised, low-latency current sampling and accurate rotor electrical angle sensing/estimation, which increases implementation complexity substantially.

Many commercially available motor controllers capable of implementing FOC hide their inner control loop. I wanted to create a precision motor controller that gives the user ultimate control and visibility of the loop while being able to iterate control algorithms quickly. The PYNQ-Z2 board available at Trinity was the perfect platform; high-speed deterministic control from the FPGA-accelerated current loop, while the supervisory loops run in software on the ARM cores. The PYNQ platform (Zynq 7020 SoC) is purpose-built to facilitate this hardware-software integration.

### What I built

I designed and built by hand a custom power module PCB for a 3-phase motor that plugs directly into the PYNQ-Z2, runs a deterministic 32 kHz commutation loop directly in FPGA logic while exposing all internals and supervisory control to software via the AXI protocol. To date I have validated quadrature and hall decoding, most power stages, SPI, AXI communication and high speed ADC data path, however I am currently debugging gate driver communication issues that are preventing actual motor commutation.

#### Custom PCB

- _**Power entry**_: LM5069 hot-swap controller limits inrush and protects against fault events (OVLO,  overcurrent).
- _**Drive stage**_: DRV8353 (DRV) smart 3-phase gate driver, power MOSFET inverter stage (Vishay SiRS4600DP MOSFETs).
- _**Sensing**_: Low-side shunt resistors feed the DRV current sense amplifiers (5V span via precision ref.), line-to-line voltages sensed via high-CMRR amp and filter stage, bus voltage sensed using Zynq XADC.
- _**ADC Chain**_: Massively capable AD7761, 8-channel simultaneous sigma-delta ADC with 16-bit precision at 256 kSPS, paired with precision buffered refs and analogue input filtering.
- _**Form factor**_: 18-25 V input (current limits to be tested, estimate is 15 A), quadrature encoder differential receiver + halls (M12 connector), entire board slots on top of PYNQ via Arduino shield headers. Manufactured by JLCPCB, components from DigiKey/LCSC, assembled entirely by me.
  
#### Verilog RTL / Linux
- _**Deterministic timing**_: The timing_hub module coordinates the precise sync between ADC sampling and PWM and implements a freeze-at-wrap realign mechanism to minimise disruption from drift. Dual MMCM clocking system enforces exact integer relationship (4x) between clock domains, allowing me to define an invariant compute budget (399 control ticks at 131.072 MHz) for each PWM period (factoring in mid-period sampling, ADC filter group delay and data transfer cycles).
- _**PWM & Commutation**_: 32 kHz, 12-bit centre-aligned PWM, currently implemented via six-step commutator (with plans to upgrade to closed-loop FOC after proof of concept), dead-time is handled by DRV chip.
- _**Quadrature input decoder**_: module conditions A/B inputs from differential receivers, syncs into the control clock, and uses FSM to keep track of and expose rotor mechanical position output up to 14-bit resolution.
- _**AXI and Safety**_: Custom AXI block safely crosses single-bit and bus signals, exposing live status words and allowing basic hardware control from software. A pwm_kill block in hardware latches faults in nanoseconds from a variety of fault sources, disabling gate drive and requiring software acknowledgment to clear.
- _**Processing System (Linux) Integration**_: PYNQ Jupyter notebook loads the bitstream and device tree overlay (SPI for two chip-selects), memory maps the AXI block and will soon run supervisory control loops.

### Impact

When completed, it will be a reusable and open lab platform for motor control, with high bandwidth deterministic phase-current loop control, precision analogue instrumentation and high level software control of hardware resources.
