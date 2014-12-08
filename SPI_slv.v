`timescale 1 ns / 100 ps
module SPI_slv(clk,rst_n,tx_data,wrt,SCLK,MISO,SS_n,MOSI,cmd_rcvd,cmd_rdy,rsp_rdy);

  input clk,rst_n,SS_n,SCLK,wrt,MOSI;
  input [15:0] tx_data;

  output MISO;
  output [15:0] cmd_rcvd;
  output cmd_rdy;
  output rsp_rdy;

  reg [15:0] shft_reg,buffer;
  reg state,nstate;
  reg shft,ld,cmd_rdy,set_cmd_rdy,rsp_rdy;
  reg SCLK_ff1,SCLK_ff2,SCLK_ff3,SS_n_ff1,SS_n_ff2;
  reg MOSI_ff1,MOSI_ff2,MOSI_ff3;

  wire negSCLK;

  localparam IDLE = 1'b0;
  localparam TX   = 1'b1;

  ///////////////////////////////////////////
  // write is double buffered...meaning   //
  // our core can write to SPI output    //
  // while read of previous in progress //
  ///////////////////////////////////////
  always @(posedge clk)
    if (wrt)
      buffer <= tx_data;

  ////////////////////////////////////
  // Implement response ready flop //
  //////////////////////////////////
  always @(posedge clk,negedge rst_n)
    if (!rst_n)
      rsp_rdy <= 0;
    else if (wrt)
      rsp_rdy <= 1;
    else if (ld)
      rsp_rdy <= 0;

  /////////////////////////////////////
  // create parallel shift register //
  ///////////////////////////////////
  always @(posedge clk)
    if (ld)
      shft_reg <= buffer;
    else if (shft)
      shft_reg <= {shft_reg[14:0],MOSI_ff3};

  ////////////////////////////////////////////////////////////
  // double flop SCLK and SS_n for meta-stability purposes //
  ////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      begin
        SCLK_ff1 <= 1'b0;
        SCLK_ff2 <= 1'b0;
        SCLK_ff3 <= 1'b0;
        SS_n_ff1 <= 1'b1;
        SS_n_ff2 <= 1'b1;
        MOSI_ff1 <= 1'b0;
        MOSI_ff2 <= 1'b0;
        MOSI_ff3 <= 1'b0;
      end
    else
      begin
        SCLK_ff1 <= SCLK; 
        SCLK_ff2 <= SCLK_ff1;
        SCLK_ff3 <= SCLK_ff2;
        SS_n_ff1 <= SS_n;
        SS_n_ff2 <= SS_n_ff1; 
        MOSI_ff1 <= MOSI;
        MOSI_ff2 <= MOSI_ff1;
        MOSI_ff3 <= MOSI_ff2;
      end

  ///////////////////////////////
  // Implement state register //
  /////////////////////////////
  always @(posedge clk or negedge rst_n)
    if (!rst_n)
      state <= IDLE;
    else
      state <= nstate;

  /////////////////////////////////
  // Implement cmd_rdy register //
  ///////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
      cmd_rdy <= 1'b0;
    else if (ld)
      cmd_rdy <= 1'b0;
    else if (set_cmd_rdy)
      cmd_rdy <= 1'b1;

  //////////////////////////////////////
  // Implement state tranisiton logic //
  /////////////////////////////////////
  always @(state,SS_n_ff2,negSCLK)
    begin
      //////////////////////
      // Default outputs //
      ////////////////////
      shft = 0;
      ld = 0;
      set_cmd_rdy = 0;
      case (state)
        IDLE : begin
          if (!SS_n_ff2)
            begin
              ld = 1;
              nstate = TX;
            end
          else nstate = IDLE;
        end
        TX : begin
          shft = negSCLK & ~SS_n_ff2;
          if (SS_n_ff2) 
            begin
              set_cmd_rdy = 1;
              nstate = IDLE;
            end
          else nstate = TX;
        end
      endcase
    end
  
  /////////////////////////////////////////////////////
  // If SCLK_ff3 is still high, but SCLK_ff2 is low //
  // then a negative edge of SCLK has occurred.    //
  //////////////////////////////////////////////////
  assign negSCLK = ~SCLK_ff2 && SCLK_ff3;
  ///// MISO is shift_reg[15] with a tri-state ///////////
  assign MISO = (SS_n_ff2) ? 1'bz : shft_reg[15];
 
  assign cmd_rcvd = shft_reg;

endmodule
