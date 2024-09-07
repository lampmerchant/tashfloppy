# Backend UART Protocol

**Subject to change!**

The backend transmits and receives at a bitrate of 1 MHz.


## Frontend to Backend

All command bytes not documented are ignored.


### `0xC?` - Hardware Configuration

These commands change the drive type that the backend represents itself to be.  One of them should be sent as soon as possible after powering the Macintosh on.  Changing drive type after this may have undesirable results.

* `0xC0` - No Drive (default)
* `0xC1` - Single-Sided Double-Density (400 kB) Drive
* `0xC2` - Double-Sided Double-Density (800 kB) Drive
* `0xC3` - SuperDrive (FDHD)


### `0xD?` - Insert Disk

These commands change the disk that the backend represents as inserted into the emulated drive.  They should only be used *after* an appropriate Hardware Configuration command.

* `0xD0` - Insert High-Density Disk, Read-Only
* `0xD1` - Insert High-Density Disk, Read-Write
* `0xD2` - Insert Double-Density Disk, Read-Only
* `0xD3` - Insert Double-Density Disk, Read-Write
* `0xDF` - Force Eject Disk


### `0xE?` - Enter Data Mode

These commands switch the transmitter into one of the available data modes and all incoming bytes thereafter are interpreted as data to be sent over the RDDATA line.

Incoming bytes are stored in a 256-byte circular queue.  The CTS line is deasserted when the queue's length reaches 192 bytes and reasserted when it falls to 63 bytes.

A break character (holding the UART line low for longer than a byte cell) causes an *immediate* return to command mode from data mode.  Bytes in the queue which have not yet been sent are discarded.


#### `0xE0` - Auto GCR

This mode is a stateful implementation of GCR, intended to take some of the burden of encoding off of the frontend.

Initially, all incoming bytes are sent directly over the RDDATA line as received, as falling edges transmitted at the rate of 500 kHz from MSb to LSb.  However, certain sequences cause state changes that affect the bytes that follow.

The sequence `0xD5 0xAA 0x96` is interpreted as the beginning of an address header and causes the following five bytes (low bits of cylinder number, sector number, head number and high bit of cylinder number, format, and checksum) to be nibblized directly, i.e. translated from six-bit nibbles into seven-bit IWM bytes with the MSb set, before returning to the initial state.

The sequence `0xD5 0xAA 0xAD` is interpreted as the beginning of a data sector and causes a more complicated series of state changes.  The byte immediately following the sequence (the sector number) is nibblized directly.  The 524 bytes following this (the sector tags and data) are packed from 174 groups of three and one group of two into 174 groups of four and one group of three and then nibblized.  The three bytes following this are packed from one group of three (the checksum bytes) into one group of four and then nibblized.  The state machine then returns to its initial state.

Note that it is still the frontend's responsibility to calculate the GCR checksum bytes and 'mangle' the outgoing data accordingly.


#### `0xE1` - Raw GCR with Random Noise

This mode is a raw implementation of GCR, intended to take a sequence of bits from the frontend and send them directly over the RDDATA line as falling edges transmitted at the rate of 500 kHz.  Where there are sequences of zeroes, it also injects pseudorandom noise into the outgoing bitstream, simulating the behavior of a real floppy drive's automatic gain control when it encounters a span of the disk surface with no flux transitions.

All incoming bytes are fed, bit by bit from MSb to LSb, through a four-bit shift register, in the following way:

* The incoming bit is shifted into bit 0 (the LSb) of the shift register.
* If there are any one bits in the shift register, bit 1 of the shift register is sent over RDDATA.
* If all four bits of the shift register are zeroes, a pseudorandom bit is sent over RDDATA.

For more information on this algorithm, see the [WOZ disk image reference](https://applesaucefdc.com/woz/reference2/).

If the queue of incoming bytes runs empty, `0x00` bytes will be fed into the shift register instead.

The pseudorandom number generator works in the following way:

* A free-running timer with an 8-bit register is initalized, incrementing at the rate of 8 MHz and resetting after incrementing to 254 (this helps to prevent it becoming synchronized with the outgoing data).
* For each byte received, a conversion on the microcontroller's analog-to-digital converter, which is connected to its temperature sensor, is initiated.
* Each bit in the incoming byte is processed as described above.  When a random bit is required, it is taken from the timer register's LSb and the timer register is shifted right, with a zero entering as the new MSb.
* When the byte is complete, the low 8 bits of the reading from the analog-to-digital converter are XORed with the timer register with the result stored in the timer register.


#### `0xE4` - Auto MFM

This mode is a stateful implementation of MFM.

Initially, most incoming bytes are sent directly over the RDDATA line as received, as falling edges transmitted at the rate of 1 MHz.  The 'data' bits of the outgoing bitstream are taken from the incoming byte from MSb to LSb and the 'clock' bits are computed automatically.  However, certain bytes are treated specially.

From the initial state, the bytes `0xC2` and `0xA1` have one clock bit dropped from their lower nibble, used by MFM encoding as part of an index, address, or data mark.

The byte `0xFE`, as the fourth byte in an address mark, signals that the next six bytes are to be exempt from the special casing applied to bytes by the initial state.  The byte `0xFB`, as the fourth byte in a data mark, signals that the next 514 bytes are to be exempt from the special casing applied to bytes by the initial state.

The byte `0xEE` has no special meaning in MFM, but this implementation treats it as a signal that an pulse is to be sent over the INDEX line while the byte is otherwise interpreted and sent as though it were a `0x4E` 'gap' byte.

When this command is initially received, the backend will wait for the first data byte before beginning to transmit.  Thereafter, because sync must be maintained, the frontend must keep the queue from emptying.  If the queue does empty, the backend will cease to transmit and refuse to start again until it receives a break character and another Enter Data Mode command.


## Backend Receiver to Frontend

All command bytes not documented are meaningless.


### `0x00` through `0x4F` - Step

These commands indicate that the drive has been instructed to step to a different cylinder.  The byte sent is the number of the cylinder stepped to.  The frontend should respond by sending a break character followed by an Enter Data Mode command and beginning to send data to be read from the drive.

Note that this is the drive's sole opportunity to dictate timing to the Macintosh instead of the other way around.  When the backend receives the step command, it asserts the !STEP signal and deasserts the !READY signal and these signals remain as such until the backend receives an Enter Data Mode command.


### `0x80` - Motor Off

This command indicates that the Macintosh has turned the drive motor off.  The frontend should respond by sending a break character and waiting for the disk to be ejected or for the drive motor to be turned on again.


### `0x81` - Motor On

This command indicates that the Macintosh has turned the drive motor on.  The frontend should respond by sending an Enter Data Mode command and beginning to send data to be read from the drive.


### `0x82`/`0x83` - GCR/MFM Mode

This command indicates that the Macintosh has cleared/set the MFMMODE signal.


### `0x84`/`0x85` - Select Head 0/1

This command indicates that the Macintosh has set the SEL signal to 0/1.  If it is not already transmitting data from head 0/1, the frontend should respond by sending a break character followed by an Enter Data Mode command and beginning to send data to be read from the drive.  Note that this command may be sent multiple times in succession indicating the same head and/or while the Macintosh has a signal other than the RDDATA line selected.


### `0x86`/`0x87` - Enter Data Mode on Head 0/1

This command indicates that the Macintosh has asserted the !WRREQ signal with the SEL signal set to 0/1.  The frontend should respond by sending a break character and interpreting all following bytes from the receiver as incoming data.

When all data received over the !WR line has been relayed and !WRREQ deasserted, the receiver sends a break character to return the frontend to command mode.

The format of the incoming data corresponds to the most recent Enter Data Mode command sent by the frontend.


#### Auto GCR

This format is selected when `0xE0` was the last Enter Data Mode command sent by the frontend.

This format corresponds to the Auto GCR mode.  It is a stateful implementation of GCR, intended to take some of the burden of decoding off of the frontend.

Initially, all incoming bytes are sent directly over the UART as received from the !WR line, with a transition (positive or negative) taken as the MSb of an 8-bit IWM byte (where the MSb is always set) and the following 7 bits taken at 47/96 (~0.490) MHz intervals, a transition equalling a one and no transition equalling a zero.  However, certain sequences cause state changes that affect the bytes that follow.

The sequence `0xD5 0xAA 0x96` is interpreted as the beginning of an address header and causes the following five bytes (low bits of cylinder number, sector number, head number and high bit of cylinder number, format, and checksum) to be denibblized directly, i.e. translated from seven-bit IWM bytes into six-bit nibbles, before returning to the initial state.

The sequence `0xD5 0xAA 0xAD` is interpreted as the beginning of a data sector and causes a more complicated series of state changes.  The byte immediately following the sequence (the sector number) is denibblized directly.  The 699 IWM bytes following this are denibblized and then unpacked from 174 groups of four and one group of three into 174 groups of three and one group of two (the sector tags and data).  The four IWM bytes following this are denibblized and then unpacked from one group of four into one group of three (the checksum bytes).  The state machine then returns to its initial state.

Note that it is still the frontend's responsibility to 'demangle' the outgoing data and verify the GCR checksum bytes.


#### Raw GCR

This format is selected when `0xE1` was the last Enter Data Mode command sent by the frontend.

This format corresponds to the Raw GCR mode.  It relays the bits transmitted by the Macintosh as received from the !WR line, with a transition (positive or negative) taken as the MSb of an 8-bit IWM byte (where the MSb is always set) and the following 7 bits taken at 47/96 (~0.490) MHz intervals, a transition equalling a one and no transition equalling a zero.  Note that the receiver recalibrates its timing on every one bit it receives and thus long sequences of zero bits may cause timing skew.

The bits relayed are sent to the frontend using a simple encoding that allows numbers of bits that are not integral multiples of 8 to be represented:

* `0b0XXXXXXX` - 7-bit payload
* `0b10XXXXXX` - 6-bit payload
* `0b110XXXXX` - 5-bit payload
* `0b1110XXXX` - 4-bit payload
* `0b11110XXX` - 3-bit payload
* `0b111110XX` - 2-bit payload
* `0b1111110X` - 1-bit payload
* `0b11111110` - 0-bit payload


#### Auto MFM

This format is selected when `0xE4` was the last Enter Data Mode command sent by the frontend.

The receiver waits for a sequence of 60 or more 'sync' bits, i.e. clock bits separated by 2 us, followed by a one data bit separated from the clock bits by a gap of 3 us, before relaying any data to the frontend.  Once this sequence is received, data bits are packed from MSb to LSb into 8-bit bytes and relayed directly to the frontend.  No special treatment is given to the `0xC2` and `0xA1` bytes that precede index, address, and data marks, and the frontend must infer their existence by context.


### `0x8E` - Eject Disk

This command indicates that the Macintosh has ejected the emulated floppy disk.
