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

module jtcps1_obj_table(
    input              rst,
    input              clk,

    input              VB,

    // control registers
    input      [15:0]  vram_base,
    output reg [23:1]  vram_addr,
    input      [15:0]  vram_data,
    input              vram_ok,
    output reg         vram_cs,

    // interface with renderer
    input      [ 9:0]  table_addr,
    output reg [15:0]  table_data
);

reg frame, frame_n, last_VB, st;
reg [ 9:0] wr_addr;
reg [15:0] wr_data;
reg        wr_en;
reg        wait_cycle;

// buffer (dual port RAM)
reg [15:0] table_buffer[0:(2**11)-1];

always @(posedge clk) begin
    if( wr_en ) table_buffer[ {frame_n, wr_addr} ] <= wr_data;
end

always @(posedge clk) begin
    table_data <= table_buffer[ {frame, table_addr} ];
end

`ifdef SIMULATION
// avoid X's
integer cnt;
initial begin
    $display("OBJ table initialization OK");
    for(cnt=0;cnt<2**11;cnt=cnt+1) table_buffer[cnt]=16'd0;
end
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        frame     <= 1'b0;
        frame_n   <= 1'b1;
        st        <= 0;
        vram_cs   <= 1'b0;
        vram_addr <= 23'd0;
    end else begin
        last_VB <= VB;
        case( st )
            0: begin
                vram_addr  <= {vram_base[15:3], 10'd0};
                vram_cs    <= 1'b0;
                wr_addr    <= 10'h3ff;
                wr_en      <= 1'b0;
                wait_cycle <= 1'b1;
                if( !VB && last_VB ) begin // start of new frame, after blanking
                    vram_cs   <= 1'b1;
                    frame     <= ~frame;
                    frame_n   <=  frame;
                    st        <= 1;
                end else st<=0;
            end
            1: begin
                wait_cycle <= 1'b0;
                if(vram_ok && !wait_cycle) begin
                    vram_addr[17:1]  <= vram_addr[17:1] + 17'd1;
                    wr_addr          <= wr_addr + 10'd1;
                    wr_data          <= vram_data;
                    wr_en            <= 1'b1;
                    wait_cycle       <= 1'b1;
                    if( vram_addr[10:1]== 10'h3fe ) st<=0;
                end
            end
        endcase
    end
end

endmodule