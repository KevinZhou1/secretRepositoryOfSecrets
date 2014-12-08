module SPI_EEP(clk,rst_n,SS_n,SCLK,MOSI,MISO);

input clk, rst_n;
input SS_n,SCLK,MOSI;
output MISO;

reg [7:0]mem[0:255];

reg [1:0] state,nstate;
reg wrt;
reg	[15:0] tx_data;
reg wrt_mem;

wire [7:0] rd_data;
wire [15:0] cmd_rcvd;
wire cmd_rdy;
wire [5:0] addr;

////// bits [13:8] of the command to EEP will always form address /////
assign addr = cmd_rcvd[13:8];

localparam IDLE  = 2'b00;
localparam READ  = 2'b01;
localparam WRITE = 2'b10;
localparam WAIT_RDY_FALL = 2'b11;
//////////////////////////////
// State Machine & Control //
////////////////////////////
always @(*)
  begin
    //////////////////////////////////////////////
	// Default SM outputs to most common state //
	////////////////////////////////////////////
    wrt = 0;
	tx_data = {8'h00,rd_data};
	nstate = IDLE;
	wrt_mem = 0;
	
	case (state)
	  IDLE : begin
	    if (cmd_rdy)
		  begin
			case (cmd_rcvd[15:14])
			  2'b00 : begin
			    nstate = READ;
			  end
			  2'b01 : begin
			    nstate = WRITE;
			  end			  
			  default : begin
			    $display("ERROR: command to cal EEP has unknown opcode bits");
				nstate = IDLE;
			  end
			endcase
		  end
		else
		  nstate = IDLE;
	  end
	  READ : begin
        tx_data = {8'h00,rd_data};		// data from array read will be transmitted next
		wrt = 1;
		nstate = WAIT_RDY_FALL;
	  end
	  WRITE : begin
	    tx_data = 16'hA5A5;		// EEPROM can send a positive acknowledge on writes
		wrt = 1;
	    wrt_mem = 1;			// write the data received in cmd_rcvd[7:0] to memory
		nstate = WAIT_RDY_FALL;
	  end
	  WAIT_RDY_FALL : begin
	    if (cmd_rdy)
          nstate = WAIT_RDY_FALL;
		else
		  nstate = IDLE;
	  end
	endcase
  end
  
///////////////////////////////////
// Instantiate 16-bit SPI slave //
/////////////////////////////////
SPI_slv iEEP_SPI(.clk(clk),.rst_n(rst_n),.tx_data(tx_data),.wrt(wrt),.SCLK(SCLK),.MISO(MISO),.SS_n(SS_n),.MOSI(MOSI),
                 .cmd_rcvd(cmd_rcvd),.cmd_rdy(cmd_rdy),.rsp_rdy());
	
//////////////////////////////
// Model the memory itself //
////////////////////////////	
always @(posedge clk)
  if (wrt_mem)
    mem[addr] = cmd_rcvd[7:0];

/// now the memory read ///
assign rd_data = mem[addr];
		
//////////////////
// State flops //
////////////////
always @(posedge clk, negedge rst_n)
  if (!rst_n)
    state <= IDLE;
  else
    state <= nstate;
	
initial
  $readmemh("CAL_EEP.hex",mem);
  
endmodule
			 
