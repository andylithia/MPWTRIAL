module user_project_wrapper (user_clock2,
    vccd1,
    vccd2,
    vdda1,
    vdda2,
    vssa1,
    vssa2,
    vssd1,
    vssd2,
    wb_clk_i,
    wb_rst_i,
    wbs_ack_o,
    wbs_cyc_i,
    wbs_stb_i,
    wbs_we_i,
    analog_io,
    io_in,
    io_oeb,
    io_out,
    la_data_in,
    la_data_out,
    la_oenb,
    user_irq,
    wbs_adr_i,
    wbs_dat_i,
    wbs_dat_o,
    wbs_sel_i);
 input user_clock2;
 input vccd1;
 input vccd2;
 input vdda1;
 input vdda2;
 input vssa1;
 input vssa2;
 input vssd1;
 input vssd2;
 input wb_clk_i;
 input wb_rst_i;
 output wbs_ack_o;
 input wbs_cyc_i;
 input wbs_stb_i;
 input wbs_we_i;
 inout [28:0] analog_io;
 input [37:0] io_in;
 output [37:0] io_oeb;
 output [37:0] io_out;
 input [127:0] la_data_in;
 output [127:0] la_data_out;
 input [127:0] la_oenb;
 output [2:0] user_irq;
 input [31:0] wbs_adr_i;
 input [31:0] wbs_dat_i;
 output [31:0] wbs_dat_o;
 input [3:0] wbs_sel_i;

 wire one_;
 wire carry_oen;
 wire ia_oen;
 wire bcd_oen;
 wire ws_oen;
 wire is_oen;
 wire phi_oen;
 wire zero_;
 wire sync_oen;
 wire carry_bus;
 wire ia_bus;
 wire bcd_bus;
 wire ws_bus;
 wire is_bus;
 wire phi1_out;
 wire phi2_out;
 wire start_out;
 wire sync_bus;
 wire dbg_arc_t1_out;
 wire dbg_arc_t4_out;
 wire dbg_arc_a1_out;
 wire dbg_arc_b1_out;
 wire dbg_ctc_state1_out;
 wire dbg_ctc_kdn_out;
 wire sram_clk1;
 wire \dbg_dsbf_out[4] ;

 hp35_core u_hp35_core (.PWO(io_in[17]),
    .START(start_out),
    .bcd_bus(bcd_bus),
    .bcd_in(io_in[12]),
    .bcd_oen(bcd_oen),
    .carry_bus(carry_bus),
    .carry_in(io_in[10]),
    .carry_oen(carry_oen),
    .cdiv_rst(la_data_in[58]),
    .dbg_arc_a1(dbg_arc_a1_out),
    .dbg_arc_b1(dbg_arc_b1_out),
    .dbg_arc_dummy(la_data_in[45]),
    .dbg_arc_t1(dbg_arc_t1_out),
    .dbg_arc_t4(dbg_arc_t4_out),
    .dbg_ctc_kdn(dbg_ctc_kdn_out),
    .dbg_ctc_state1(dbg_ctc_state1_out),
    .dbg_disable_arc(la_data_in[42]),
    .dbg_disable_ctc(la_data_in[43]),
    .dbg_disable_rom(la_data_in[44]),
    .dbg_force_data(la_data_in[46]),
    .dbg_internal_cdiv(la_data_in[59]),
    .dbg_sram_csb1(la_data_in[41]),
    .ia_bus(ia_bus),
    .ia_in(io_in[11]),
    .ia_oen(ia_oen),
    .is_bus(is_bus),
    .is_in(io_in[14]),
    .is_oen(is_oen),
    .osc_in(wb_clk_i),
    .phi1_in(io_in[15]),
    .phi1_out(phi1_out),
    .phi2_in(io_in[16]),
    .phi2_out(phi2_out),
    .phi_oen(phi_oen),
    .sram_clk1(sram_clk1),
    .sync_bus(sync_bus),
    .sync_in(io_in[9]),
    .sync_oen(sync_oen),
    .vccd1(vccd1),
    .vssd1(vssd1),
    .ws_bus(ws_bus),
    .ws_in(io_in[13]),
    .ws_oen(ws_oen),
    .COL({io_in[28],
    io_in[27],
    io_in[26],
    io_in[25],
    io_in[24]}),
    .DD({io_out[23],
    io_out[22],
    io_out[21],
    io_out[20],
    io_out[19]}),
    .dbg_ctc_q({io_out[31],
    io_out[30],
    io_out[29],
    la_data_out[86],
    la_data_out[85],
    la_data_out[84]}),
    .dbg_dsbf({\dbg_dsbf_out[4] ,
    la_data_out[74],
    la_data_out[73],
    la_data_out[72],
    la_data_out[71]}),
    .dbg_rom_roe({la_data_out[81],
    la_data_out[80],
    la_data_out[79]}),
    .dbg_romdata({la_data_in[56],
    la_data_in[55],
    la_data_in[54],
    la_data_in[53],
    la_data_in[52],
    la_data_in[51],
    la_data_in[50],
    la_data_in[49],
    la_data_in[48],
    la_data_in[47]}),
    .dbg_sram_cksel({la_data_in[70],
    la_data_in[69],
    la_data_in[68]}),
    .dbg_sram_wrmode({la_data_in[72],
    la_data_in[71]}),
    .sraddr_in({la_data_in[40],
    la_data_in[39],
    la_data_in[38],
    la_data_in[37],
    la_data_in[36],
    la_data_in[35],
    la_data_in[34],
    la_data_in[33]}),
    .sraddr_mux({la_data_out[100],
    la_data_out[99],
    la_data_out[98],
    la_data_out[97],
    la_data_out[96],
    la_data_out[95],
    la_data_out[94],
    la_data_out[93]}),
    .srdata({la_data_in[29],
    la_data_in[28],
    la_data_in[27],
    la_data_in[26],
    la_data_in[25],
    la_data_in[24],
    la_data_in[23],
    la_data_in[22],
    la_data_in[21],
    la_data_in[20],
    la_data_in[19],
    la_data_in[18],
    la_data_in[17],
    la_data_in[16],
    la_data_in[15],
    la_data_in[14],
    la_data_in[13],
    la_data_in[12],
    la_data_in[11],
    la_data_in[10],
    la_data_in[9],
    la_data_in[8],
    la_data_in[7],
    la_data_in[6],
    la_data_in[5],
    la_data_in[4],
    la_data_in[3],
    la_data_in[2],
    la_data_in[1],
    la_data_in[0]}));
 assign io_oeb[0] = one_;
 assign io_oeb[10] = carry_oen;
 assign io_oeb[11] = ia_oen;
 assign io_oeb[12] = bcd_oen;
 assign io_oeb[13] = ws_oen;
 assign io_oeb[14] = is_oen;
 assign io_oeb[15] = phi_oen;
 assign io_oeb[16] = phi_oen;
 assign io_oeb[17] = one_;
 assign io_oeb[18] = zero_;
 assign io_oeb[19] = zero_;
 assign io_oeb[1] = one_;
 assign io_oeb[20] = zero_;
 assign io_oeb[21] = zero_;
 assign io_oeb[22] = zero_;
 assign io_oeb[23] = zero_;
 assign io_oeb[24] = one_;
 assign io_oeb[25] = one_;
 assign io_oeb[26] = one_;
 assign io_oeb[27] = one_;
 assign io_oeb[28] = one_;
 assign io_oeb[29] = zero_;
 assign io_oeb[2] = one_;
 assign io_oeb[30] = zero_;
 assign io_oeb[31] = zero_;
 assign io_oeb[32] = one_;
 assign io_oeb[33] = one_;
 assign io_oeb[34] = one_;
 assign io_oeb[35] = one_;
 assign io_oeb[36] = one_;
 assign io_oeb[37] = one_;
 assign io_oeb[3] = one_;
 assign io_oeb[4] = one_;
 assign io_oeb[5] = one_;
 assign io_oeb[6] = one_;
 assign io_oeb[7] = one_;
 assign io_oeb[8] = one_;
 assign io_oeb[9] = sync_oen;
 assign io_out[0] = zero_;
 assign io_out[10] = carry_bus;
 assign io_out[11] = ia_bus;
 assign io_out[12] = bcd_bus;
 assign io_out[13] = ws_bus;
 assign io_out[14] = is_bus;
 assign io_out[15] = phi1_out;
 assign io_out[16] = phi2_out;
 assign io_out[17] = zero_;
 assign io_out[18] = start_out;
 assign io_out[1] = zero_;
 assign io_out[24] = zero_;
 assign io_out[25] = zero_;
 assign io_out[26] = zero_;
 assign io_out[27] = zero_;
 assign io_out[28] = zero_;
 assign io_out[2] = zero_;
 assign io_out[32] = zero_;
 assign io_out[33] = zero_;
 assign io_out[34] = zero_;
 assign io_out[35] = zero_;
 assign io_out[36] = zero_;
 assign io_out[37] = zero_;
 assign io_out[3] = zero_;
 assign io_out[4] = zero_;
 assign io_out[5] = zero_;
 assign io_out[6] = zero_;
 assign io_out[7] = zero_;
 assign io_out[8] = zero_;
 assign io_out[9] = sync_bus;
 assign la_data_out[0] = zero_;
 assign la_data_out[101] = zero_;
 assign la_data_out[102] = zero_;
 assign la_data_out[103] = zero_;
 assign la_data_out[104] = zero_;
 assign la_data_out[105] = zero_;
 assign la_data_out[106] = zero_;
 assign la_data_out[107] = zero_;
 assign la_data_out[108] = zero_;
 assign la_data_out[109] = zero_;
 assign la_data_out[10] = zero_;
 assign la_data_out[110] = zero_;
 assign la_data_out[111] = zero_;
 assign la_data_out[112] = zero_;
 assign la_data_out[113] = zero_;
 assign la_data_out[114] = zero_;
 assign la_data_out[115] = zero_;
 assign la_data_out[116] = zero_;
 assign la_data_out[117] = zero_;
 assign la_data_out[118] = zero_;
 assign la_data_out[119] = zero_;
 assign la_data_out[11] = zero_;
 assign la_data_out[120] = zero_;
 assign la_data_out[121] = zero_;
 assign la_data_out[122] = zero_;
 assign la_data_out[123] = zero_;
 assign la_data_out[124] = zero_;
 assign la_data_out[125] = zero_;
 assign la_data_out[126] = zero_;
 assign la_data_out[127] = zero_;
 assign la_data_out[12] = zero_;
 assign la_data_out[13] = zero_;
 assign la_data_out[14] = zero_;
 assign la_data_out[15] = zero_;
 assign la_data_out[16] = zero_;
 assign la_data_out[17] = zero_;
 assign la_data_out[18] = zero_;
 assign la_data_out[19] = zero_;
 assign la_data_out[1] = zero_;
 assign la_data_out[20] = zero_;
 assign la_data_out[21] = zero_;
 assign la_data_out[22] = zero_;
 assign la_data_out[23] = zero_;
 assign la_data_out[24] = zero_;
 assign la_data_out[25] = zero_;
 assign la_data_out[26] = zero_;
 assign la_data_out[27] = zero_;
 assign la_data_out[28] = zero_;
 assign la_data_out[29] = zero_;
 assign la_data_out[2] = zero_;
 assign la_data_out[30] = zero_;
 assign la_data_out[31] = zero_;
 assign la_data_out[32] = zero_;
 assign la_data_out[33] = zero_;
 assign la_data_out[34] = zero_;
 assign la_data_out[35] = zero_;
 assign la_data_out[36] = zero_;
 assign la_data_out[37] = zero_;
 assign la_data_out[38] = zero_;
 assign la_data_out[39] = zero_;
 assign la_data_out[3] = zero_;
 assign la_data_out[40] = zero_;
 assign la_data_out[41] = zero_;
 assign la_data_out[42] = zero_;
 assign la_data_out[43] = zero_;
 assign la_data_out[44] = zero_;
 assign la_data_out[45] = zero_;
 assign la_data_out[46] = zero_;
 assign la_data_out[47] = zero_;
 assign la_data_out[48] = zero_;
 assign la_data_out[49] = zero_;
 assign la_data_out[4] = zero_;
 assign la_data_out[50] = zero_;
 assign la_data_out[51] = zero_;
 assign la_data_out[52] = zero_;
 assign la_data_out[53] = zero_;
 assign la_data_out[54] = zero_;
 assign la_data_out[55] = zero_;
 assign la_data_out[56] = zero_;
 assign la_data_out[57] = zero_;
 assign la_data_out[58] = zero_;
 assign la_data_out[59] = zero_;
 assign la_data_out[5] = zero_;
 assign la_data_out[60] = zero_;
 assign la_data_out[61] = zero_;
 assign la_data_out[62] = zero_;
 assign la_data_out[63] = zero_;
 assign la_data_out[6] = zero_;
 assign la_data_out[75] = dbg_arc_t1_out;
 assign la_data_out[76] = dbg_arc_t4_out;
 assign la_data_out[77] = dbg_arc_a1_out;
 assign la_data_out[78] = dbg_arc_b1_out;
 assign la_data_out[7] = zero_;
 assign la_data_out[82] = dbg_ctc_state1_out;
 assign la_data_out[83] = dbg_ctc_kdn_out;
 assign la_data_out[8] = zero_;
 assign la_data_out[9] = zero_;
 assign user_irq[0] = sram_clk1;
 assign user_irq[1] = zero_;
 assign user_irq[2] = zero_;
 assign wbs_ack_o = la_data_in[127];
 assign wbs_dat_o[0] = zero_;
 assign wbs_dat_o[10] = zero_;
 assign wbs_dat_o[11] = zero_;
 assign wbs_dat_o[12] = zero_;
 assign wbs_dat_o[13] = zero_;
 assign wbs_dat_o[14] = zero_;
 assign wbs_dat_o[15] = zero_;
 assign wbs_dat_o[16] = zero_;
 assign wbs_dat_o[17] = zero_;
 assign wbs_dat_o[18] = zero_;
 assign wbs_dat_o[19] = zero_;
 assign wbs_dat_o[1] = zero_;
 assign wbs_dat_o[20] = zero_;
 assign wbs_dat_o[21] = zero_;
 assign wbs_dat_o[22] = zero_;
 assign wbs_dat_o[23] = zero_;
 assign wbs_dat_o[24] = zero_;
 assign wbs_dat_o[25] = zero_;
 assign wbs_dat_o[26] = zero_;
 assign wbs_dat_o[27] = zero_;
 assign wbs_dat_o[28] = zero_;
 assign wbs_dat_o[29] = zero_;
 assign wbs_dat_o[2] = zero_;
 assign wbs_dat_o[30] = zero_;
 assign wbs_dat_o[31] = zero_;
 assign wbs_dat_o[3] = zero_;
 assign wbs_dat_o[4] = zero_;
 assign wbs_dat_o[5] = zero_;
 assign wbs_dat_o[6] = zero_;
 assign wbs_dat_o[7] = zero_;
 assign wbs_dat_o[8] = zero_;
 assign wbs_dat_o[9] = zero_;
endmodule
