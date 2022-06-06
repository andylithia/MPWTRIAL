// SPDX-FileCopyrightText: 2020 Efabless Corporation
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
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_project_wrapper
 *
 * This wrapper enumerates all of the pins available to the
 * user for the user project.
 *
 * An example user project is provided in this wrapper.  The
 * example should be removed and replaced with the actual
 * user project.
 *
 *-------------------------------------------------------------
 */

module user_project_wrapper #(
    parameter BITS = 32
) (
`ifdef USE_POWER_PINS
    inout vdda1,	// User area 1 3.3V supply
    inout vdda2,	// User area 2 3.3V supply
    inout vssa1,	// User area 1 analog ground
    inout vssa2,	// User area 2 analog ground
    inout vccd1,	// User area 1 1.8V supply
    inout vccd2,	// User area 2 1.8v supply
    inout vssd1,	// User area 1 digital ground
    inout vssd2,	// User area 2 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    `define MPRJ_IO_PADS 38
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // Analog (direct connection to GPIO pad---use with caution)
    // Note that analog I/O is not available on the 7 lowest-numbered
    // GPIO pads, and so the analog_io indexing is offset from the
    // GPIO indexing by 7 (also upper 2 GPIOs do not have analog_io).
    inout [`MPRJ_IO_PADS-10:0] analog_io,

    // Independent clock (on independent integer divider)
    input   user_clock2,

    // User maskable interrupt signals
    output [2:0] user_irq
);

/*--------------------------------------*/
/* User project is instantiated  here   */
/*--------------------------------------*/
wire        dbg_detach_in;
wire [4:0]  col_in;
wire        cdiv_rst_in;
wire        dbg_internal_cdiv_in;
wire        external_clock_in;
reg         osc_in;
wire        phi1_in;
wire        phi2_in;
wire        phi1_out;
wire        phi2_out;
wire        phi_oe;
wire        pwo_in;
wire [4:0]  dd_out;
wire        start_out;
wire        is_in;
wire        is_bus;
wire        is_oe;
wire        ws_in;
wire        ws_bus;
wire        ws_oe;
wire        bcd_in;
wire        bcd_bus;
wire        bcd_oe;
wire        ia_in;
wire        ia_bus;
wire        ia_oe;
wire        carry_in;
wire        carry_bus;
wire        carry_oe;
wire        sync_in;
wire        sync_bus;
wire        sync_oe;

// Clock Divider Select
wire [2:0]  dbg_cksel_in;
reg  [5:0]  clkdiv_r;
always @(posedge wb_clk_i) begin
    if(wb_rst_i) clkdiv_r <= 1'b0;
    else         clkdiv_r <= clkdiv_r + 1'b1;
end

always @* begin
    case (dbg_cksel_in)
        3'b000:  osc_in = external_clock_in;
        3'b001:  osc_in = wb_clk_i;
        3'b010:  osc_in = clkdiv_r[0];
        3'b011:  osc_in = clkdiv_r[1];
        3'b100:  osc_in = clkdiv_r[2];
        3'b101:  osc_in = clkdiv_r[3];
        3'b110:  osc_in = clkdiv_r[4];
        3'b111:  osc_in = clkdiv_r[5];
    endcase
end

wire        dbg_enable_arc_in;
wire        dbg_enable_ctc_in;
wire        dbg_enable_rom_in;
wire        dbg_arc_dummy_in;
wire        dbg_force_data_in;
wire [9:0]  dbg_romdata_in;
wire        dbg_sram_csb1_in;
wire [4:0]  dbg_dsbf_out;
wire        dbg_arc_t1_out;
wire        dbg_arc_t4_out;
wire        dbg_arc_a1_out;
wire        dbg_arc_b1_out;
wire [2:0]  dbg_rom_roe_out;
wire        dbg_ctc_state1_out;
wire        dbg_ctc_kdn_out;
wire [5:0]  dbg_ctc_q_out;

// wire        dbg_busin_xor;  //
// wire        dgb_busout_xor; //
wire        dbg_oe_xor; // If I'm correct, the oeb signal is oe inverted
                        // To avoid any error, the LA is able to invert all the oe bits
                        // BTW, after reset, all the LA outputs are 0s.
wire        sram_clk0;
wire        sram_csb0;
wire        sram_web0;
wire [7:0]  sram_addr0;
wire [29:0] sram_din0;

wire        sram_clk1;
wire        dbg_sram_csb1;
wire [7:0]  sraddr_mux;
wire [31:0] srdata;

// Assigning MPRJ_IO Ports
assign io_out[31:29] = dbg_ctc_q_out[5:3];
assign io_oeb[31:29] = {3{dbg_oe_xor}} ^ (~3'b111);     // All out 
assign col_in[4:0]   = io_in[28:24];
assign io_oeb[28:24] = {5{dbg_oe_xor}} ^ (~5'b00000);   // All input
assign io_out[23:19] = dd_out;
assign io_oeb[23:19] = {5{dbg_oe_xor}} ^ (~5'b11111);   // All output
assign io_out[18]    = start_out;
assign io_oeb[18]    = {1{dbg_oe_xor}} ^ (~1'b1);       // All output
assign io_out[16]    = phi2_out;
assign phi2_in       = io_in[16];
assign io_out[15]    = phi1_out;
assign phi1_in       = io_in[15];
assign io_oeb[16:15] = {2{dbg_oe_xor}} ^ ~{2{phi_oe}};
assign io_out[14]    = is_bus;
assign is_in         = io_in[14];
assign io_oeb[14]    = {1{dbg_oe_xor}} ^ ~is_oe;
assign io_out[13]    = ws_bus;
assign ws_in         = io_in[13];
assign io_oeb[13]    = {1{dbg_oe_xor}} ^ ~ws_oe;
assign io_out[12]    = bcd_bus;
assign bcd_in        = io_in[12];
assign io_oeb[12]    = {1{dbg_oe_xor}} ^ ~bcd_oe;
assign io_out[11]    = ia_bus;
assign ia_in         = io_in[11];
assign io_oeb[11]    = {1{dbg_oe_xor}} ^ ~ia_oe;
assign io_out[10]    = carry_bus;
assign carry_in      = io_in[10];
assign io_oeb[10]    = {1{dbg_oe_xor}} ^ ~carry_oe;
assign io_out[ 9]    = sync_bus;
assign sync_in       = io_in[ 9];
assign io_oeb[ 9]    = {1{dbg_oe_xor}} ^ ~sync_oe;
assign external_clock_in = io_in[8];
assign io_oeb[ 8]    = {1{dbg_oe_xor}} ^ ~1'b0;

// Assigning LA Ports
// assign la_data_out[63:0] = TDC_dout;
assign la_data_out[64]      = pwo_in;
assign la_data_out[65]      = is_bus;
assign la_data_out[66]      = ws_bus;
assign la_data_out[67]      = bcd_bus;
assign la_data_out[68]      = ia_bus;
assign la_data_out[69]      = carry_bus;
assign la_data_out[70]      = sync_bus;
assign la_data_out[74:71]   = dbg_dsbf_out;
assign la_data_out[75]      = dbg_arc_t1_out;
assign la_data_out[76]      = dbg_arc_t4_out;
assign la_data_out[77]      = dbg_arc_a1_out;
assign la_data_out[78]      = dbg_arc_b1_out;
assign la_data_out[81:79]   = dbg_rom_roe_out;
assign la_data_out[82]      = dbg_ctc_state1_out;
assign la_data_out[83]      = dbg_ctc_kdn_out;
assign la_data_out[89:84]   = dbg_ctc_q_out;
assign la_data_out[91:90]   = {phi1_out, phi2_out};
assign la_data_out[92]      = sram_clk1;
assign la_data_out[100:93]  = sraddr_mux;

assign sram_din0             = la_data_in[29:0];
assign sram_web0             = la_data_in[30];
assign sram_csb0             = la_data_in[31];
assign sram_clk0             = la_data_in[32];
assign sram_addr0            = la_data_in[40:33];
assign dbg_sram_csb1_in      = la_data_in[41];
assign dbg_enable_arc_in     = la_data_in[42];
assign dbg_enable_ctc_in     = la_data_in[43];
assign dbg_enable_rom_in     = la_data_in[44];
assign dbg_arc_dummy_in      = la_data_in[45];
assign dbg_force_data_in     = la_data_in[46];
assign dbg_romdata_in        = la_data_in[56:47];
assign dbg_oe_xor            = la_data_in[57];
assign cdiv_rst_in           = la_data_in[58];
assign dbg_internal_cdiv_in  = la_data_in[59];




sky130_sram_1kbyte_1rw1r_32x256_8 u_SRAM(
`ifdef USE_POWER_PINS
	.vccd1(vccd1),	// User area 1 1.8V power
	.vssd1(vssd1),	// User area 1 digital ground
`endif
    .clk0  (sram_clk0       ),
    .addr0 (sram_addr0      ),
    .web0  (sram_web0       ),
    .wmask0(4'b1111         ),
    .csb0  (sram_csb0       ),
    .din0  ({2'b0,sram_din0}),
    .dout0 (                ),
    .clk1  (sram_clk1       ), // Synced to the posedge of PHI2
    .csb1  (dbg_sram_csb1   ), // Should work when held 1'b0 all the way
    .addr1 (sraddr_mux      ), // 
    .dout1 (srdata          )  // 
);

hp35_core u_hp35_core (
`ifdef USE_POWER_PINS
	.vccd1(vccd1),	// User area 1 1.8V power
	.vssd1(vssd1),	// User area 1 digital ground
`endif
    .COL               (col_in               ),
    .cdiv_rst          (cdiv_rst_in          ),
    .dbg_internal_cdiv (dbg_internal_cdiv_in ),
    .osc_in            (osc_in               ),
    .phi1_in           (phi1_in              ),
    .phi2_in           (phi2_in              ),
    .phi1_out          (phi1_out             ),
    .phi2_out          (phi2_out             ),
    .PWO               (pwo_in               ),
    .DD                (dd_out               ),
    .START             (start_out            ),
    .is_in             (is_in                ),
    .is_bus            (is_bus               ),
    .is_oe             (is_oe                ),
    .ws_in             (ws_in                ),
    .ws_bus            (ws_bus               ),
    .ws_oe             (ws_oe                ),
    .bcd_in            (bcd_in               ),
    .bcd_bus           (bcd_bus              ),
    .bcd_oe            (bcd_oe               ),
    .ia_in             (ia_in                ),
    .ia_bus            (ia_bus               ),
    .carry_bus         (carry_bus            ),
    .carry_in          (carry_in             ),
    .sync_bus          (sync_bus             ),
    .sync_in           (sync_in              ),
    .dbg_enable_arc    (dbg_enable_arc_in    ),
    .dbg_enable_ctc    (dbg_enable_ctc_in    ),
    .dbg_enable_rom    (dbg_enable_rom_in    ),
    .dbg_arc_dummy     (dbg_arc_dummy_in     ),
    .dbg_force_data    (dbg_force_data_in    ),
    .dbg_romdata       (dbg_romdata_in       ),
    .dbg_sram_csb1     (dbg_sram_csb1_in     ),
    .dbg_dsbf          (dbg_dsbf_out         ),
    .dbg_arc_t1        (dbg_arc_t1_out       ),
    .dbg_arc_t4        (dbg_arc_t4_out       ),
    .dbg_arc_a1        (dbg_arc_a1_out       ),
    .dbg_arc_b1        (dbg_arc_b1_out       ),
    .dbg_rom_roe       (dbg_rom_roe_out      ),
    .dbg_ctc_state1    (dbg_ctc_state1_out   ),
    .dbg_ctc_kdn       (dbg_ctc_kdn_out      ),
    .dbg_ctc_q         (dbg_ctc_q_out        ),
    .sram_clk1         (sram_clk1            ),
    .sraddr_mux        (sraddr_mux           ),
    .srdata            (srdata[29:0]         )
);


/*
user_proj_example mprj (
`ifdef USE_POWER_PINS
	.vccd1(vccd1),	// User area 1 1.8V power
	.vssd1(vssd1),	// User area 1 digital ground
`endif

    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),

    // MGMT SoC Wishbone Slave

    .wbs_cyc_i(wbs_cyc_i),
    .wbs_stb_i(wbs_stb_i),
    .wbs_we_i(wbs_we_i),
    .wbs_sel_i(wbs_sel_i),
    .wbs_adr_i(wbs_adr_i),
    .wbs_dat_i(wbs_dat_i),
    .wbs_ack_o(wbs_ack_o),
    .wbs_dat_o(wbs_dat_o),

    // Logic Analyzer

    .la_data_in(la_data_in),
    .la_data_out(la_data_out),
    .la_oenb (la_oenb),

    // IO Pads

    .io_in (io_in),
    .io_out(io_out),
    .io_oeb(io_oeb),

    // IRQ
    .irq(user_irq)
);

*/
endmodule	// user_project_wrapper
`default_nettype wire
