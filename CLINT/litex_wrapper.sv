/*
 * Copyright Â© 2022 Eric Matthews,  Lesley Shannon
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Initial code developed under the supervision of Dr. Lesley Shannon,
 * Reconfigurable Computing Lab, Simon Fraser University.
 *
 * Author(s):
 *             Eric Matthews <ematthew@sfu.ca>
 */

module litex_wrapper
    import cva5_config::*;
    import cva5_types::*;
    import l2_config_and_types::*;

    #(
        parameter  LITEX_VARIANT = 0,
        parameter bit [31:0] RESET_VEC = 0,
        parameter bit [31:0] NON_CACHABLE_L = 32'h80000000,
        parameter bit [31:0] NON_CACHABLE_H =32'hFFFFFFFF
    )

    (
        input logic clk,
        input logic rst,
        input logic [15:0] litex_interrupt,
        input logic cpu_m_interrupt,
        input logic cpu_s_interrupt,
        input logic cpu_software_in,
        input logic cpu_timer_in,
        input logic [63:0] mtime,
        output logic [29:0] ibus_adr,
        output logic [31:0] ibus_dat_w,
        output logic [3:0] ibus_sel,
        output logic ibus_cyc,
        output logic ibus_stb,
        output logic ibus_we,
        output logic ibus_cti,
        output logic ibus_bte,
        input logic [31:0] ibus_dat_r,
        input logic ibus_ack,
        input logic ibus_err,

        output logic [29:0] dbus_adr,
        output logic [31:0] dbus_dat_w,
        output logic [3:0] dbus_sel,
        output logic dbus_cyc,
        output logic dbus_stb,
        output logic dbus_we,
        output logic dbus_cti,
        output logic dbus_bte,
        input logic [31:0] dbus_dat_r,
        input logic dbus_ack,
        input logic dbus_err,

        output logic [29:0] idbus_adr,
        output logic [31:0] idbus_dat_w,
        output logic [3:0] idbus_sel,
        output logic idbus_cyc,
        output logic idbus_stb,
        output logic idbus_we,
        output logic idbus_cti,
        output logic idbus_bte,
        input logic [31:0] idbus_dat_r,
        input logic idbus_ack,
        input logic idbus_err
    );


    localparam wb_group_config_t MINIMAL_WB_GROUP_CONFIG = '{
        0 : '{0: ALU_ID, default : NON_WRITEBACK_ID},
        1 : '{0: LS_ID, 1: CSR_ID, default : NON_WRITEBACK_ID},
        default : '{default : NON_WRITEBACK_ID}
    };

    localparam cpu_config_t MINIMAL_CONFIG = '{
        //ISA options
        MODES : M,
        INCLUDE_UNIT : '{
            ALU : 1,
            LS : 1,
            MUL : 0,
            DIV : 0,
            CSR : 1,
            FPU : 0,
            CUSTOM : 0,
            BR : 1,
            IEC : 1
        },
        INCLUDE_IFENCE : 0,
        INCLUDE_AMO : 0,
        INCLUDE_CBO : 0,
        //CSR constants
        CSRS : '{
            MACHINE_IMPLEMENTATION_ID : 0,
            CPU_ID : 0,
            RESET_VEC : RESET_VEC,
            RESET_TVEC : 32'h00000000,
            MCONFIGPTR : '0,
            INCLUDE_SSTC : 0,
            INCLUDE_ZIHPM : 1,
            INCLUDE_ZICNTR : 1,
            INCLUDE_SMSTATEEN : 1

        },
        //Memory Options
        SQ_DEPTH : 2,
        INCLUDE_FORWARDING_TO_STORES : 0,
        AMO_UNIT : '{
            LR_WAIT : 8,
            RESERVATION_WORDS : 8
        },
        INCLUDE_ICACHE : 0,
        ICACHE_ADDR : '{
            L: 32'h40000000,
            H: 32'h4FFFFFFF
        },
        ICACHE : '{
            LINES : 512,
            LINE_W : 4,
            WAYS : 2,
            USE_EXTERNAL_INVALIDATIONS : 0,
            USE_NON_CACHEABLE : 0,
            NON_CACHEABLE : '{
                L: 32'h00000000,
                H: 32'h00000000
            }
        },
        ITLB : '{
            WAYS : 2,
            DEPTH : 64
        },
        INCLUDE_DCACHE : 0,
        DCACHE_ADDR : '{
            L: 32'h40000000,
            H: 32'h4FFFFFFF
        },
        DCACHE : '{
            LINES : 512,
            LINE_W : 4,
            WAYS : 2,
            USE_EXTERNAL_INVALIDATIONS : 0,
            USE_NON_CACHEABLE : 0,
            NON_CACHEABLE : '{
                L: 32'h00000000,
                H: 32'h00000000
            }
        },
        DTLB : '{
            WAYS : 2,
            DEPTH : 64
        },
        INCLUDE_ILOCAL_MEM : 0,
        ILOCAL_MEM_ADDR : '{
            L : 32'h80000000, 
            H : 32'h8FFFFFFF
        },
        INCLUDE_DLOCAL_MEM : 0,
        DLOCAL_MEM_ADDR : '{
            L : 32'h80000000,
            H : 32'h8FFFFFFF
        },
        INCLUDE_IBUS : 1,
        IBUS_ADDR : '{
            L : 32'h00000000, 
            H : 32'hFFFFFFFF
        },
        INCLUDE_PERIPHERAL_BUS : 1,
        PERIPHERAL_BUS_ADDR : '{
            L : 32'h00000000,
            H : 32'hFFFFFFFF
        },
        PERIPHERAL_BUS_TYPE : WISHBONE_BUS,
        //Branch Predictor Options
        INCLUDE_BRANCH_PREDICTOR : 0,
        BP : '{
            WAYS : 2,
            ENTRIES : 512,
            RAS_ENTRIES : 8
        },
        //Writeback Options
        NUM_WB_GROUPS : 2,
        WB_GROUP : MINIMAL_WB_GROUP_CONFIG
    };

    localparam wb_group_config_t STANDARD_WB_GROUP_CONFIG = '{
        0 : '{0: ALU_ID, default : NON_WRITEBACK_ID},
        1 : '{0: LS_ID, default : NON_WRITEBACK_ID},
        2 : '{0: MUL_ID, 1: DIV_ID, 2: CSR_ID, 3: CUSTOM_ID, default : NON_WRITEBACK_ID},
        default : '{default : NON_WRITEBACK_ID}
    };

    localparam cpu_config_t STANDARD_CONFIG = '{
        //ISA options
        MODES : MSU,
        INCLUDE_UNIT : '{
            ALU : 1,
            LS : 1,
            MUL : 1,
            DIV : 1,
            CSR : 1,
            FPU : 0,
            CUSTOM : 0,
            BR : 1,
            IEC : 1
        },
        INCLUDE_IFENCE : 1,
        INCLUDE_AMO : 1,
        INCLUDE_CBO : 0,

        //CSR constants
        CSRS : '{
            MACHINE_IMPLEMENTATION_ID : 0,
            CPU_ID : 0,
            RESET_VEC : RESET_VEC,
            RESET_TVEC : 32'h00000000,
            MCONFIGPTR : '0,
            INCLUDE_ZICNTR : 1,
	    INCLUDE_ZIHPM : 1,
	    INCLUDE_SSTC : 1,
            INCLUDE_SMSTATEEN : 1
        },
        //Memory Options
        SQ_DEPTH : 4,
        INCLUDE_FORWARDING_TO_STORES : 1,
        AMO_UNIT : '{
            LR_WAIT : 8,
            RESERVATION_WORDS : 8
        },
        INCLUDE_ICACHE : 1,
        ICACHE_ADDR : '{
            L : 32'h00000000, 
            H : 32'hFFFFFFFF
        },
        ICACHE : '{
            LINES : 512,
            LINE_W : 8,
            WAYS : 2,
            USE_EXTERNAL_INVALIDATIONS : 0,
            USE_NON_CACHEABLE : 0,
            NON_CACHEABLE : '{
                L: NON_CACHABLE_L,
                H: NON_CACHABLE_H
            }
        },
        ITLB : '{
            WAYS : 2,
            DEPTH : 64
        },
        INCLUDE_DCACHE : 1,
        DCACHE_ADDR : '{
            L : 32'h00000000, 
            H : 32'hFFFFFFFF
        },
        DCACHE : '{
            LINES : 512,
            LINE_W : 8,
            WAYS : 2,
            USE_EXTERNAL_INVALIDATIONS : 0,
            USE_NON_CACHEABLE : 1,
            NON_CACHEABLE : '{
                L: NON_CACHABLE_L,
                H: NON_CACHABLE_H
            }
        },
        DTLB : '{
            WAYS : 2,
            DEPTH : 64
        },
        INCLUDE_ILOCAL_MEM : 0,
        ILOCAL_MEM_ADDR : '{
            L : 32'h80000000, 
            H : 32'h8FFFFFFF
        },
        INCLUDE_DLOCAL_MEM : 0,
        DLOCAL_MEM_ADDR : '{
            L : 32'h80000000,
            H : 32'h8FFFFFFF
        },
        INCLUDE_IBUS : 0,
        IBUS_ADDR : '{
            L : 32'h00000000, 
            H : 32'hFFFFFFFF
        },
        INCLUDE_PERIPHERAL_BUS : 0,
        PERIPHERAL_BUS_ADDR : '{
            L : 32'h00000000,
            H : 32'hFFFFFFFF
        },
        PERIPHERAL_BUS_TYPE : WISHBONE_BUS,
        //Branch Predictor Options
        INCLUDE_BRANCH_PREDICTOR : 1,
        BP : '{
            WAYS : 2,
            ENTRIES : 512,
            RAS_ENTRIES : 8
        },
        //Writeback Options
        NUM_WB_GROUPS : 3,
        WB_GROUP : STANDARD_WB_GROUP_CONFIG
    };

    function cpu_config_t config_select (input integer variant);
        case (variant)
            0 : config_select = MINIMAL_CONFIG;
            1 : config_select = STANDARD_CONFIG;
            default : config_select = STANDARD_CONFIG;
        endcase
    endfunction

    localparam cpu_config_t LITEX_CONFIG = config_select(LITEX_VARIANT);


    //Unused interfaces
    axi_interface m_axi();
    avalon_interface m_avalon();
    local_memory_interface instruction_bram();
    local_memory_interface data_bram();
    interrupt_t s_interrupt;
    assign s_interrupt.software = 0;
    assign s_interrupt.external = cpu_s_interrupt;

    //L2 to Wishbone
    l2_requester_interface l2();

    //Wishbone interfaces
    wishbone_interface dwishbone();
    wishbone_interface iwishbone();
    wishbone_interface idwishbone();

    //Timer and External interrupts
    interrupt_t m_interrupt;
    assign m_interrupt.software = cpu_software_in;
    assign m_interrupt.timer = cpu_timer_in;
    assign m_interrupt.external = cpu_m_interrupt;
    // logic [63:0] mtime;

    cva5 #(.CONFIG(LITEX_CONFIG)) cpu(.*);

    generate if (LITEX_VARIANT != 0) begin : l1_arb_gen
        l1_to_wishbone  arb(.*, .cpu(l2), .wishbone(idwishbone));
        assign idbus_adr = idwishbone.adr;
        assign idbus_dat_w = idwishbone.dat_w;
        assign idbus_sel = idwishbone.sel;
        assign idbus_cyc = idwishbone.cyc;
        assign idbus_stb = idwishbone.stb;
        assign idbus_we = idwishbone.we;
        assign idbus_cti = idwishbone.cti;
        assign idbus_bte = idwishbone.bte;
        assign idwishbone.dat_r = idbus_dat_r;
        assign idwishbone.ack = idbus_ack;
        assign idwishbone.err = idbus_err;
    end else begin
        assign ibus_adr = iwishbone.adr;
        assign ibus_dat_w = iwishbone.dat_w;
        assign ibus_sel = iwishbone.sel;
        assign ibus_cyc = iwishbone.cyc;
        assign ibus_stb = iwishbone.stb;
        assign ibus_we = iwishbone.we;
        assign ibus_cti = iwishbone.cti;
        assign ibus_bte = iwishbone.bte;
        assign iwishbone.dat_r = ibus_dat_r;
        assign iwishbone.ack = ibus_ack;
        assign iwishbone.err = ibus_err;

        assign dbus_adr = dwishbone.adr;
        assign dbus_dat_w = dwishbone.dat_w;
        assign dbus_sel = dwishbone.sel;
        assign dbus_cyc = dwishbone.cyc;
        assign dbus_stb = dwishbone.stb;
        assign dbus_we = dwishbone.we;
        assign dbus_cti = dwishbone.cti;
        assign dbus_bte = dwishbone.bte;
        assign dwishbone.dat_r = dbus_dat_r;
        assign dwishbone.ack = dbus_ack;
        assign dwishbone.err = dbus_err;
    end endgenerate


endmodule