#
# This file is part of LiteX.
#
# Copyright (c) 2022 Eric Matthews <eric.charles.matthews@gmail.com>
# SPDX-License-Identifier: BSD-2-Clause

import os

from migen import *

from litex import get_data_mod

from litex.gen import *

from litex.soc.interconnect import wishbone
from litex.soc.interconnect.csr import *
from litex.soc.cores.cpu import CPU, CPU_GCC_TRIPLE_RISCV32
from litex.soc.integration.soc import SoCRegion

# Variants -----------------------------------------------------------------------------------------

CPU_VARIANTS = ["minimal", "standard"]

# GCC Flags ----------------------------------------------------------------------------------------

GCC_FLAGS = {
    #                        /------------ Base ISA
    #                        |    /------- Hardware Multiply + Divide
    #                        |    |/----- Atomics
    #                        |    ||/---- Compressed ISA
    #                        |    |||/--- Single-Precision Floating-Point
    #                        |    ||||/-- Double-Precision Floating-Point
    #                        i    macfd
    "minimal"  : "-march=rv32i2p0   -mabi=ilp32 ",
    "standard" : "-march=rv32i2p0_m -mabi=ilp32 ",
}

# CVA5 ----------------------------------------------------------------------------------------------

class CVA5(CPU):
    category             = "softcore"
    family               = "riscv"
    name                 = "cva5"
    variants             = CPU_VARIANTS
    data_width           = 32
    endianness           = "little"
    gcc_triple           = CPU_GCC_TRIPLE_RISCV32
    linker_output_format = "elf32-littleriscv"
    nop                  = "nop"
    io_regions           = {0x80000000: 0x80000000} # origin, length
    plic_base            = 0xf0c0_0000
    clint_base           = 0xf001_0000

    # GCC Flags.
    @property
    def gcc_flags(self):
        flags = GCC_FLAGS[self.variant]
        flags += "-D__cva5__"
        return flags

    def __init__(self, platform, variant="standard"):
        self.platform     = platform
        self.variant      = variant
        self.human_name   = f"CVA5-{variant.upper()}"
        self.reset        = Signal()
        self.interrupt    = Signal(2)
        self.periph_buses = [] # Peripheral buses (Connected to main SoC's bus).
        self.memory_buses = [] # Memory buses (Connected directly to LiteDRAM).

        # # #

        # CPU Instance.
        self.cpu_params = dict(
            # Configuration.
            p_LITEX_VARIANT  = CPU_VARIANTS.index(variant),
            p_RESET_VEC      = 0,
            p_NON_CACHABLE_L = 0x80000000, # FIXME: Use io_regions.
            p_NON_CACHABLE_H = 0xFFFFFFFF, # FIXME: Use io_regions.

            # Clk/Rst.
            i_clk = ClockSignal("sys"),
            i_rst = ResetSignal("sys"),

            # Interrupts.
            i_litex_interrupt = self.interrupt
        )
        # CPU Wishbone Buses.
        if variant == "minimal":
            # Minimal variant has no caches, no multiply or divide support, and no branch predictor.
            # It also uses separate fetch and load-store wishbone interfaces.
            self.ibus = ibus = wishbone.Interface(data_width=32, address_width=32, addressing="word")
            self.dbus = dbus = wishbone.Interface(data_width=32, address_width=32, addressing="word")
            self.periph_buses.append(ibus)
            self.periph_buses.append(dbus)
            self.cpu_params.update(
                o_ibus_adr   = ibus.adr,
                o_ibus_dat_w = ibus.dat_w,
                o_ibus_sel   = ibus.sel,
                o_ibus_cyc   = ibus.cyc,
                o_ibus_stb   = ibus.stb,
                o_ibus_we    = ibus.we,
                o_ibus_cti   = ibus.cti,
                o_ibus_bte   = ibus.bte,
                i_ibus_dat_r = ibus.dat_r,
                i_ibus_ack   = ibus.ack,
                i_ibus_err   = ibus.err,

                o_dbus_adr   = dbus.adr,
                o_dbus_dat_w = dbus.dat_w,
                o_dbus_sel   = dbus.sel,
                o_dbus_cyc   = dbus.cyc,
                o_dbus_stb   = dbus.stb,
                o_dbus_we    = dbus.we,
                o_dbus_cti   = dbus.cti,
                o_dbus_bte   = dbus.bte,
                i_dbus_dat_r = dbus.dat_r,
                i_dbus_ack   = dbus.ack,
                i_dbus_err   = dbus.err
            )
        if variant == "standard":
            # Standard variant includes instruction and data caches, multiply and divide support
            # along with the branch predictor. It uses a shared wishbone interface.
            self.idbus = idbus = wishbone.Interface(data_width=32, address_width=32, addressing="word")
            self.periph_buses.append(idbus)
            self.cpu_params.update(
                o_idbus_adr   = idbus.adr,
                o_idbus_dat_w = idbus.dat_w,
                o_idbus_sel   = idbus.sel,
                o_idbus_cyc   = idbus.cyc,
                o_idbus_stb   = idbus.stb,
                o_idbus_we    = idbus.we,
                o_idbus_cti   = idbus.cti,
                o_idbus_bte   = idbus.bte,
                i_idbus_dat_r = idbus.dat_r,
                i_idbus_ack   = idbus.ack,
                i_idbus_err   = idbus.err,
            )
        self.add_sources(platform)

    def set_reset_address(self, reset_address):
        assert not hasattr(self, "reset_address")
        self.reset_address = reset_address
        self.cpu_params.update(p_RESET_VEC=reset_address)

    @staticmethod
    def add_sources(platform):
        platform.add_source("/media/litex/plic/PLIC.sv")
        platform.add_source("/media/CVA5_PLIC/CLINT/clint.sv")
        
        cva5_path = get_data_mod("cpu", "cva5").data_location
        with open(os.path.join(cva5_path, "tools/compile_order"), "r") as f:
            for line in f:
                if line.strip() != '':
                    platform.add_source(os.path.join(cva5_path, line.strip()))
        platform.add_source(os.path.join(cva5_path, "examples/litex/l1_to_wishbone.sv"))
        platform.add_source(os.path.join(cva5_path, "examples/litex/litex_wrapper.sv"))

    def do_finalize(self):
        assert hasattr(self, "reset_address")
        self.specials += Instance("litex_wrapper", **self.cpu_params)
    def add_soc_components(self, soc):
        # print('here')
        # exit()
        self.plicbus = plicbus  = wishbone.Interface(data_width=32, address_width=32, addressing="word")
        
        s_interrupt = Signal()
        m_interrupt = Signal()
        cpu_irqs = Signal(2)
        self.specials += Instance("wishbone_plic_top",
            # p_PADDR_SIZE = 30,
            # p_PDATA_SIZE = 32,
            p_SOURCES           = 32,
            p_TARGETS           = 2,
            i_clk = ClockSignal("sys"),
            i_reset = ResetSignal("sys"),
            i_wb_cyc = plicbus.cyc,
            i_wb_stb = plicbus.stb,
            i_wb_we = plicbus.we,
            i_wb_adr = plicbus.adr,
            i_wb_dat_i = plicbus.dat_w,
            o_wb_dat_o = plicbus.dat_r,
            o_wb_ack = plicbus.ack,
            i_sources = self.interrupt,
            o_targets = cpu_irqs
        )
        self.comb += [
            m_interrupt.eq(cpu_irqs[0]),
            s_interrupt.eq(cpu_irqs[1])
        ]
        # ahb2_wishbone  = ahb.AHB2Wishbone(ahb  = amba_bus, wishbone = plicbus)

        self.cpu_params.update(
            i_cpu_s_interrupt       = s_interrupt,
            i_cpu_m_interrupt       = m_interrupt
        )
        # self.submodules += ahb2_wishbone
        soc.bus.add_slave("plic", self.plicbus, region=SoCRegion(origin=self.plic_base, size=0x40_0000, cached=False))



        self.mtime = Signal(64)
        self.software_in = Signal()
        self.timer_in = Signal()
        self.clintbus = clintbus = wishbone.Interface(data_width=32, address_width=32, addressing="word")

        self.specials += Instance("clint",
            # p_PADDR_SIZE = 30,
            # p_PDATA_SIZE = 32,
            i_clk = ClockSignal("sys"),
            i_reset = ResetSignal("sys"),
            i_wb_cyc = clintbus.cyc,
            i_wb_stb = clintbus.stb,
            i_wb_we = clintbus.we,
            i_wb_adr = clintbus.adr,
            i_wb_dat_i = clintbus.dat_w,
            o_wb_dat_o = clintbus.dat_r,
            o_wb_ack = clintbus.ack,
            i_rtc_i = ClockSignal("sys"),
            o_timer_irq_o = self.timer_in,
            o_ipi_o = self.software_in,
            o_mtime_o  = self.mtime
        )

        self.cpu_params.update(
            i_mtime    = self.mtime,
            i_cpu_software_in      = self.software_in,
            i_cpu_timer_in       = self.timer_in
        )

        soc.bus.add_slave("clint", clintbus, region=SoCRegion(origin=self.clint_base, size=0x1_0000, cached=False))