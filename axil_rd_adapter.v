
/*
Copyright (c) 2018 Alex Forencich
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

//////////////////////////////////////////////////////////////////////////////////
// Create Date: 08/27/2025 06:42:51 PM
// Module Name: axil_rd_adapter
// Project Name: AXI4_vdo
// version :1 
// Dependencies: None
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps


module axil_rd_adapter #
(
       // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) interface data bus in bits  
    parameter S_DATA_WIDTH = 32,
    // Width of output (master) interface data bus in bits
    parameter M_DATA_WIDTH = 32
)
(
    input  wire                        clk,
    input  wire                        rstn,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]       s_axil_araddr,  //read address
    input  wire                        s_axil_arvalid, //  read address valid
    output wire                        s_axil_arready, // read address ready
    output wire [S_DATA_WIDTH-1:0]     s_axil_rdata,  //read data
    output wire [1:0]                  s_axil_rresp,  //read response
    output wire                        s_axil_rvalid,  // read data valid
    input  wire                        s_axil_rready,   // read data ready

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]       m_axil_araddr,
    output wire                        m_axil_arvalid,
    input  wire                        m_axil_arready,
    input  wire [M_DATA_WIDTH-1:0]     m_axil_rdata,
    input  wire [1:0]                  m_axil_rresp,
    input  wire                        m_axil_rvalid,
    output wire                        m_axil_rready
);

// Parameter validation
initial begin
    if (S_DATA_WIDTH != M_DATA_WIDTH) begin
        $error("Error: This simplified adapter only supports same-width interfaces (instance %m)");
        $finish;
    end
end

// State definitions
localparam [0:0]
    STATE_IDLE = 1'd0,
    STATE_DATA = 1'd1;

// State and control registers
reg [0:0] state_reg = STATE_IDLE, state_next;

// Slave interface registers
reg s_axil_arready_reg = 1'b0, s_axil_arready_next;
reg [S_DATA_WIDTH-1:0] s_axil_rdata_reg = {S_DATA_WIDTH{1'b0}}, s_axil_rdata_next;
reg [1:0] s_axil_rresp_reg = 2'd0, s_axil_rresp_next;
reg s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

// Master interface registers
reg [ADDR_WIDTH-1:0] m_axil_araddr_reg = {ADDR_WIDTH{1'b0}}, m_axil_araddr_next;
reg m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
reg m_axil_rready_reg = 1'b0, m_axil_rready_next;

// Output assignments
assign s_axil_arready = s_axil_arready_reg;
assign s_axil_rdata = s_axil_rdata_reg;
assign s_axil_rresp = s_axil_rresp_reg;
assign s_axil_rvalid = s_axil_rvalid_reg;

assign m_axil_araddr = m_axil_araddr_reg;
assign m_axil_arvalid = m_axil_arvalid_reg;
assign m_axil_rready = m_axil_rready_reg;

// Combinational logic
always @* begin
    // Default assignments
    state_next = STATE_IDLE;
    
    s_axil_arready_next = 1'b0;
    s_axil_rdata_next = s_axil_rdata_reg;
    s_axil_rresp_next = s_axil_rresp_reg;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rready;
    
    m_axil_araddr_next = m_axil_araddr_reg;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_arready;
    m_axil_rready_next = 1'b0;

    // State machine for single-cycle direct transfer
    case (state_reg)
        STATE_IDLE: begin
            s_axil_arready_next = !m_axil_arvalid_reg;

            if (s_axil_arready_reg && s_axil_arvalid) begin
                s_axil_arready_next = 1'b0;
                m_axil_araddr_next = s_axil_araddr;
                m_axil_arvalid_next = 1'b1;
                m_axil_rready_next = !m_axil_rvalid;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        
        STATE_DATA: begin
            m_axil_rready_next = !s_axil_rvalid_reg;
            if (m_axil_rready_reg && m_axil_rvalid) begin
                m_axil_rready_next = 1'b0;
                s_axil_rdata_next = m_axil_rdata;
                s_axil_rresp_next = m_axil_rresp;
                s_axil_rvalid_next = 1'b1;
                s_axil_arready_next = !m_axil_arvalid_reg;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_DATA;
            end
        end
    endcase
end

// Sequential logic
always @(posedge clk) begin
    if (rstn==0) begin
        state_reg <= STATE_IDLE;
        s_axil_arready_reg <= 1'b0;
        s_axil_rdata_reg <= {S_DATA_WIDTH{1'b0}};
        s_axil_rresp_reg <= 2'd0;
        s_axil_rvalid_reg <= 1'b0;
        m_axil_araddr_reg <= {ADDR_WIDTH{1'b0}};
        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;
    end else begin
        state_reg <= state_next;
        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_rresp_reg <= s_axil_rresp_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;
        m_axil_araddr_reg <= m_axil_araddr_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;
    end
end

endmodule

