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
               AXI_MIDW             = 1               ,
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
		       ADDR_WB_ADDR1                 = 20     ,
		       ADDR_G_ADDR0                  = 21     ,
		       ADDR_G_ADDR1                  = 22     ,
		       ADDR_G_SIZE                   = 23     ;

  parameter    IDLE                 = 0               ,
               LOAD_AC              = 1               ,
               LOAD_DATA            = 2               ,
               LOAD_SOFT            = 3               ,
               DONE                 = 4               ;

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
  reg    [1                 : 0]    reg_mode          ;
  reg    [31                : 0]    reg_block_size    ;
  reg    [31                : 0]    reg_block_num     ;
  reg    [31                : 0]    reg_wb_addr0      ;
  reg    [31                : 0]    reg_wb_addr1      ;
  reg    [31                : 0]    reg_g_addr0       ;
  reg    [31                : 0]    reg_g_addr1       ;
  reg    [31                : 0]    reg_g_size        ;

  reg    [2                 : 0]    cur_state         ;
  reg    [2                 : 0]    nxt_state         ;
  reg    [AXI_AW-1          : 0]    gen_m0_maddr      ;        
  reg                               gen_m0_mread      ;
  reg    [7                 : 0]    gen_m0_mlen       ;
  reg    [13                : 0]    ac_cnt            ;
  reg    [4                 : 0]    read_cnt          ;
  reg    [9                 : 0]    soft_cnt          ;
  wire   [9                 : 0]    soft_total        ;
  wire   [AXI_AW-1          : 0]    ac_addr           ;
  wire   [AXI_AW-1          : 0]    g_addr            ;
  wire   [4                 : 0]    ac_total_read     ;

  wire                              push_req_ac       ;
  wire                              pop_req_ac        ;
  wire                              empty_ac          ;
  wire   [AXI_AW-1          : 0]    data_out_ac       ;
  wire   [AXI_DW-1          : 0]    push_data_ac      ;

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
						  reg_mode        <= 'd0 ;
						  reg_block_size  <= 'd0 ;
						  reg_block_num   <= 'd0 ;
						  reg_wb_addr0    <= 'd0 ;
						  reg_wb_addr1    <= 'd0 ;
						  reg_g_addr0     <= 'd0 ;
						  reg_g_addr1     <= 'd0 ;
						  reg_g_size      <= 'd0 ;
    end
    else if(s_axi_awvalid & s_axi_awready) begin
      case(s_axi_awaddr[6:2])
        ADDR_AC_ADDR0   : reg_ac_addr0    <= s_axi_wdata ;
        ADDR_AC_ADDR1   : reg_ac_addr1    <= s_axi_wdata ;
        ADDR_MODE       : reg_mode        <= s_axi_wdata[1:0] ;
        ADDR_BLOCKSIZE  : reg_block_size  <= s_axi_wdata ;
        ADDR_BLOCKNUM   : reg_block_num   <= s_axi_wdata ;
        ADDR_WB_ADDR0   : reg_wb_addr0    <= s_axi_wdata ;
        ADDR_WB_ADDR1   : reg_wb_addr1    <= s_axi_wdata ;
        ADDR_G_ADDR0    : reg_g_addr0     <= s_axi_wdata ;
        ADDR_G_ADDR1    : reg_g_addr1     <= s_axi_wdata ;
        ADDR_G_SIZE     : reg_g_size      <= s_axi_wdata ;
      endcase
    end
  end

  assign ac_total_read = (reg_block_num - 1)/512;
  assign soft_total    = reg_g_size[21:12];

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
      IDLE  :  if((reg_start == 1'b1) & (reg_mode == 2'b00)) 
                nxt_state = LOAD_SOFT;
			  else if((reg_start == 1'b1) & (reg_mode == 2'b01))
			    nxt_state = LOAD_AC;
              else
                nxt_state = IDLE;
      LOAD_AC  :  if( ac_cnt == reg_block_num[16:3] )
                nxt_state = LOAD_DATA;
              else                    
                nxt_state = LOAD_AC;
      LOAD_DATA :  if( empty_ac )      
                nxt_state = DONE;
              else                    
                nxt_state = LOAD_DATA;
	  LOAD_SOFT :  if( soft_cnt == soft_total )
	            nxt_state = DONE;
	          else
			    nxt_state = LOAD_SOFT;
      DONE :  if ( !axi_rstn )
                nxt_state = IDLE;
              else
                nxt_state = DONE;
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
  assign gen_m0_msize    = 3'b110                  ;

    fifo_512_64 fifo_ac(
      .rst              ( !axi_rstn         ),
      .clk              ( axi_clk           ),
      .din              ( push_data_ac      ),
      .wr_en            ( push_req_ac       ),
      .rd_en            ( pop_req_ac        ),
      .dout             ( data_out_ac       ),
      .empty            ( empty_ac          )
    );

    assign push_data_ac = {gen_m0_sdata[63:0],gen_m0_sdata[127:64],gen_m0_sdata[191:128],gen_m0_sdata[255:192],gen_m0_sdata[319:256],gen_m0_sdata[383:320],gen_m0_sdata[447:384],gen_m0_sdata[511:448]};
	assign push_req_ac  = gen_m0_svalid & (gen_m0_sresp==0) & (cur_state == LOAD_AC);
    assign pop_req_ac   = !empty_ac & gen_m0_saccept & gen_m0_mread & (cur_state == LOAD_DATA);

	always@(posedge axi_clk or negedge axi_rstn)
	    if(!axi_rstn)
			read_cnt <= 'd0;
		else if(gen_m0_mread & gen_m0_saccept & (cur_state == LOAD_AC))
			read_cnt <= read_cnt + 1'b1;

	always@(posedge axi_clk or negedge axi_rstn)
	    if(!axi_rstn)
			soft_cnt <= 'd0;
		else if(gen_m0_mread & gen_m0_saccept & (cur_state == LOAD_SOFT))
			soft_cnt <= soft_cnt + 1'b1;

    always @(posedge axi_clk or negedge axi_rstn )
	    if(!axi_rstn)
            ac_cnt   <= 'd0;
		else if(push_req_ac)
            ac_cnt   <= ac_cnt + 1'b1;

    assign ac_addr = {reg_ac_addr0,reg_ac_addr1};
    assign g_addr  = {reg_g_addr0,reg_g_addr1};

    always @(*) begin
        if((cur_state == LOAD_AC) & (read_cnt == ac_total_read) & (reg_block_num[8:3] != 6'b0))
    	    gen_m0_mlen = reg_block_num[8:3] - 1'b1;
    	else if((cur_state == LOAD_AC) || (cur_state == LOAD_SOFT))
    	    gen_m0_mlen = 'd63;
    	else
    	    gen_m0_mlen = reg_block_size[13:6] - 1'b1;
    end

    always @(*) begin
        if ( cur_state == LOAD_AC )
	        gen_m0_maddr = ac_addr + 'd4096 * read_cnt;
        else if( cur_state == LOAD_SOFT )
	        gen_m0_maddr = g_addr + 'd4096 * soft_cnt;
	    else
	        gen_m0_maddr = data_out_ac ;
    end

    always @(*) begin
    gen_m0_mread = 0 ;
        if (cur_state == LOAD_AC)
		    gen_m0_mread = (read_cnt < (ac_total_read + 1));
		else if (cur_state == LOAD_SOFT)
	        gen_m0_mread = (soft_cnt < soft_total);
	    else if (cur_state == LOAD_DATA)
            gen_m0_mread = !empty_ac;
    end

endmodule
