

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
// Module Name: axil_wr_adapter
// Project Name: AXI4_vdo
// version :1 
// Dependencies: None
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
module axil_wr_adapter #
(
    
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) interface data bus in bits
    parameter S_DATA_WIDTH = 32,
    // Width of output (master) interface data bus in bits
    parameter M_DATA_WIDTH = 32
)
(
    input  wire                     clk,
    input  wire                     rstn,

    /*
     * AXI lite slave interface
     */
    input  wire [ADDR_WIDTH-1:0]    s_axil_awaddr,  //Write address
    input  wire                     s_axil_awvalid, // Write address valid
    output wire                     s_axil_awready, //Write address ready
    input  wire [S_DATA_WIDTH-1:0]  s_axil_wdata,   //Write data
    input  wire                     s_axil_wvalid,  // Write data valid
    output wire                     s_axil_wready,  //Write data ready
    output wire [1:0]               s_axil_bresp,   //Write response
    output wire                     s_axil_bvalid,  // Write response valid
    input  wire                     s_axil_bready,  //Write response ready

    /*
     * AXI lite master interface
     */
    output wire [ADDR_WIDTH-1:0]    m_axil_awaddr,
    output wire                     m_axil_awvalid,
    input  wire                     m_axil_awready,
    output wire [M_DATA_WIDTH-1:0]  m_axil_wdata,
    output wire                     m_axil_wvalid,
    input  wire                     m_axil_wready,
    input  wire [1:0]               m_axil_bresp,
    input  wire                     m_axil_bvalid,
    output wire                     m_axil_bready
);

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_DATA = 2'd1,
    STATE_RESP = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg s_axil_awready_reg = 1'b0, s_axil_awready_next;
reg s_axil_wready_reg = 1'b0, s_axil_wready_next;
reg [1:0] s_axil_bresp_reg = 2'd0, s_axil_bresp_next;
reg s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

reg [ADDR_WIDTH-1:0] m_axil_awaddr_reg = {ADDR_WIDTH{1'b0}}, m_axil_awaddr_next;
reg m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
reg [M_DATA_WIDTH-1:0] m_axil_wdata_reg = {M_DATA_WIDTH{1'b0}}, m_axil_wdata_next;
reg m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
reg m_axil_bready_reg = 1'b0, m_axil_bready_next;

assign s_axil_awready = s_axil_awready_reg;
assign s_axil_wready = s_axil_wready_reg;
assign s_axil_bresp = s_axil_bresp_reg;
assign s_axil_bvalid = s_axil_bvalid_reg;

assign m_axil_awaddr = m_axil_awaddr_reg;
assign m_axil_awvalid = m_axil_awvalid_reg;
assign m_axil_wdata = m_axil_wdata_reg;
assign m_axil_wvalid = m_axil_wvalid_reg;
assign m_axil_bready = m_axil_bready_reg;

always @* begin
    state_next = STATE_IDLE;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bresp_next = s_axil_bresp_reg;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_bready;
    m_axil_awaddr_next = m_axil_awaddr_reg;
    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_awready;
    m_axil_wdata_next = m_axil_wdata_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wready;
    m_axil_bready_next = 1'b0;

    case(state_reg)
        STATE_IDLE: begin
            s_axil_awready_next = !m_axil_awvalid_reg;

            if (s_axil_awready && s_axil_awvalid) begin
                s_axil_awready_next = 1'b0;
                m_axil_awaddr_next = s_axil_awaddr;
                m_axil_awvalid_next = 1'b1;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DATA: begin
            s_axil_wready_next = !m_axil_wvalid_reg;
            if (s_axil_wready && s_axil_wvalid) begin
                s_axil_wready_next = 1'b0;
                m_axil_wdata_next = s_axil_wdata;
                m_axil_wvalid_next = 1'b1;
                state_next = STATE_RESP;
            end else begin
                state_next = STATE_DATA;
            end
        end
        STATE_RESP: begin
            m_axil_bready_next = !s_axil_bvalid_reg;

            if (m_axil_bready && m_axil_bvalid) begin
                m_axil_bready_next = 1'b0;
                s_axil_bresp_next = m_axil_bresp;
                s_axil_bvalid_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_RESP;
            end
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bresp_reg <= s_axil_bresp_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    m_axil_awaddr_reg <= m_axil_awaddr_next;
    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wdata_reg <= m_axil_wdata_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;

    if (rstn==0) begin
        state_reg <= STATE_IDLE;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        m_axil_awvalid_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        m_axil_bready_reg <= 1'b0;
    end
end

endmodule



/*
 * Variable Table
 * 
 * | Variable Name       | Purpose                                                                 | Pipelined |
 * |---------------------|-------------------------------------------------------------------------|-----------|
 * | clk                 | Clock signal for synchronous logic                                     | No        |
 * | rstn                 | active low Reset signal to initialize the state machine                           | No        |
 * | s_axil_araddr       | Read address from the slave interface                                   | No        |
 * | s_axil_arvalid      | Indicates if the read address from the slave is valid                  | No        |
 * | s_axil_arready      | Indicates if the module is ready to accept a read address from the slave| Yes       |
 * | s_axil_rdata        | Read data to the slave interface                                        | Yes       |
 * | s_axil_rresp        | Read response to the slave interface                                    | Yes       |
 * | s_axil_rvalid       | Indicates if the read data to the slave is valid                       | Yes       |
 * | s_axil_rready       | Indicates if the slave is ready to accept read data                    | No        |
 * | m_axil_araddr       | Read address to the master interface                                    | Yes       |
 * | m_axil_arvalid      | Indicates if the read address to the master is valid                   | Yes       |
 * | m_axil_arready      | Indicates if the master is ready to accept a read address              | No        |
 * | m_axil_rdata        | Read data from the master interface                                     | No        |
 * | m_axil_rresp        | Read response from the master interface                                 | No        |
 * | m_axil_rvalid       | Indicates if the read data from the master is valid                    | No        |
 * | m_axil_rready       | Indicates if the module is ready to accept read data from the master   | Yes       |
 */

