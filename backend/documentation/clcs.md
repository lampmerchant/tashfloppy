# CLC Arrangements

## Floppy Mode

### Multiplexer

```
                     CLC1
                      |\
 FTX (TMX from Tx) ---|0|___ RD
 FRX (TMX from Rx) ---|1|
                      |/
                       |
                      CA1
  CLC2 is unused
                     CLC3
                      |\
          SWITCHED ---|0|___ TRX
 !TACH/INDEX (CCP1)---|1|
      |               |/
      |                |
      |               SEL
      `--------------------- TTX

```


### Transmitter

```
        ____
CA0 ---|LUT |----------------------------------.   CLC3
SEL ---|____|   LUT muxes !DIRTN, !CSTIN,      |    |\
        CLC1    !STEP, and !WRPROT             '----|0|
 ________________________________________________   | |
/                      CLC2                      \  | |___ TMX
                                              |\    | |
RDDATA (SDO NAND SCK) or FMX (TTX from Mx) ---|0|   | |
when !WRREQ is high      else          ___    | |---|1|
or MFMMODE is low              SEL ---|LUT|---|1|   |/
                                      |___|   |/     |
          LUT muxes SUPERDRIVE and MFMMODE     |    CA2
                                              CA0

```


### Receiver

```
                     ____    |\
             SEL ---|LUT |---|0|  CLC3
                    |____|   | |   |\
LUT muxes !MOTORON and !TK0  | |---|0|
                             | |   | |
        FMX (TRX from Mx) ---|1|   | |
                             |/    | |
                              |    | |--- TMX
                             CA0   | |
\_____________CLC1______________/  | |
                           ____    | |
 LUT muxes SIDES,  CA0 ---|LUT |---|1|
 !READY, !DRVIN,   SEL ---|____|   |/
 and PRESENT/!HD           CLC2     |
                                   CA2

```


## DCD Mode

### Multiplexer

```
When !HSHK is high (idle):
        ___
SDO ---|   \     |\
SCK ---|    )O---|0|
CA1 ---|___/     | |___ RD
                 | |
         !CA1 ---|1|
                 |/
                  |
                 CA2

When !HSHK is low (ready):
        ___
SDO ---|   \    |\
SCK ---|    )---|0|
CA1 ---|___/    | |___ RD
                | |
        !CA1 ---|1|
                |/
                 |
                CA2
\_______CLC2_______/

```


### Transmitter

* `FMX (TTX from Mx) --- CTS`
* `!WRREQ --- TMX`


### Receiver

* `FMX (TRX from Mx) --- Tx`
* `!WR --- TMX`


## Bootloader

### Multiplexer, when not selected

* `FRX (TMX from Rx) --- TTX`
* `FTX (TMX from Tx) --- TRX`


### Multiplexer, when selected

* `UART CTS --- TTX`
* `UART Tx --- TRX`


### Transmitter, when not selected

* `FMX (TTX from Mx) --- CTS`
* `1 (Tx, idle) --- TMX`


### Transmitter, when selected

* `UART CTS --- CTS`
* `UART Tx --- TMX`


### Receiver, when not selected

* `FMX (TRX from Mx) --- Tx`
* `0 (CTS, asserted) --- TMX`


### Receiver, when selected

* `UART CTS --- TMX`
* `UART Tx --- Tx`
