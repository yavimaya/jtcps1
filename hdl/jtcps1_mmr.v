/*  This file is part of JTCPS1.
    JTCPS1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCPS1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCPS1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2020 */
    
`timescale 1ns/1ps

// Scroll 1 is 512x512, 8x8 tiles
// Scroll 2 is 1024x1024 16x16 tiles
// Scroll 3 is 2048x2048 32x32 tiles

module jtcps1_mmr(
    input              rst,
    input              clk,

    input              ppu_rstn,
    input              ppu1_cs,
    input              ppu2_cs,

    input   [ 5:1]     addr,
    input   [ 1:0]     dsn,      // data select, active low
    input   [15:0]     cpu_dout,
    output  [15:0]     mmr_dout,
    // registers
    output reg [15:0]  ppu_ctrl,
    // Scroll
    output reg [15:0]  hpos1,
    output reg [15:0]  hpos2,
    output reg [15:0]  hpos3,
    output reg [15:0]  vpos1,
    output reg [15:0]  vpos2,
    output reg [15:0]  vpos3,

    output reg [15:0]  hstar1,
    output reg [15:0]  hstar2,

    output reg [15:0]  vstar1,
    output reg [15:0]  vstar2,

    // VRAM position
    output reg [15:0]  vram1_base,
    output reg [15:0]  vram2_base,
    output reg [15:0]  vram3_base,
    output reg [15:0]  vram_obj_base,
    output reg [15:0]  vram_row_base,
    output reg [15:0]  vram_star_base,
    output reg [15:0]  pal_base,

    // CPS-B Registers
    input      [ 5:1]  addr_layer,
    input      [ 5:1]  addr_prio0,
    input      [ 5:1]  addr_prio1,
    input      [ 5:1]  addr_prio2,
    input      [ 5:1]  addr_prio3,
    input      [ 5:1]  addr_pal_page,

    output reg [15:0]  layer_ctrl,
    output reg [15:0]  prio0,
    output reg [15:0]  prio1,
    output reg [15:0]  prio2,
    output reg [15:0]  prio3,
    output reg [ 5:0]  pal_page_en // which palette pages to copy
);

assign mmr_dout = 16'd0;

function [15:0] data_sel;
    input [15:0] olddata;
    input [15:0] newdata;
    input [ 1:0] ds;
    data_sel = { dsn[1] ? olddata[15:8] : newdata[15:8], dsn[0] ? olddata[7:0] : newdata[7:0] };
endfunction

wire reg_rst;

// For quick simulation of the video alone
// it is possible to load the regs from a file
// defined by the macro MMR_FILE

`ifndef SIMULATION
`undef MMR_FILE
`endif

`ifdef MMR_FILE
reg [15:0] mmr_regs[0:10];
initial begin
    $display("INFO: MMR initial values read from %s", `MMR_FILE );
    $readmemh(`MMR_FILE,mmr_regs);
    vram_obj_base  = mmr_regs[0];
    vram1_base     = mmr_regs[1];
    vram2_base     = mmr_regs[2];
    vram3_base     = mmr_regs[3];
    pal_base       = mmr_regs[4];
    hpos1          = mmr_regs[5];
    vpos1          = mmr_regs[6];
    hpos2          = mmr_regs[7];
    vpos2          = mmr_regs[8];
    hpos3          = mmr_regs[9];
    vpos3          = mmr_regs[10];
end
assign reg_rst = 1'b0;
`else 
assign reg_rst = rst | ~ppu_rstn;
`endif

always @(posedge clk, posedge reg_rst) begin
    if( reg_rst ) begin
        hpos1         <= 16'd0;
        hpos2         <= 16'd0;
        hpos3         <= 16'd0;
        vpos1         <= 16'd0;
        vpos2         <= 16'd0;
        vpos3         <= 16'd0;
        vram1_base    <= 16'd0;
        vram2_base    <= 16'd0;
        vram3_base    <= 16'd0;
        vram_obj_base <= 16'd0;
        pal_base      <= 16'd0;
        pal_page_en   <= 6'h3f;

        prio0         <= ~16'h0;
        prio1         <= ~16'h0;
        prio2         <= ~16'h0;
        prio3         <= ~16'h0;
        pal_page_en   <=  6'h3f;
        layer_ctrl    <=  16'd0;
    end else begin
        if( ppu1_cs ) begin
            case( addr[5:1] )
                // CPS-A registers
                5'h00: vram_obj_base <= data_sel(vram_obj_base , cpu_dout, dsn);
                5'h01: vram1_base    <= data_sel(vram1_base    , cpu_dout, dsn);
                5'h02: vram2_base    <= data_sel(vram2_base    , cpu_dout, dsn);
                5'h03: vram3_base    <= data_sel(vram3_base    , cpu_dout, dsn);
                5'h04: vram_row_base <= data_sel(vram_row_base , cpu_dout, dsn);
                5'h05: pal_base      <= data_sel(pal_base      , cpu_dout, dsn);
                5'h06: hpos1         <= data_sel(hpos1         , cpu_dout, dsn);
                5'h07: vpos1         <= data_sel(vpos1         , cpu_dout, dsn);
                5'h08: hpos2         <= data_sel(hpos2         , cpu_dout, dsn);
                5'h09: vpos2         <= data_sel(vpos2         , cpu_dout, dsn);
                5'h0a: hpos3         <= data_sel(hpos3         , cpu_dout, dsn);
                5'h0b: vpos3         <= data_sel(vpos3         , cpu_dout, dsn);
                5'h0c: hstar1        <= data_sel(hstar1        , cpu_dout, dsn);
                5'h0d: vstar1        <= data_sel(vstar1        , cpu_dout, dsn);
                5'h0e: hstar2        <= data_sel(hstar2        , cpu_dout, dsn);
                5'h0f: vstar2        <= data_sel(vstar2        , cpu_dout, dsn);
                5'h10: vram_star_base<= data_sel(vram_star_base, cpu_dout, dsn);
                5'h11: ppu_ctrl      <= data_sel(ppu_ctrl      , cpu_dout, dsn);
            endcase
        end
        if( ppu2_cs ) begin
            if( addr == addr_layer    ) layer_ctrl <= data_sel(layer_ctrl, cpu_dout, dsn);
            if( addr == addr_prio0    ) prio0      <= data_sel(prio0,      cpu_dout, dsn);
            if( addr == addr_prio1    ) prio1      <= data_sel(prio1,      cpu_dout, dsn);
            if( addr == addr_prio2    ) prio2      <= data_sel(prio2,      cpu_dout, dsn);
            if( addr == addr_prio3    ) prio3      <= data_sel(prio3,      cpu_dout, dsn);
            if( addr == addr_pal_page ) pal_page_en<= data_sel(pal_page_en,cpu_dout, dsn);
        end
    end
end


endmodule
