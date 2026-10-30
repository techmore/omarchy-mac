#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
"""Exercise extracted Broadcom DMA-selection source without hardware or kernel writes."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def definition(text, header):
    start = text.index(header)
    opening = text.index('{', start)
    depth = 0
    for i in range(opening, len(text)):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    raise ValueError('unbalanced function body')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('msgbuf', type=Path, help='candidate brcmfmac/msgbuf.c')
    args = parser.parse_args()
    text = args.msgbuf.read_text()
    selector = definition(text, 'static enum dma_data_direction\nbrcmf_msgbuf_rx_dma_direction(')
    initializer = definition(text, 'static struct brcmf_msgbuf_pktids *\nbrcmf_msgbuf_init_pktids(')
    program = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdlib.h>
typedef unsigned int u32;
enum dma_data_direction { DMA_BIDIRECTIONAL = 0, DMA_TO_DEVICE = 1, DMA_FROM_DEVICE = 2 };
struct pci_dev { unsigned short vendor, device; };
struct device { bool pci; struct pci_dev *parent; };
struct brcmf_msgbuf_pktid { int unused; };
struct brcmf_msgbuf_pktids { u32 array_size, last_allocated_idx; enum dma_data_direction direction; struct brcmf_msgbuf_pktid *array; };
#define PCI_VENDOR_ID_BROADCOM 0x14e4
#define BRCM_PCIE_4387_DEVICE_ID 0x4433
#define BRCM_PCIE_4388_DEVICE_ID 0x4434
#define dev_is_pci(dev) ((dev)->pci)
#define to_pci_dev(dev) ((dev)->parent)
#define dev_info(dev, ...) ((void)(dev))
#define kzalloc_objs(obj, count) calloc((count), sizeof(obj))
#define kzalloc_obj(obj) calloc(1, sizeof(obj))
#define kfree(ptr) free(ptr)
''' + selector + '\n' + initializer + r'''
int main(void) {
    struct pci_dev radio = { PCI_VENDOR_ID_BROADCOM, BRCM_PCIE_4387_DEVICE_ID };
    struct device dev = { true, &radio };
    assert(brcmf_msgbuf_rx_dma_direction(&dev) == DMA_BIDIRECTIONAL);
    radio.device = BRCM_PCIE_4388_DEVICE_ID;
    assert(brcmf_msgbuf_rx_dma_direction(&dev) == DMA_BIDIRECTIONAL);
    radio.device = 0x9999;
    assert(brcmf_msgbuf_rx_dma_direction(&dev) == DMA_FROM_DEVICE);
    radio.device = BRCM_PCIE_4388_DEVICE_ID;
    radio.vendor = 0xffff;
    assert(brcmf_msgbuf_rx_dma_direction(&dev) == DMA_FROM_DEVICE);
    dev.pci = false;
    assert(brcmf_msgbuf_rx_dma_direction(&dev) == DMA_FROM_DEVICE);
    struct brcmf_msgbuf_pktids *tx = brcmf_msgbuf_init_pktids(2, DMA_TO_DEVICE);
    struct brcmf_msgbuf_pktids *rx = brcmf_msgbuf_init_pktids(2, DMA_BIDIRECTIONAL);
    assert(tx && rx && tx->direction == DMA_TO_DEVICE && rx->direction == DMA_BIDIRECTIONAL);
    free(tx->array); free(tx); free(rx->array); free(rx);
    return 0;
}
'''
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / 'test.c'
        executable = Path(tmp) / 'test'
        source.write_text(program)
        subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(source), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)
    print('Extracted DMA selector and direction initialization passed; no hardware exercised.')


if __name__ == '__main__':
    main()
