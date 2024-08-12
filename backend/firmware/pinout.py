from itertools import batched  # requires Python 3.12 or later
import os.path


# Pin assignments - change these as appropriate for PCB

DT_NENBL = 'RA5'
DT_CA3 = 'RA4'
DT_CA2 = 'RA3'
DT_CA1 = 'RA2'
DT_CA0 = 'RA1'
DT_SEL = 'RA0'
DT_CLC_FROM_RX = 'RC5'
DT_CLC_FROM_TX = 'RC4'
DT_CLC_TO_RX = 'RC3'
DT_CCP_FROM_TX = 'RC2'
DT_RD_OUT = 'RC1'
DT_UART_RX = 'RC0'

RX_NENBL = 'RA5'
RX_CA3 = 'RA4'
RX_CA2 = 'RA3'
RX_CA1 = 'RA2'
RX_CA0 = 'RA1'
RX_SEL = 'RA0'
RX_CLC_FROM_DT = 'RC5'
RX_CLC_TO_DT = 'RC4'
RX_NWRREQ = 'RC3'
RX_NWR = 'RC2'
RX_UART_RX = 'RC1'
RX_UART_TX = 'RC0'

TX_NENBL = 'RA5'
TX_CA3 = 'RA4'
TX_CA2 = 'RA3'
TX_CA1 = 'RA2'
TX_CA0 = 'RA1'
TX_SEL = 'RA0'
TX_CLC_TO_DT = 'RC5'
TX_CCP_TO_DT = 'RC4'
TX_NWRREQ = 'RC3'
TX_UART_RX = 'RC2'
TX_UART_CTS = 'RC1'


# Script

script_path = os.path.dirname(os.path.realpath(__file__))

if len(set(i[1] for i in (DT_CA2, DT_CA1, DT_CA0, DT_SEL))) != 1:
  raise Exception("DCD transmitter's CA2, CA1, CA0, and SEL must all be on the same port")
if len(set(i[1] for i in (RX_CA2, RX_CA1, RX_CA0, RX_SEL))) != 1:
  raise Exception("receiver's CA2, CA1, CA0, and SEL must all be on the same port")
if len(set(i[1] for i in (TX_CA2, TX_CA1, TX_CA0, TX_SEL))) != 1:
  raise Exception("transmitter's CA2, CA1, CA0, and SEL must all be on the same port")

def gen_pin(name, pin):
  yield '%s_PIN' % name, pin
  yield '%s_PORT' % name, 'PORT%s' % pin[1]
  yield '%s_IOCF' % name, 'IOC%sF' % pin[1]
  yield '%s_IOCP' % name, 'IOC%sP' % pin[1]
  yield '%s_IOCN' % name, 'IOC%sN' % pin[1]
  if pin != 'RA3': yield '%s_PPS' % name, '%sPPS' % pin
  yield '%s_PPSI' % name, '%s ;%s' % ({'RA0': "B'00000'",
                                       'RA1': "B'00001'",
                                       'RA2': "B'00010'",
                                       'RA3': "B'00011'",
                                       'RA4': "B'00100'",
                                       'RA5': "B'00101'",
                                       'RC0': "B'10000'",
                                       'RC1': "B'10001'",
                                       'RC2': "B'10010'",
                                       'RC3': "B'10011'",
                                       'RC4': "B'10100'",
                                       'RC5': "B'10101'"}[pin], pin)

def make_pinout(filename, equs):
  with open(filename, 'w') as g:
    for k, v in equs.items():
      g.write('%s%sequ\t%s\n' % (k, '\t' if len(k) >= 8 else '\t\t', v))

dt_equs = {
  'CMD_PORT': 'PORT%s' % DT_SEL[1],
}
dt_equs.update(gen_pin('NEN', DT_NENBL))
dt_equs.update(gen_pin('CA3', DT_CA3))
dt_equs.update(gen_pin('CA2', DT_CA2))
dt_equs.update(gen_pin('CA1', DT_CA1))
dt_equs.update(gen_pin('CA0', DT_CA0))
dt_equs.update(gen_pin('SEL', DT_SEL))
dt_equs.update(gen_pin('CFR', DT_CLC_FROM_RX))
dt_equs.update(gen_pin('CFT', DT_CLC_FROM_TX))
dt_equs.update(gen_pin('CTR', DT_CLC_TO_RX))
dt_equs.update(gen_pin('TFT', DT_CCP_FROM_TX))
dt_equs.update(gen_pin('RD', DT_RD_OUT))
dt_equs.update(gen_pin('RX', DT_UART_RX))

rx_equs = {
  'CMD_PORT': 'PORT%s' % RX_SEL[1],
}
rx_equs.update(gen_pin('NEN', RX_NENBL))
rx_equs.update(gen_pin('CA3', RX_CA3))
rx_equs.update(gen_pin('CA2', RX_CA2))
rx_equs.update(gen_pin('CA1', RX_CA1))
rx_equs.update(gen_pin('CA0', RX_CA0))
rx_equs.update(gen_pin('SEL', RX_SEL))
rx_equs.update(gen_pin('CFD', RX_CLC_FROM_DT))
rx_equs.update(gen_pin('CTD', RX_CLC_TO_DT))
rx_equs.update(gen_pin('NWQ', RX_NWRREQ))
rx_equs.update(gen_pin('NWR', RX_NWR))
rx_equs.update(gen_pin('RX', RX_UART_RX))
rx_equs.update(gen_pin('TX', RX_UART_TX))

tx_equs = {
  'CMD_PORT': 'PORT%s' % TX_SEL[1],
}
tx_equs.update(gen_pin('NEN', TX_NENBL))
tx_equs.update(gen_pin('CA3', TX_CA3))
tx_equs.update(gen_pin('CA2', TX_CA2))
tx_equs.update(gen_pin('CA1', TX_CA1))
tx_equs.update(gen_pin('CA0', TX_CA0))
tx_equs.update(gen_pin('SEL', TX_SEL))
tx_equs.update(gen_pin('TTD', TX_CCP_TO_DT))
tx_equs.update(gen_pin('CTD', TX_CLC_TO_DT))
tx_equs.update(gen_pin('NWQ', TX_NWRREQ))
tx_equs.update(gen_pin('RX', TX_UART_RX))
tx_equs.update(gen_pin('CTS', TX_UART_CTS))

make_pinout(os.path.join(script_path, 'dcdtransmitter', 'dcdtransmitter_pinout.inc'), dt_equs)
make_pinout(os.path.join(script_path, 'receiver', 'receiver_pinout.inc'), rx_equs)
make_pinout(os.path.join(script_path, 'transmitter', 'transmitter_pinout.inc'), tx_equs)

def gen_lut(ca2, ca1, ca0, sel):
  for i in range(64):
    yield (8 if i & 1 << ca2 else 0) | (4 if i & 1 << ca1 else 0) | (2 if i & 1 << ca0 else 0) | (1 if i & 1 << sel else 0)

def make_lut(filename, ca2, ca1, ca0, sel):
  with open(filename, 'w') as g:
    for line in batched(gen_lut(ca2, ca1, ca0, sel), n=8):
      g.write('\tdt\t%s\n' % ','.join(('0x%02X' % i) for i in line))

make_lut(os.path.join(script_path, 'dcdtransmitter', 'dcdtransmitter_lut.inc'),
         int(DT_CA2[-1]), int(DT_CA1[-1]), int(DT_CA0[-1]), int(DT_SEL[-1]))
make_lut(os.path.join(script_path, 'receiver', 'receiver_lut.inc'),
         int(RX_CA2[-1]), int(RX_CA1[-1]), int(RX_CA0[-1]), int(RX_SEL[-1]))
make_lut(os.path.join(script_path, 'transmitter', 'transmitter_lut.inc'),
         int(TX_CA2[-1]), int(TX_CA1[-1]), int(TX_CA0[-1]), int(TX_SEL[-1]))
