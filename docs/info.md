<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements an SPI-controlled PWM peripheral.
 
The SPI peripheral receives 16-bit write transactions containing a 1-bit
write indicator, a 7-bit register address, and 8 bits of data. The registers
control the output enables, PWM enables, and PWM duty cycle for 16 output
channels.

### Register map
 
- `0x00`: Output enable for `uo_out[7:0]`
- `0x01`: Output enable for `uio_out[7:0]`
- `0x02`: PWM enable for `uo_out[7:0]`
- `0x03`: PWM enable for `uio_out[7:0]`
- `0x04`: PWM duty cycle


## How to test

Cocotb tests are used to verify SPI register writes, output behavior, PWM
frequency, and PWM duty cycle.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
