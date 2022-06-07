// SPDX-FileCopyrightText: 2022 AnalogMiko
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0
//
// -- hp 35 wrapper --
// The Display chips are excluded
// Compared to the original source code written by R. J. Weinstein, 
// the only major change is that the inout ports are replaced by MUX counterparts
//
// (c) AL Jun 4th 2022
// AnalogMiko.com

module hp35_core(
`ifdef USE_POWER_PINS
	inout vccd1,	// User area 1 1.8V power
	inout vssd1,	// User area 1 digital ground
`endif
    // output [7:0] ROW,       // Keyboard Scan ROW,     Output from CTC
    // Use Q53 to save IO
    input  [4:0] COL,       // Keyboard Scan COL,     Input to CTC
    input        cdiv_rst,  // Controled by caravel, internal divider force reset
    input        dbg_internal_cdiv,    // Use internal clock?
    input        osc_in,    // Input Clock
    input        phi1_in,   // Global Clock Signal,   Input from External
    input        phi2_in,   // Global Clock Signal,   Input from External
    output       phi1_out,
    output       phi2_out,
    output       phi_oen,
    input        PWO,       // CTC PWO Reset Control, Input from External
    output [4:0] DD,        // Display Bus,           Output from ARC
    output       START,     // Display Start Control, Output from ARC
    
    input        is_in,     // Instruction Bus,       Input to CTC
    output       is_bus,    // Instruction Bus,       Output from Internal ROM
    output       is_oen,     // Instruction Bus,       Output Control from Internal ROM

    
    input        ws_in,     // Word Select Bus,  from CTC or ROM to ARC
    output       ws_bus,    // Word Select Bus,  from 
    output       ws_oen,   
    input        bcd_in,    // BCD Peripheral Bus, from RAM to ARC
    output       bcd_bus,   // BCD Peripheral Bus, from ARC to RAM
    output       bcd_oen,   // BCD Bus Enable,     from ARC to RAM
    
    input        ia_in,     // Address Bus,           Only useful when the CTC is disabled
    output       ia_bus,    // Address Bus,           Output from CTC
    output       ia_oen,
    output       carry_bus, // Carry,       from ARC to CTC
    input        carry_in,  // Carry input, used when the ARC is disabled
    output       carry_oen,
    output       sync_bus,  // Global SYNC, from CTC to all
    input        sync_in,   // Global SYNC input, used when the CTC is disable
    output       sync_oen,
    // When any of the following signals is not asserted,
    // The correosponding bus connection will be disabled, 
    // For the non-tristate design, it means that the MUX bus is now owned by the IO port
    input        dbg_disable_arc,
    input        dbg_disable_ctc,
    input        dbg_disable_rom,
    input        dbg_arc_dummy,
    input        dbg_force_data,
    input [9:0]  dbg_romdata,
    input        dbg_sram_csb1,
    output [4:0] dbg_dsbf,          // The internal display buffer
    output       dbg_arc_t1,        // T-State
    output       dbg_arc_t4,        // /
    output       dbg_arc_a1,        // Register A
    output       dbg_arc_b1,        // Register B
    output [2:0] dbg_rom_roe,       // 
    output       dbg_ctc_state1,    // 
    output       dbg_ctc_kdn,       // Any Keydown?
    output [5:0] dbg_ctc_q,

    // SRAM WR Port

    // Update Jun 4: The SRAM is causing P&R issues
    // Moving it to the top level

    // Because the top level can't contain circuits
    // The address MUX is implemented here
    input  [2:0]  dbg_sram_cksel,
    input  [7:0]  sraddr_in,
    input  [1:0]  dbg_sram_wrmode,
    output        sram_clk1,
    output [7:0]  sraddr_mux,
    input  [29:0] srdata
);

// Controls
reg  carry_bus;
reg  sync_bus;
wire sync_drive_ctc;
wire carry_drive_arc;

reg phi1;
reg phi2;
// Clock Divider (New Arch)
reg [2:0] xdivr;
reg       xT1r, xT2r, xT3r, xT4r;
reg       phi1r;
reg       phi2r;
always@(posedge osc_in or posedge cdiv_rst) begin
    if(cdiv_rst) begin
        xdivr <= 3'b0;
        xT1r <= 1'b1;
        xT2r <= 1'b0;
        xT3r <= 1'b0;
        xT4r <= 1'b0;
    end else begin
        xdivr <= xdivr + 1'b1;
        if(xdivr == 7) begin
            if(DD[1]&DD[3]) 
                {xT1r, xT2r, xT3r, xT4r} <= 4'b0010;
            else
                {xT1r, xT2r, xT3r, xT4r} <= {xT4r, xT1r, xT2r, xT3r};
        end
        phi1r <= (xdivr == 5);
        phi2r <= (xdivr == 7);
    end
end

assign phi1_out = ~phi1r;
assign phi2_out = ~phi2r;
assign phi_oen  = ~dbg_internal_cdiv;

// Peripheral Bus
wire       bcd_internal_active;
wire       bcd_internal_drive;
reg        bcd_bus;
reg        bcd_oen;

// Address Bus
reg        ia_bus;  // Always driven by CTC, Loaded by the ROMs
wire       ia_internal_drive;

// Instruction Bus
wire [2:0] is_internal_active;  // Driven by ROM, Loaded by ARC / CTC
wire [2:0] is_internal_drive;   // Driven by ROM, Loaded by ARC / CTC
reg        is_bus;
reg        is_oen;

// Word Select Bus
wire [2:0] ws_internal_active;      // Driven by the ROMs, Loaded by ARC
wire [2:0] ws_internal_drive;       // Driven by the ROMs, Loaded by ARC
wire       ws_internal_active_ctc;  // Driven by CTC, Loaded by ARC
wire       ws_internal_drive_ctc;   // Driven by CTC, Loaded by ARC
reg        ws_bus;
reg        ws_oen;

assign sync_oen  = ~dbg_disable_ctc;
assign carry_oen = ~dbg_disable_arc;
assign ia_oen    = ~dbg_disable_ctc;

// SRAM Interface
wire [7:0] sraddr[2:0];
wire [2:0] srprelatch;
reg [7:0]  sraddr_mux;
// reg [31:0] srdata;
wire [29:0] srdata;
reg        sram_clk1;
always @* begin
    case (dbg_sram_wrmode)
        2'b11: sraddr_mux = sraddr_in;
        2'b00: sraddr_mux = sraddr[0]; 
        2'b01: sraddr_mux = sraddr[1]; 
        2'b10: sraddr_mux = sraddr[2]; 
    endcase

    case (dbg_sram_cksel)
        3'b000:  sram_clk1 =  phi2; 
        3'b001:  sram_clk1 = ~phi2; 
        3'b010:  sram_clk1 =  phi1;
        3'b011:  sram_clk1 = ~phi1;
        3'b100:  sram_clk1 = 1'b1;
        3'b101:  sram_clk1 = 1'b0; 
        default: sram_clk1 = 1'bx;
    endcase
end



// Debug Connectors (To be connected to the Caravel LA interface)
wire       dbg_disable_ctc;
wire       dbg_disable_arc;
wire       dbg_disable_rom;
wire [2:0] dbg_rom_roe;
wire       dbg_ctc_state1;
wire [4:0] dbg_dsbf;
wire       dbg_arc_t1;
wire       dbg_arc_t4;
wire       dbg_arc_a1;
wire       dbg_arc_b1;
wire       dbg_arc_dummy;
wire       dbg_ctc_kdn;


// ** A R C
arithmetic_and_register_20_a u_ARC(
    .A(DD[0]),.B(DD[1]),.C(DD[2]),.D(DD[3]),.E(DD[4]),  // -> Display Bus
    .START      (START              ),  // -> Display Control
    .CARRY      (carry_drive_arc    ),  // ARC -> CTC             
    .dbg_dsbf3  (dbg_dsbf[3]        ),  // Internal Display Buffer -> DBG
    .dbg_dsbf2  (dbg_dsbf[2]        ),  // |
    .dbg_dsbf1  (dbg_dsbf[1]        ),  // |
    .dbg_dsbf0  (dbg_dsbf[0]        ),  // |
    .dbg_dsbf_dp(dbg_dsbf[4]        ),  // /
    .dbg_t1     (dbg_arc_t1         ),  // Timing Register -> DBG
    .dbg_t4     (dbg_arc_t4         ),  // Timing Register -> DBG
    .dbg_regA1  (dbg_arc_a1         ),  //      Register A -> DBG
    .dbg_regB1  (dbg_arc_b1         ),  //      Register B -> DBG
    .PHI2       (phi2               ),  // CTC -> Global Clock
    .IS         (is_bus             ),  // CTC/ROM -> ARC
    .WS         (ws_bus             ),  // CTC/ROM -> ARC
    .SYNC       (sync_bus           ),  // CTC -> Global SYNC Signal
    .bcd_in     (bcd_in             ),  // Tristate Bus, ARC <-> RAM
    .bcd_active (bcd_internal_active),  // |
    .bcd_out    (bcd_internal_drive ),  // /
    .dummy      (dbg_arc_dummy      )   // When asserted, preload regA with 60'hHAFEEDFACEBEEF to prevent inferring RAM
);

// ** C T C
control_and_timing_16_a u_CTC(
    .ia_out      (ia_internal_drive     ),  // Address Bus
    .ws_in       (ws_bus                ),  // Word Select Bus
    .ws_out      (ws_internal_drive_ctc ),  // |
    .ws_active   (ws_internal_active_ctc),  // /
    .SYNC        (sync_drive_ctc        ),  // Global SYNC
    .tp_tiny_pin2(dbg_ctc_state1        ),  // Does it enter sIdle when Reset ?
    .dbg_ctc_kdn (dbg_ctc_kdn           ),
    .PHI2        (phi2                  ),  // Global Clock
    .PWO         (PWO                   ),  // Global RST
    .IS          (is_bus                ),  // Instruction bus, Driven by ROMs 
    .CARRY       (carry_bus             ),  // Driven by ARC
    .dbg_q       (dbg_ctc_q             ),  // State Register
    //.ROW0(ROW[0]),.ROW1(ROW[1]),.ROW2(ROW[2]),.ROW3(ROW[3]),.ROW4(ROW[4]),.ROW5(ROW[5]),.ROW6(ROW[6]),.ROW7(ROW[7]),
    .ROW0(),.ROW1(),.ROW2(),.ROW3(),.ROW4(),.ROW5(),.ROW6(),.ROW7(),
    .COL0(COL[0]),.COL2(COL[1]),.COL3(COL[2]),.COL4(COL[3]),.COL6(COL[4])
);

// ** R O M
genvar gi;
generate
    for(gi=0;gi<3;gi=gi+1) begin : gen_ROM_instances
        read_only_memory_18_a #(.RomNum(gi)) u_ROM(
            .is_active(is_internal_active[gi]),
            .is_out   (is_internal_drive [gi]),
            .is_in    (is_bus                ),  // The three Tri-State buses
            .ws_out   (ws_internal_drive[gi] ),
            .ws_active(ws_internal_active[gi]),
            .IA       (ia_bus                ),
            .PHI1(phi1),.PHI2(phi2),.PWO(PWO),.SYNC(sync_bus),
            .TP_ROE   (dbg_rom_roe[gi]       ),
            .sraddr   (sraddr[gi]            ),
            .srprelatch(srprelatch[gi]       ),
            .srdata   ({2'b0,srdata}         ),
            .dbg_force_data(dbg_force_data   ),
            .forcedata(dbg_romdata           )
        );
    end
endgenerate

// The three ROMs should receive the same sraddr
/*
reg [31:0] sram_pdr;
always @(posedge sram_wclk) begin
    sram_pdr <= {sram_pdr[31:1], sram_sdin};
end
*/
// Instantiate SRAM
/*
sky130_sram_1kbyte_1rw1r_32x256_8 u_SRAM(
    .clk0  (sram_clk0    ),
    .addr0 (sram_addr0   ),
    .web0  (sram_web0    ),
    .wmask0(4'b1111      ),
    .addr0 (sram_addr0   ),
    // .din0  (sram_pdr     ),
    .din0  (sram_din0    ),
    .dout0 (             ),
    .clk1  (sram_clk1    ), // Synced to the posedge of PHI2
    .csb1  (dbg_sram_csb1), // Should work when held 1'b0 all the way
    .addr1 (sraddr_mux   ), // 
    .dout1 (srdata       )  // 
);

*/

// Implementation of the buses
// Use MUX instead of Tri-state buffers 
reg ws_mux1;
wire ws_internal_active_rom = |ws_internal_active;
always @* begin
    // Word Select Bus (Can be driven by either the ROMs or the CTC)
    casex ({ws_internal_active})
        3'b1xx:  ws_mux1 = ws_internal_drive[2];
        3'b01x:  ws_mux1 = ws_internal_drive[1];
        3'b001:  ws_mux1 = ws_internal_drive[0];
        default: ws_mux1 = 1'bx;
    endcase

    casex ({~dbg_disable_ctc, ~dbg_disable_rom, ws_internal_active_ctc, ws_internal_active_rom})
        4'b111x: {ws_oen, ws_bus} = {1'b0, ws_internal_drive_ctc};   // CTC is in control
        4'b1101: {ws_oen, ws_bus} = {1'b0, ws_mux1};                 // ROM is in control
        4'b101x: {ws_oen, ws_bus} = {1'b0, ws_internal_drive_ctc};
        4'b0101: {ws_oen, ws_bus} = {1'b0, ws_mux1};
        default: {ws_oen, ws_bus} = {1'b1, ws_in};
    endcase

    // BCD Bus (Peripheral)
    casex ({~dbg_disable_arc, bcd_internal_active})
        2'b0x:   {bcd_oen, bcd_bus} = {1'b1, bcd_in};                // External ARC
        2'b11:   {bcd_oen, bcd_bus} = {1'b0, bcd_internal_drive};    // ARC is in control
        default: {bcd_oen, bcd_bus} = {1'b1, bcd_in};                // Nobody is in control
    endcase

    // Instruction Bus
    casex ({~dbg_disable_rom,is_internal_active})
        4'b0xxx:  {is_oen, is_bus} = {1'b1, is_in               };    // External ROM
        4'b1100:  {is_oen, is_bus} = {1'b0, is_internal_drive[2]};    // ROM 2 in control
        4'b1010:  {is_oen, is_bus} = {1'b0, is_internal_drive[1]};    // ROM 1 in control
        4'b1001:  {is_oen, is_bus} = {1'b0, is_internal_drive[0]};    // ROM 0 in control
        default:  {is_oen, is_bus} = {1'b1, is_in               };    // Essentially nobody is in control
    endcase

    // Single-Drive Signals
    case ({~dbg_disable_ctc})
        1'b1:    {sync_bus, ia_bus} = {sync_drive_ctc, ia_internal_drive};
        default: {sync_bus, ia_bus} = {sync_in,        ia_in};
    endcase

    case ({~dbg_disable_arc})
        1'b1:     carry_bus = carry_drive_arc;
        default:  carry_bus = carry_in;
    endcase
    
    case ({dbg_internal_cdiv})
        1'b1:     {phi1, phi2} = {phi1_out, phi2_out};
        default:  {phi1, phi2} = {phi1_in,  phi2_in };
    endcase
    
end



endmodule /* hp35_core */