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

module jtcps1_video(
    input              rst,
    input              clk,
    input              pxl_cen,        // pixel clock enable

    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    output     [ 8:0]  hdump,
    input      [ 3:0]  gfx_en,

    // CPU interface
    input              ppu_rstn,
    input              ppu1_cs,
    input              ppu2_cs,
    input   [ 5:1]     addr,
    input   [ 1:0]     dsn,      // data select, active low
    input   [15:0]     cpu_dout,
    output  [15:0]     mmr_dout,

    // CPS-B Registers
    input              cfg_we,
    input      [ 7:0]  cfg_data,

    // Extra inputs read through the C-Board
    input   [ 3:0]  start_button,
    input   [ 3:0]  coin_input,
    input   [ 7:0]  joystick3,
    input   [ 7:0]  joystick4,

    // Video RAM interface
    output     [17:1]  vram1_addr,
    input      [15:0]  vram1_data,
    input              vram1_ok,
    output             vram1_cs,

    output     [17:1]  vram_obj_addr,
    input      [15:0]  vram_obj_data,
    input              vram_obj_ok,
    output             vram_obj_cs,

    output     [17:1]  vpal_addr,
    input      [15:0]  vpal_data,
    input              vpal_ok,
    output             vpal_cs,

    // Video signal
    output             HS,
    output             VS,
    output             HB,
    output             VB,
    output             LHBL_dly,
    output             LVBL_dly,
    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,

    // GFX ROM interface
    output     [19:0]  rom1_addr,
    output     [ 3:0]  rom1_bank,
    output             rom1_half,    // selects which half to read
    input      [31:0]  rom1_data,
    output             rom1_cs,
    input              rom1_ok,

    output     [19:0]  rom0_addr,
    output     [ 3:0]  rom0_bank,
    output             rom0_half,    // selects which half to read
    input      [31:0]  rom0_data,
    output             rom0_cs,
    input              rom0_ok
    // To frame buffer
    // output     [11:0]  line_data,
    // output     [ 8:0]  line_addr,
    // output             line_wr,
    // input              line_wr_ok
);

parameter REGSIZE=1; // defined at top level

// use for CPU only simulations:
`ifdef NOVIDEO
`define NOSCROLL
`define NOOBJ
`define NOCOLMIX
`endif

wire [10:0]     scr1_pxl, scr2_pxl, scr3_pxl;
wire [ 8:0]     obj_pxl;
wire [ 8:0]     vrender1;
wire [15:0]     ppu_ctrl;
wire            line_start, preVB;

// Register configuration
// Scroll
wire       [15:0]  hpos1, hpos2, hpos3, vpos1, vpos2, vpos3, hstar1, hstar2, vstar1, vstar2;
// VRAM position
wire       [15:0]  vram1_base, vram2_base, vram3_base, vram_obj_base, vram_row_base, row_offset;
// Layer priority
wire       [15:0]  layer_ctrl, prio0, prio1, prio2, prio3;
wire       [ 7:0]  layer_mask0, layer_mask1, layer_mask2, layer_mask3, layer_mask4;
// palette control
wire       [15:0]  pal_base;
wire               pal_copy;
wire       [ 5:0]  pal_page_en; // which palette pages to copy
// ROM banks
wire       [ 5:0]  game;
wire       [15:0]  bank_offset;
wire       [15:0]  bank_mask;

wire               obj_dma_ok, obj_dma_clr;

jtcps1_timing u_timing(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .cen8           ( pxl_cen           ),

    .vdump          ( vdump             ),
    .hdump          ( hdump             ),
    .vrender1       ( vrender1          ),
    .vrender        ( vrender           ),
    .start          ( line_start        ),
    // to video output
    .HS             ( HS                ),
    .VS             ( VS                ),
    .VB             ( VB                ),
    .preVB          ( preVB             ),
    .HB             ( HB                )
);

// initial begin
//     $display("OFFSET=%X",`OFFSET);
// end

jtcps1_mmr #(REGSIZE) u_mmr(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .ppu_rstn       ( ppu_rstn          ),  // controlled by CPU

    .ppu1_cs        ( ppu1_cs           ),
    .ppu2_cs        ( ppu2_cs           ),
    .addr           ( addr              ),
    .dsn            ( dsn               ),      // data select, active low
    .cpu_dout       ( cpu_dout          ),
    .mmr_dout       ( mmr_dout          ),
    // registers
    .ppu_ctrl       ( ppu_ctrl          ),
    // Scroll
    .hpos1          ( hpos1             ),
    .hpos2          ( hpos2             ),
    .hpos3          ( hpos3             ),
    .vpos1          ( vpos1             ),
    .vpos2          ( vpos2             ),
    .vpos3          ( vpos3             ),
    .hstar1         ( hstar1            ),
    .hstar2         ( hstar2            ),
    .vstar1         ( vstar1            ),
    .vstar2         ( vstar2            ),

    // OBJ DMA
    .obj_dma_ok    ( obj_dma_ok       ),
    .obj_dma_clr   ( obj_dma_clr      ),

    // ROM banks
    .game           ( game              ),
    .bank_offset    ( bank_offset       ),
    .bank_mask      ( bank_mask         ),

    // VRAM position
    .vram1_base     ( vram1_base        ),
    .vram2_base     ( vram2_base        ),
    .vram3_base     ( vram3_base        ),
    .vram_obj_base  ( vram_obj_base     ),
    .vram_row_base  ( vram_row_base     ),
    .row_offset     ( row_offset        ),
    .pal_base       ( pal_base          ),
    .pal_copy       ( pal_copy          ),

    // CPS-B Registers
    .cfg_we         ( cfg_we            ),
    .cfg_data       ( cfg_data          ),

    .layer_ctrl     ( layer_ctrl        ),
    .layer_mask0    ( layer_mask0       ),
    .layer_mask1    ( layer_mask1       ),
    .layer_mask2    ( layer_mask2       ),
    .layer_mask3    ( layer_mask3       ),
    .layer_mask4    ( layer_mask4       ),
    .prio0          ( prio0             ),
    .prio1          ( prio1             ),
    .prio2          ( prio2             ),
    .prio3          ( prio3             ),
    .pal_page_en    ( pal_page_en       )
);

//`define NOSCROLL1
`ifndef NOSCROLL
jtcps1_scroll u_scroll(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .gfx_en     ( gfx_en        ),

    .vrender    ( vrender       ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),
    .preVB      ( preVB         ),
    
    .vram1_base ( vram1_base    ),
    .hpos1      ( hpos1         ),
    .vpos1      ( vpos1         ),

    .vram2_base ( vram2_base    ),
    .hpos2      ( hpos2         ),
    .vpos2      ( vpos2         ),

    .vram3_base ( vram3_base    ),
    .hpos3      ( hpos3         ),
    .vpos3      ( vpos3         ),

    // Row Scroll
    .vram_row_base  ( vram_row_base ),
    .row_offset     ( row_offset    ),
    .row_en         ( ppu_ctrl[0]   ),

    // ROM banks
    .game       ( game          ),
    .bank_offset( bank_offset   ),
    .bank_mask  ( bank_mask     ),

    .start      ( line_start    ),

    .vram_addr  ( vram1_addr    ),
    .vram_data  ( vram1_data    ),
    .vram_ok    ( vram1_ok      ),
    .vram_cs    ( vram1_cs      ),
    .rom_addr   ( rom1_addr     ),
    .rom_data   ( rom1_data     ),
    .rom_cs     ( rom1_cs       ),
    .rom_ok     ( rom1_ok       ),
    .rom_half   ( rom1_half     ),

    .scr1_pxl   ( scr1_pxl      ),
    .scr2_pxl   ( scr2_pxl      ),
    .scr3_pxl   ( scr3_pxl      )
);
`else 
assign rom1_cs    = 1'b0;
assign rom1_addr  = 20'd0;
assign vram1_cs   = 1'b0;
assign vram1_addr = 17'd0;
assign scr1_pxl   = 11'h1ff;
assign scr2_pxl   = 11'h1ff;
assign scr3_pxl   = 11'h1ff;
`endif

// Objects
`ifndef NOOBJ
jtcps1_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    // input              HB,
    //.VB         ( VB            ),

    .obj_dma_ok    ( obj_dma_ok   ),
    .obj_dma_clr   ( obj_dma_clr  ),

    .start      ( line_start    ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .vdump      ( vdump         ),
    .hdump      ( hdump         ),

    // ROM banks
    .game       ( game          ),
    .bank_offset( bank_offset   ),
    .bank_mask  ( bank_mask     ),

    // control registers
    .vram_base  ( vram_obj_base ),
    .vram_addr  ( vram_obj_addr ),
    .vram_data  ( vram_obj_data ),
    .vram_ok    ( vram_obj_ok   ),
    .vram_cs    ( vram_obj_cs   ),

    .rom_addr   ( rom0_addr     ),
    .rom_data   ( rom0_data     ),
    .rom_cs     ( rom0_cs       ),
    .rom_ok     ( rom0_ok       ),
    .rom_half   ( rom0_half     ),

    .pxl        ( obj_pxl       )
);
`else 
assign vram_obj_cs = 1'b0;
assign rom0_cs     = 1'b0;
assign rom0_addr   = 20'd0;
assign obj_pxl     = 9'h1ff;
`endif

`ifdef SIMULATION
reg pal_copy2=1'b0;
wire pal_copy3 = pal_copy2 | pal_copy;
initial begin
    pal_copy2=1'b0;
    #50_000 pal_copy2=1'b1;
    #50_040 pal_copy2=1'b0;
end
`endif


`ifndef NOCOLMIX
jtcps1_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .HB         ( HB            ),
    .VB         ( VB            ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),

    // Palette copy
    `ifdef SIMULATION
    .pal_copy   ( pal_copy3     ), // runs a palette copy command at the beginning of the simulation
    `else
    .pal_copy   ( pal_copy      ),
    `endif
    .pal_base   ( pal_base      ),
    .pal_page_en( pal_page_en   ),

    // Layer priority
    .layer_ctrl ( layer_ctrl    ),
    .layer_mask0( layer_mask0   ),
    .layer_mask1( layer_mask1   ),
    .layer_mask2( layer_mask2   ),
    .layer_mask3( layer_mask3   ),
    .layer_mask4( layer_mask4   ),
    .prio0      ( prio0         ),
    .prio1      ( prio1         ),
    .prio2      ( prio2         ),
    .prio3      ( prio3         ),

    // VRAM access
    .vram_addr  ( vpal_addr     ),
    .vram_data  ( vpal_data     ),
    .vram_ok    ( vpal_ok       ),
    .vram_cs    ( vpal_cs       ),

    // Scroll data
    .scr1_pxl   ( scr1_pxl      ),
    .scr2_pxl   ( scr2_pxl      ),
    .scr3_pxl   ( scr3_pxl      ),
    .obj_pxl    ( obj_pxl       ),
    // Video
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )    
);
`else
assign red=8'b0;
assign green=8'b0;
assign blue=8'b0;
assign LHBL_dly = ~HB;
assign LVBL_dly = ~VB;
assign vpal_cs   = 1'b0;
assign vpal_addr = 17'd0;
`endif

endmodule