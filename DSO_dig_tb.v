`timescale 1ns/10ps
module DSO_dig_tb();
	
reg clk,rst_n;							// clock and reset are generated in TB

reg [23:0] cmd_snd;						// command Host is sending to DUT
reg send_cmd;
reg clr_resp_rdy;

wire adc_clk,MOSI,SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n;
wire TX,RX;

wire [15:0] cmd_ch1,cmd_ch2,cmd_ch3;			// received commands to digital Pots that control channel gain
wire [15:0] cmd_trig;							// received command to digital Pot that controls trigger level
wire cmd_sent,resp_rdy;							// outputs from master UART
wire [7:0] resp_rcv;
wire [7:0] ch1_data,ch2_data,ch3_data;
wire trig1,trig2;

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH  = 8'h01;		// Channel to dump specified in low 2-bits of second byte
localparam CFG_GAIN = 8'h02;		// Gain setting in bits [4:2], and channel in [1:0] of 2nd byte
localparam TRIG_LVL = 8'h03;		// Set trigger level, lower byte specifies value (46,201) is valid
localparam TRIG_POS = 8'h04;		// Set the trigger position. This is a 13-bit number, samples after capture
localparam SET_DEC  = 8'h05;		// Set decimator, lower nibble of 3rd byte. 2^this value is decimator
localparam TRIG_CFG = 8'h06;		// Write trig config.  2nd byte 00dettcc.  d=done, e=edge,
localparam TRIG_RD  = 8'h07;		// Read trig config register
localparam EEP_WRT  = 8'h08;		// Write calibration EEP, 2nd byte is address, 3rd byte is data
localparam EEP_RD   = 8'h09;		// Read calibration EEP, 2nd byte specifies address

//////////////////////
// Instantiate DUT //
////////////////////
DSO_dig iDUT(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_data(ch1_data),.ch2_data(ch2_data),
             .ch3_data(ch3_data),.trig1(trig1),.trig2(trig2),.MOSI(MOSI),.MISO(MISO),.SCLK(SCLK),
             .trig_ss_n(trig_ss_n),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
			 .EEP_ss_n(EEP_ss_n),.TX(TX),.RX(RX));

///////////////////////////////////////////////
// Instantiate Analog Front End & A2D Model //
/////////////////////////////////////////////
AFE_A2D iAFE(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.ch1_ss_n(ch1_ss_n),.ch2_ss_n(ch2_ss_n),.ch3_ss_n(ch3_ss_n),
             .trig_ss_n(trig_ss_n),.MOSI(MOSI),.SCLK(SCLK),.trig1(trig1),.trig2(trig2),.ch1_data(ch1_data),
			 .ch2_data(ch2_data),.ch3_data(ch3_data));
			 
/////////////////////////////////////////////
// Instantiate UART Master (acts as host) //
///////////////////////////////////////////
UART_comm_mstr iMSTR(.clk(clk), .rst_n(rst_n), .RX(TX), .TX(RX), .cmd(cmd_snd), .send_cmd(send_cmd),
                     .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp_rcv), .clr_resp_rdy(clr_resp_rdy));

/////////////////////////////////////
// Instantiate Calibration EEPROM //
///////////////////////////////////
SPI_EEP iEEP(.clk(clk),.rst_n(rst_n),.SS_n(EEP_ss_n),.SCLK(SCLK),.MOSI(MOSI),.MISO(MISO));

initial clk = 0;
always
    #2 clk = ~clk; // 500 MHz clock

task gen_init;
    begin
    rst_n = 1'b0;
    repeat(2) @(posedge clk);
    rst_n = 1'b1;
    end
endtask

task init_UART_comm_mstr;
    begin
    cmd_snd = 24'h000000;
    send_cmd = 1'b0;
    clr_resp_rdy = 1'b1;
    repeat(2) @(posedge clk);
    end
endtask

task send_UART_mstr_cmd;
    input [23:0] temp_cmd;
    begin
    cmd_snd = temp_cmd;
    send_cmd = 1'b1;
    clr_resp_rdy = 1'b0;
    @(posedge clk);
    send_cmd = 1'b0;
    end
endtask

task check_UART_pos_ack;
    input resp_rdy;
    input resp;
    output clr_resp_rdy;
    begin
    @(posedge resp_rdy);
    if(resp === 8'hEE)
        $display("DIG UART sent a neg ack :(\n");
    else if(resp !== 8'hA5)
        $display("DIG UART didn't output anything\n");
    clr_resp_rdy = 1'b1;
    @(posedge clk);
    clr_resp_rdy = 1'b0;
    if(resp_rdy !== 1'b0)
        $display("DIG UART resp_rdy didn't clear");
    end
endtask

task check_trig_cfg;
    input [7:0] correct_trig_cfg;
    input [7:0] cur_trig_cfg;
    begin
    if(correct_trig_cfg !== cur_trig_cfg)
        $display("Expected trig_cfg %d and actual %d do not match",
                 correct_trig_cfg, cur_trig_cfg);
    end
endtask

reg [7:0] trig_cfg;
reg [7:0] AFE_data;
reg [2:0] ggg; // Analog gain value
reg [1:0] cc;  // Channel select
reg [7:0] LL; // trigger level
reg [8:0] ULL; // Trigger position register
reg [7:0] VV;  // EEPROM calibration data
reg [3:0] U, L; // U = trig_pos value, L = decimator
reg d; // capture done bit
reg e; // edge type
reg tt; // trigger type
reg [5:0] aaaaaa; // 6-bit address of calibration EEPROM

initial begin
    gen_init();
    init_UART_comm_mstr();
    // Check analog gain configure (cmd 02)
    send_UART_mstr_cmd({CFG_GAIN, 3'h0, ggg, cc});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Check set trigger level     (cmd 03)
    send_UART_mstr_cmd({TRIG_LVL, 8'hxx, LL});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Check write trigger position register (cmd 04)
    send_UART_mstr_cmd({TRIG_POS, 7'h00, ULL});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Check set decimator (cmd 05)
    send_UART_mstr_cmd({SET_DEC, 8'hxx, 4'h0, L});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Check TRIG_CFG
    send_UART_mstr_cmd({TRIG_CFG, d, e, tt, cc, 8'hxx});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Read TRIG_CFG
    send_UART_mstr_cmd({TRIG_RD, 16'hxxxx});
    check_trig_cfg(resp_rcv, {d, e, tt, cc});
    // Write calibration EEP
    send_UART_mstr_cmd({EEP_WRT, 2'h0, aaaaaa, VV});
    check_UART_pos_ack(resp_rdy, resp_rcv, clr_resp_rdy);
    // Read calibration EEP
    send_UART_mstr_cmd({EEP_RD, 2'h0, aaaaaa, 8'hxx});
    // Check EEP read is correct
    // Check dump channel
    send_UART_mstr_cmd({DUMP_CH, 16'h0000});

end

always
  #1 clk = ~clk;
			 

endmodule
			 
			 