////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016,2017 International Business Machines
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions AND
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module action_wrapper #(
    // Parameters of Axi Slave Bus Interface AXI_CTRL_REG
    parameter C_S_AXI_CTRL_REG_DATA_WIDTH    = 32,
    parameter C_S_AXI_CTRL_REG_ADDR_WIDTH    = 32,

    // Parameters of Axi Master Bus Interface AXI_HOST_MEM ; to Host memory
    parameter C_M_AXI_HOST_MEM_ID_WIDTH      = 1,
    parameter C_M_AXI_HOST_MEM_ADDR_WIDTH    = 64,
    parameter C_M_AXI_HOST_MEM_DATA_WIDTH    = 512,
    parameter C_M_AXI_HOST_MEM_AWUSER_WIDTH  = 8,
    parameter C_M_AXI_HOST_MEM_ARUSER_WIDTH  = 8,
    parameter C_M_AXI_HOST_MEM_WUSER_WIDTH   = 1,
    parameter C_M_AXI_HOST_MEM_RUSER_WIDTH   = 1,
    parameter C_M_AXI_HOST_MEM_BUSER_WIDTH   = 1,
    parameter INT_BITS                       = 3,
    parameter CONTEXT_BITS                   = 8
)
(
    input  ap_clk                    ,
    input  ap_rst_n                  ,
    output interrupt                 ,
    output [INT_BITS-2 : 0] interrupt_src             ,
    output [CONTEXT_BITS-1 : 0] interrupt_ctx             ,
    input  interrupt_ack             ,
    //                                                                                                 
    // AXI Control Register Interface
    input  [C_S_AXI_CTRL_REG_ADDR_WIDTH-1 : 0 ] s_axi_ctrl_reg_araddr     ,
    output s_axi_ctrl_reg_arready    ,
    input  s_axi_ctrl_reg_arvalid    ,
    input  [C_S_AXI_CTRL_REG_ADDR_WIDTH-1 : 0 ] s_axi_ctrl_reg_awaddr     ,
    output s_axi_ctrl_reg_awready    ,
    input  s_axi_ctrl_reg_awvalid    ,
    input  s_axi_ctrl_reg_bready     ,
    output [1 : 0 ] s_axi_ctrl_reg_bresp      ,
    output s_axi_ctrl_reg_bvalid     ,
    output [C_S_AXI_CTRL_REG_DATA_WIDTH-1 : 0 ] s_axi_ctrl_reg_rdata      ,
    input  s_axi_ctrl_reg_rready     ,
    output [1 : 0 ] s_axi_ctrl_reg_rresp      ,
    output s_axi_ctrl_reg_rvalid     ,
    input  [C_S_AXI_CTRL_REG_DATA_WIDTH-1 : 0 ] s_axi_ctrl_reg_wdata      ,
    output s_axi_ctrl_reg_wready     ,
    input  [(C_S_AXI_CTRL_REG_DATA_WIDTH/8)-1 : 0 ] s_axi_ctrl_reg_wstrb      ,
    input  s_axi_ctrl_reg_wvalid     ,
    //
    // AXI Host Memory Interface
    output [C_M_AXI_HOST_MEM_ADDR_WIDTH-1 : 0 ] m_axi_host_mem_araddr     ,
    output [1 : 0 ] m_axi_host_mem_arburst    ,
    output [3 : 0 ] m_axi_host_mem_arcache    ,
    output [C_M_AXI_HOST_MEM_ID_WIDTH-1 : 0 ] m_axi_host_mem_arid       ,
    output [7 : 0 ] m_axi_host_mem_arlen      ,
    output [1 : 0 ] m_axi_host_mem_arlock     ,
    output [2 : 0 ] m_axi_host_mem_arprot     ,
    output [3 : 0 ] m_axi_host_mem_arqos      ,
    input  m_axi_host_mem_arready    ,
    output [3 : 0 ] m_axi_host_mem_arregion   ,
    output [2 : 0 ] m_axi_host_mem_arsize     ,
    output [C_M_AXI_HOST_MEM_ARUSER_WIDTH-1 : 0 ] m_axi_host_mem_aruser     ,
    output m_axi_host_mem_arvalid    ,
    output [C_M_AXI_HOST_MEM_ADDR_WIDTH-1 : 0 ] m_axi_host_mem_awaddr     ,
    output [1 : 0 ] m_axi_host_mem_awburst    ,
    output [3 : 0 ] m_axi_host_mem_awcache    ,
    output [C_M_AXI_HOST_MEM_ID_WIDTH-1 : 0 ] m_axi_host_mem_awid       ,
    output [7 : 0 ] m_axi_host_mem_awlen      ,
    output [1 : 0 ] m_axi_host_mem_awlock     ,
    output [2 : 0 ] m_axi_host_mem_awprot     ,
    output [3 : 0 ] m_axi_host_mem_awqos      ,
    input  m_axi_host_mem_awready    ,
    output [3 : 0 ] m_axi_host_mem_awregion   ,
    output [2 : 0 ] m_axi_host_mem_awsize     ,
    output [C_M_AXI_HOST_MEM_AWUSER_WIDTH-1 : 0 ] m_axi_host_mem_awuser     ,
    output m_axi_host_mem_awvalid    ,
    input  [C_M_AXI_HOST_MEM_ID_WIDTH-1 : 0 ] m_axi_host_mem_bid        ,
    output m_axi_host_mem_bready     ,
    input  [1 : 0 ] m_axi_host_mem_bresp      ,
    input  [C_M_AXI_HOST_MEM_BUSER_WIDTH-1 : 0 ] m_axi_host_mem_buser      ,
    input  m_axi_host_mem_bvalid     ,
    input  [C_M_AXI_HOST_MEM_DATA_WIDTH-1 : 0 ] m_axi_host_mem_rdata      ,
    input  [C_M_AXI_HOST_MEM_ID_WIDTH-1 : 0 ] m_axi_host_mem_rid        ,
    input  m_axi_host_mem_rlast      ,
    output m_axi_host_mem_rready     ,
    input  [1 : 0 ] m_axi_host_mem_rresp      ,
    input  [C_M_AXI_HOST_MEM_RUSER_WIDTH-1 : 0 ] m_axi_host_mem_ruser      ,
    input  m_axi_host_mem_rvalid     ,
    output [C_M_AXI_HOST_MEM_DATA_WIDTH-1 : 0 ] m_axi_host_mem_wdata      ,
    output m_axi_host_mem_wlast      ,
    input  m_axi_host_mem_wready     ,
    output [(C_M_AXI_HOST_MEM_DATA_WIDTH/8)-1 : 0 ] m_axi_host_mem_wstrb      ,
    output [C_M_AXI_HOST_MEM_WUSER_WIDTH-1 : 0 ] m_axi_host_mem_wuser      ,
    output m_axi_host_mem_wvalid
);

    // Make wuser stick to 0
    assign m_axi_card_mem0_wuser = 0;
    assign m_axi_card_mem0_aruser = 0;
    assign m_axi_card_mem0_arqos = 0;
    assign m_axi_card_mem0_arregion = 0;
    assign m_axi_card_mem0_awuser = 0;
    assign m_axi_card_mem0_awqos = 0;
    assign m_axi_card_mem0_awregion = 0;
    assign m_axi_host_mem_wuser = 0;
    assign m_axi_host_mem_aruser = 0;
    assign m_axi_host_mem_arqos = 0;
    assign m_axi_host_mem_arregion = 0;
    assign m_axi_host_mem_awuser = 0;
    assign m_axi_host_mem_awqos = 0;
    assign m_axi_host_mem_awregion = 0;

    // gen_m0
    wire   [C_M_AXI_HOST_MEM_ADDR_WIDTH-1       : 0]     gen_m0_maddr   ;
    wire   [1                                   : 0]     gen_m0_mburst  ;
    wire   [3                                   : 0]     gen_m0_mcache  ;
    wire   [C_M_AXI_HOST_MEM_DATA_WIDTH-1       : 0]     gen_m0_mdata   ;
    wire   [C_M_AXI_HOST_MEM_ID_WIDTH-1         : 0]     gen_m0_mid     ;
    wire   [7                                   : 0]     gen_m0_mlen    ;
    wire                                                 gen_m0_mlock   ;
    wire   [2                                   : 0]     gen_m0_mprot   ;
    wire                                                 gen_m0_mread   ;
    wire                                                 gen_m0_mready  ;
    wire   [2                                   : 0]     gen_m0_msize   ;
    wire                                                 gen_m0_mwrite  ;
    wire   [C_M_AXI_HOST_MEM_DATA_WIDTH/8-1     : 0]     gen_m0_mwstrb  ;
    wire                                                 gen_m0_saccept ;
    wire   [C_M_AXI_HOST_MEM_DATA_WIDTH-1       : 0]     gen_m0_sdata   ;
    wire   [C_M_AXI_HOST_MEM_ID_WIDTH-1         : 0]     gen_m0_sid     ;
    wire                                                 gen_m0_slast   ;
    wire   [2                                   : 0]     gen_m0_sresp   ;
    wire                                                 gen_m0_svalid  ;

  gm_0_DW_axi_gm gm_0_DW_axi_gm_0(
    // Outputs
    .saccept           ( gen_m0_saccept           ),
    .sid               ( gen_m0_sid               ),
    .svalid            ( gen_m0_svalid            ),
    .slast             ( gen_m0_slast             ),
    .sdata             ( gen_m0_sdata             ),
    .sresp             ( gen_m0_sresp             ),
    .awid              ( m_axi_host_mem_awid      ),
    .awvalid           ( m_axi_host_mem_awvalid   ),
    .awaddr            ( m_axi_host_mem_awaddr    ),
    .awlen             ( m_axi_host_mem_awlen     ),
    .awsize            ( m_axi_host_mem_awsize    ),
    .awburst           ( m_axi_host_mem_awburst   ),
    .awlock            ( m_axi_host_mem_awlock    ),
    .awcache           ( m_axi_host_mem_awcache   ),
    .awprot            ( m_axi_host_mem_awprot    ),
    .wid               (                          ), //temp
    .wvalid            ( m_axi_host_mem_wvalid    ),
    .wlast             ( m_axi_host_mem_wlast     ),
    .wdata             ( m_axi_host_mem_wdata     ),
    .wstrb             ( m_axi_host_mem_wstrb     ),
    .bready            ( m_axi_host_mem_bready    ),
    .arid              ( m_axi_host_mem_arid      ),
    .arvalid           ( m_axi_host_mem_arvalid   ),
    .araddr            ( m_axi_host_mem_araddr    ),
    .arlen             ( m_axi_host_mem_arlen     ),
    .arsize            ( m_axi_host_mem_arsize    ),
    .arburst           ( m_axi_host_mem_arburst   ),
    .arlock            ( m_axi_host_mem_arlock    ),
    .arcache           ( m_axi_host_mem_arcache   ),
    .arprot            ( m_axi_host_mem_arprot    ),
    .rready            ( m_axi_host_mem_rready    ),
    // Inputs
    .aclk              ( ap_clk                   ),
    .aresetn           ( ap_rst_n                 ),
    .gclken            ( 1'b1                     ),
    .mid               ( gen_m0_mid               ),
    .maddr             ( gen_m0_maddr             ),
    .mread             ( gen_m0_mread             ),
    .mwrite            ( gen_m0_mwrite            ),
    .mlock             ( gen_m0_mlock             ),
    .mlen              ( gen_m0_mlen              ),
    .msize             ( gen_m0_msize             ),
    .mburst            ( gen_m0_mburst            ),
    .mcache            ( gen_m0_mcache            ),
    .mprot             ( gen_m0_mprot             ),
    .mdata             ( gen_m0_mdata             ),
    .mwstrb            ( gen_m0_mwstrb            ),
    .mready            ( gen_m0_mready            ),
    .awready           ( m_axi_host_mem_awready   ),
    .wready            ( m_axi_host_mem_wready    ),
    .bid               ( m_axi_host_mem_bid       ),
    .bvalid            ( m_axi_host_mem_bvalid    ),
    .bresp             ( m_axi_host_mem_bresp     ),
    .arready           ( m_axi_host_mem_arready   ),
    .rid               ( m_axi_host_mem_rid       ),
    .rvalid            ( m_axi_host_mem_rvalid    ),
    .rlast             ( m_axi_host_mem_rlast     ),
    .rdata             ( m_axi_host_mem_rdata     ),
    .rresp             ( m_axi_host_mem_rresp     )
    );

  scatter scatter0(
    // global
    .axi_clk           ( ap_clk                     ), //250MHz
    .axi_rstn          ( ap_rst_n                   ),
	.i_action_type     ( 32'h1014100B               ),
	.i_action_version  ( 32'h00000000               ),
    // axi_lite
    .s_axi_awready     ( s_axi_ctrl_reg_awready     ),
    .s_axi_awaddr      ( s_axi_ctrl_reg_awaddr      ),
    .s_axi_awvalid     ( s_axi_ctrl_reg_awvalid     ),
    .s_axi_wready      ( s_axi_ctrl_reg_wready      ),
    .s_axi_wdata       ( s_axi_ctrl_reg_wdata       ),
    .s_axi_wstrb       ( s_axi_ctrl_reg_wstrb       ),
    .s_axi_wvalid      ( s_axi_ctrl_reg_wvalid      ),
    .s_axi_bresp       ( s_axi_ctrl_reg_bresp       ),
    .s_axi_bvalid      ( s_axi_ctrl_reg_bvalid      ),
    .s_axi_bready      ( s_axi_ctrl_reg_bready      ),
    .s_axi_arready     ( s_axi_ctrl_reg_arready     ),
    .s_axi_arvalid     ( s_axi_ctrl_reg_arvalid     ),
    .s_axi_araddr      ( s_axi_ctrl_reg_araddr      ),
    .s_axi_rdata       ( s_axi_ctrl_reg_rdata       ),
    .s_axi_rresp       ( s_axi_ctrl_reg_rresp       ),
    .s_axi_rready      ( s_axi_ctrl_reg_rready      ),
    .s_axi_rvalid      ( s_axi_ctrl_reg_rvalid      ),
    // gen_m0
    .gen_m0_maddr      ( gen_m0_maddr               ),
    .gen_m0_mburst     ( gen_m0_mburst              ),
    .gen_m0_mcache     ( gen_m0_mcache              ),
    .gen_m0_mdata      ( gen_m0_mdata               ),
    .gen_m0_mid        ( gen_m0_mid                 ),
    .gen_m0_mlen       ( gen_m0_mlen                ),
    .gen_m0_mlock      ( gen_m0_mlock               ),
    .gen_m0_mprot      ( gen_m0_mprot               ),
    .gen_m0_mread      ( gen_m0_mread               ),
    .gen_m0_mready     ( gen_m0_mready              ),
    .gen_m0_msize      ( gen_m0_msize               ),
    .gen_m0_mwrite     ( gen_m0_mwrite              ),
    .gen_m0_mwstrb     ( gen_m0_mwstrb              ),
    .gen_m0_saccept    ( gen_m0_saccept             ),
    .gen_m0_sdata      ( gen_m0_sdata               ),
    .gen_m0_sid        ( gen_m0_sid                 ),
    .gen_m0_slast      ( gen_m0_slast               ),
    .gen_m0_sresp      ( gen_m0_sresp               ),
    .gen_m0_svalid     ( gen_m0_svalid              )
    );
    
endmodule
