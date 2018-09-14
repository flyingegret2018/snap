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

module scatter(
  // global
  axi_clk           , //250MHz
  axi_rstn          ,
  i_action_type     ,
  i_action_version  ,
  // axi_lite
  s_axi_awready     ,
  s_axi_awaddr      ,
  s_axi_awvalid     ,
  s_axi_wready      ,
  s_axi_wdata       ,
  s_axi_wstrb       ,
  s_axi_wvalid      ,
  s_axi_bresp       ,
  s_axi_bvalid      ,
  s_axi_bready      ,
  s_axi_arready     ,
  s_axi_arvalid     ,
  s_axi_araddr      ,
  s_axi_rdata       ,
  s_axi_rresp       ,
  s_axi_rready      ,
  s_axi_rvalid      ,
  // gen_m0
  gen_m0_maddr      ,
  gen_m0_mburst     ,
  gen_m0_mcache     ,
  gen_m0_mdata      ,
  gen_m0_mid        ,
  gen_m0_mlen       ,
  gen_m0_mlock      ,
  gen_m0_mprot      ,
  gen_m0_mread      ,
  gen_m0_mready     ,
  gen_m0_msize      ,
  gen_m0_mwrite     ,
  gen_m0_mwstrb     ,
  gen_m0_saccept    ,
  gen_m0_sdata      ,
  gen_m0_sid        ,
  gen_m0_slast      ,
  gen_m0_sresp      ,
  gen_m0_svalid
  );


//*** PARAMETER DECLARATION ****************************************************

  parameter    AXI_DW               = 512             ,
               AXI_AW               = 64              ,
               AXI_MIDW             = 4               ,
               AXI_SIDW             = 8               ;

  parameter    AXI_WID              = 0               ,
               AXI_RID              = 0               ;

  parameter    ADDR_SNAP_STATUS              = 0      ,
               ADDR_SNAP_INT_ENABLE          = 1      ,
               ADDR_SNAP_ACTION_TYPE         = 4      ,
               ADDR_SNAP_ACTION_VERSION      = 5      ,
               ADDR_SNAP_CONTEXT             = 8      ,
		       ADDR_AC_ADDR0                 = 12     ,
		       ADDR_AC_ADDR1                 = 13     ,
		       ADDR_START                    = 14     ,
		       ADDR_DONE                     = 15     ,
		       ADDR_MODE                     = 16     ,
		       ADDR_BLOCKSIZE                = 17     ,
		       ADDR_BLOCKNUM                 = 18     ,
		       ADDR_WB_ADDR0                 = 19     ,
		       ADDR_WB_ADDR1                 = 20     ;

  parameter    IDLE                 = 0               ,
               LOAD_AC              = 1               ,
               LOAD_DATA            = 2               ,
               DONE                 = 3               ;

//*** INPUT/OUTPUT DECLARATION *************************************************

  // global
  input                             axi_clk           ;
  input                             axi_rstn          ;

  // axi_lite
  output                            s_axi_awready     ;
  input  [31                : 0]    s_axi_awaddr      ;
  input                             s_axi_awvalid     ;
  output                            s_axi_wready      ;
  input  [31                : 0]    s_axi_wdata       ;
  input  [3                 : 0]    s_axi_wstrb       ;
  input                             s_axi_wvalid      ;
  output [1                 : 0]    s_axi_bresp       ;
  output                            s_axi_bvalid      ;
  input                             s_axi_bready      ;
  output                            s_axi_arready     ;
  input  [31                : 0]    s_axi_araddr      ;
  input                             s_axi_arvalid     ;
  output [31                : 0]    s_axi_rdata       ;
  output [1                 : 0]    s_axi_rresp       ;
  output                            s_axi_rvalid      ;
  input                             s_axi_rready      ;

  // gen_m0 (cur pix & bs)
  output [AXI_AW-1          : 0]    gen_m0_maddr      ;
  output [1                 : 0]    gen_m0_mburst     ;
  output [3                 : 0]    gen_m0_mcache     ;
  output [AXI_DW-1          : 0]    gen_m0_mdata      ;
  output [AXI_MIDW-1        : 0]    gen_m0_mid        ;
  output [7                 : 0]    gen_m0_mlen       ;
  output                            gen_m0_mlock      ;
  output [2                 : 0]    gen_m0_mprot      ;
  output                            gen_m0_mread      ;
  output                            gen_m0_mready     ;
  output [2                 : 0]    gen_m0_msize      ;
  output                            gen_m0_mwrite     ;
  output [AXI_DW/8-1        : 0]    gen_m0_mwstrb     ;
  input                             gen_m0_saccept    ;
  input  [AXI_DW-1          : 0]    gen_m0_sdata      ;
  input  [AXI_MIDW-1        : 0]    gen_m0_sid        ;
  input                             gen_m0_slast      ;
  input  [2                 : 0]    gen_m0_sresp      ;
  input                             gen_m0_svalid     ;

  input  [31                : 0]    i_action_type     ;
  input  [31                : 0]    i_action_version  ;


//*** WIRE/REG DECLARATION *****************************************************

  reg    [31                : 0]    s_axi_rdata       ;
  reg                               s_axi_rvalid      ;
  wire   [1                 : 0]    s_axi_rresp       ;
  wire   [1                 : 0]    s_axi_bresp       ;
  reg                               s_axi_bvalid      ;
  reg                               s_axi_arready     ;
  reg                               s_axi_awready     ;
  reg                               s_axi_wready      ;

  reg                               reg_start         ;
  reg                               reg_done          ;
  reg    [31                : 0]    reg_ac_addr0      ;
  reg    [31                : 0]    reg_ac_addr1      ;

  reg    [1                 : 0]    cur_state         ;
  reg    [1                 : 0]    nxt_state         ;
  reg    [AXI_AW-1          : 0]    gen_m0_maddr      ;        
  reg                               gen_m0_mread      ;
  reg    [7                 : 0]    ac_cnt            ;
  reg    [1                 : 0]    read_cnt          ;
  wire   [AXI_AW-1          : 0]    ac_addr           ;

  wire                              push_req_ac       ;
  wire                              pop_req_ac        ;
  wire                              empty_ac          ;
  wire   [AXI_AW-1          : 0]    data_out_ac       ;

//*** MAIN ****************************************************************

  // axi_lite
  // to reg_start 
  //--- CDC SYN start ---
  always @(posedge axi_clk or negedge axi_rstn) begin
    if( !axi_rstn )
      reg_start <= 1'b0 ;
    else if( s_axi_wvalid && s_axi_wready && (s_axi_awaddr[6:2]==ADDR_START) && s_axi_wdata[0] )
      reg_start <= 1'b1 ;
    else
      reg_start <= 1'b0 ;
  end

  always @(posedge axi_clk or negedge axi_rstn) begin
    if( !axi_rstn )
      reg_done <= 1'b0 ;
	else if(cur_state == DONE)
	  reg_done <= 1'b1 ;
  end

  // to other register
  always @(posedge axi_clk or negedge axi_rstn) begin
    if( !axi_rstn ) begin
                          reg_ac_addr0    <= 'd0 ;
                          reg_ac_addr1    <= 'd0 ;
    end
    else if(s_axi_awvalid & s_axi_awready) begin
      case(s_axi_awaddr[6:2])
        ADDR_AC_ADDR0   : reg_ac_addr0    <= s_axi_wdata ;
        ADDR_AC_ADDR1   : reg_ac_addr1    <= s_axi_wdata ;
      endcase
    end
  end

  always @(*) begin
                        s_axi_rdata = 0              ;
    case( s_axi_araddr[6:2] )
	  ADDR_SNAP_STATUS          : s_axi_rdata = 32'd0           ;
	  ADDR_SNAP_INT_ENABLE      : s_axi_rdata = 32'd0           ;
	  ADDR_SNAP_ACTION_TYPE     : s_axi_rdata = i_action_type   ;
	  ADDR_SNAP_ACTION_VERSION  : s_axi_rdata = i_action_version;
	  ADDR_SNAP_CONTEXT         : s_axi_rdata = 32'd0           ;
      ADDR_DONE                 : s_axi_rdata = {31'b0,reg_done};
    endcase
  end

  assign s_axi_bresp = 2'b00;
  assign s_axi_rresp = 2'b00;

  always @(posedge axi_clk or negedge axi_rstn)
    if( !axi_rstn )
	  s_axi_bvalid <= 1'b0;
	else if(s_axi_wvalid & s_axi_wready)
	  s_axi_bvalid <= 1'b1;
	else if(s_axi_bready)
	  s_axi_bvalid <= 1'b0;

  always @(posedge axi_clk or negedge axi_rstn)
    if( !axi_rstn )
	  s_axi_rvalid <= 1'b0;
	else if(s_axi_arvalid & s_axi_arready)
	  s_axi_rvalid <= 1'b1;
	else if(s_axi_rready)
	  s_axi_rvalid <= 1'b0;

  always @(posedge axi_clk or negedge axi_rstn)
    if( !axi_rstn )
	  s_axi_arready <= 1'b1;
	else if(s_axi_arvalid)
	  s_axi_arready <= 1'b0;
	else if(s_axi_rvalid & s_axi_rready)
	  s_axi_arready <= 1'b1;

  always @(posedge axi_clk or negedge axi_rstn)
    if( !axi_rstn )
	  s_axi_awready <= 1'b0;
	else if(s_axi_awvalid)
	  s_axi_awready <= 1'b1;
	else if(s_axi_wvalid & s_axi_wready)
	  s_axi_awready <= 1'b0;

  always @(posedge axi_clk or negedge axi_rstn)
    if( !axi_rstn )
	  s_axi_wready <= 1'b0;
	else if(s_axi_awvalid & s_axi_awready)
	  s_axi_wready <= 1'b1;
	else if(s_axi_wvalid)
	  s_axi_wready <= 1'b0;

//*** gm0 ****************************************************************

  always @(posedge axi_clk or negedge axi_rstn ) begin
    if( !axi_rstn )
      cur_state <= 0 ;
    else
      cur_state <= nxt_state ;
  end

  always @(*) begin
    nxt_state = IDLE;
    case( cur_state )
      IDLE  :  if( reg_start ) 
                nxt_state = LOAD_AC; 
              else
                nxt_state = IDLE ;
      LOAD_AC  :  if( ac_cnt == 'h80 )
                nxt_state = LOAD_DATA ;
              else                    
                nxt_state = LOAD_AC  ;
      LOAD_DATA :  if( empty_ac )      
                nxt_state = DONE ;
              else                    
                nxt_state = LOAD_DATA ;
      DONE :  if ( !axi_rstn )
                nxt_state = IDLE ;
              else
                nxt_state = DONE ;
    endcase
  end

  assign gen_m0_mburst   = 2'b01                   ;
  assign gen_m0_mcache   = 4'b0000                 ;
  assign gen_m0_mid      = AXI_RID                 ;
  assign gen_m0_mlock    = 0                       ;
  assign gen_m0_mprot    = 3'b000                  ;
  assign gen_m0_mready   = 1                       ;
  assign gen_m0_mwstrb   = 64'hffff_ffff_ffff_ffff ;
  assign gen_m0_mdata    = 512'b0                  ;
  assign gen_m0_mwrite   = 0                       ;

  assign gen_m0_msize    = (cur_state == LOAD_AC) ? 3'b110 : 3'b101 ;
  assign gen_m0_mlen     = (cur_state == LOAD_AC) ?   'd63 : 'd31   ;

    fifo_512_64 fifo_ac(
      .rst              ( !axi_rstn         ),
      .clk              ( axi_clk           ),
      .din              ( gen_m0_sdata      ),
      .wr_en            ( push_req_ac       ),
      .rd_en            ( pop_req_ac        ),
      .dout             ( data_out_ac       ),
      .empty            ( empty_ac          )
    );

    assign push_req_ac  = gen_m0_svalid & (gen_m0_sresp==0) & (cur_state == LOAD_AC);
    assign pop_req_ac   = !empty_ac & gen_m0_saccept & gen_m0_mread & (cur_state == LOAD_DATA);

	always@(posedge axi_clk or negedge axi_rstn)
	    if(!axi_rstn)
			read_cnt <= 'd0;
		else if(gen_m0_mread & gen_m0_saccept & (cur_state == LOAD_AC))
			read_cnt <= read_cnt + 1'b1;

  always @(posedge axi_clk or negedge axi_rstn )
	    if(!axi_rstn)
            ac_cnt   <= 'd0;
		else if(push_req_ac)
            ac_cnt   <= ac_cnt + 1'b1;

  assign ac_addr = {reg_ac_addr0,reg_ac_addr1};

  always @(*) begin
    if ( (cur_state == LOAD_AC) & (read_cnt == 2'b0) )
        gen_m0_maddr = ac_addr;
	else if (cur_state == LOAD_AC)
	    gen_m0_maddr = ac_addr + 12'h800;
    else
	    gen_m0_maddr = data_out_ac ;
  end

  always @(*) begin
    gen_m0_mread = 0 ;
    if ( cur_state== LOAD_AC )
		gen_m0_mread = (read_cnt < 2);
	else if (cur_state == LOAD_DATA)
        gen_m0_mread = !empty_ac;
  end

endmodule
