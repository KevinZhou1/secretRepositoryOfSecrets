module dig_pot(clk,rst_n,MOSI,SCLK,SS,wipe_0,wipe_1);

  input clk,rst_n;			// clock and reset
  input MOSI;				// SPI serial data in
  input SCLK;				// SPI clock
  input SS;					// SPI Slave Select
  
  output reg [7:0] wipe_0;		// wiper 0 output
  output reg [7:0] wipe_1;		// wiper 1 output
  
  reg cmd_rdy_ff;
  
  wire [15:0] cmd;			// hold 16-bit data received over SPI
  wire cmd_rdy_pos_edge;
  //////////////////////////////////////
  // Instantiate SPI slave front end //
  ////////////////////////////////////
  SPI_slv iCHX_CFG(.clk(clk), .rst_n(rst_n), .tx_data(16'h00), .wrt(1'b0), .SCLK(SCLK), .MISO(),
                   .SS_n(SS), .MOSI(MOSI), .cmd_rcvd(cmd), .cmd_rdy(cmd_rdy), .rsp_rdy());
			
  ////////////////////////////////////////////
  // Implement logic for writes to wiper 0 //
  //////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  wipe_0 <= 8'h80;		// initializes to mid rail
	else if (cmd_rdy_pos_edge)
	  wipe_0 <= ((cmd[13:12]==2'b01) && (cmd[8])) ? cmd[7:0] : wipe_0;

  ////////////////////////////////////////////
  // Implement logic for writes to wiper 1 //
  //////////////////////////////////////////
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  wipe_1 <= 8'h80;		// initializes to mid rail
	else if (cmd_rdy_pos_edge)
	  wipe_1 <= ((cmd[13:12]==2'b01) && (cmd[9])) ? cmd[7:0] : wipe_1;	  
	  
  ///////////////////////////////////////////////////
  // Need to flop cmd_rdy to make + edge detector // 
  /////////////////////////////////////////////////  
  always @(posedge clk, negedge rst_n)
    if (!rst_n)
	  cmd_rdy_ff <= 1'b0;
	else
	  cmd_rdy_ff <= cmd_rdy;
	  
  assign cmd_rdy_pos_edge = cmd_rdy & ~cmd_rdy_ff;
  
endmodule