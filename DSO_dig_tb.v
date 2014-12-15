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
`include "task.sv"
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
    ////////////////////////////////////////////////
    // Initialization: rst_n = 0, and clear UART //
    //////////////////////////////////////////////
    gen_init();
    init_UART_comm_mstr();

    ////////////////////////////////////
    // CMD 02: Analog gain configure //
    //////////////////////////////////
    // Set channel one gain, valid command
    ggg = 3'b011; // analog gain value
    cc = 2'b00; // channel select
    send_cfg_gain_cmd(ggg, cc, 1'b1);
    // Set channel two gain, valid command
    ggg = 3'b001;
    cc = 2'b01;
    send_cfg_gain_cmd(ggg, cc, 1'b1);
    // Set channel three gain, valid command
    ggg = 3'b010;
    cc = 2'b10;
    send_cfg_gain_cmd(ggg, cc, 1'b1);
    // Set channel "four" gain, invalid command. Should return neg ack
    ggg = 3'b111;
    cc = 2'b11;
    send_cfg_gain_cmd(ggg, cc, 1'b0);

    ///////////////////////////////////////////
    // CMD 03: Set trigger level (trig_lvl) //
    /////////////////////////////////////////
    LL = 8'h80; // trigger level
    send_trig_lvl_cmd(LL, 1'b1);
    LL = 8'h2D;
    send_trig_lvl_cmd(LL, 1'b0);

    //////////////////////////////////////////////
    // CMD 04: Set trigger position (trig_pos) //
    ////////////////////////////////////////////
    ULL = 9'h134; // trigger position
    send_trig_pos_cmd(ULL, 1'b1);

    ////////////////////////////
    // CMD 05: Set decimator //
    //////////////////////////
    L = 4'h2; // decimator
    send_set_dec_cmd(L, 1'b1);

    /////////////////////////////////////////////////////
    // CMD 06: Set trigger config register (trig_cfg) //
    ///////////////////////////////////////////////////
    d = 1'b0; // capture_done
    e = 1'b1; // edge type, 1 == positive edge, 0 == negative edge
    tt = 2'b01; // trigger type, 10 = auto roll, 01 = normal, 00 = off
    cc = 2'b00; // channel select, 00 = channel 1, 01 = channel
    send_trig_cfg_cmd(d, e, tt, cc, 1'b1);
    // 2'b10 channel select is invalid. Should return neg ack
    cc = 2'b10;
    send_trig_cfg_cmd(d, e, tt, cc, 1'b0);

    //////////////////////////////////////////////////////
    // CMD 07: Read trigger config register (trig_cfg) //
    ////////////////////////////////////////////////////
    cc = 2'b00;
    send_rd_trig_cfg_cmd(d, e, tt, cc);

    ////////////////////////////////////////////
    // CMD 08: Write to EEP calibration data //
    //////////////////////////////////////////
    aaaaaa = 6'h12; // calibration address
    VV = 8'h34; // EEPROM calibration data
    send_eep_wrt_cmd(aaaaaa, VV, 1'b1);

    ////////////////////////////////////////
    // CMD 09: Read EEP calibration data //
    //////////////////////////////////////
    // Read calibration EEP
    aaaaaa = 6'h12; // calibration address
    send_eep_rd_cmd(aaaaaa, VV);
    $stop;

    $readmemh("RAM.hex",iDUT.iRAM1.mem);
    $readmemh("RAM2.hex",iDUT.iRAM2.mem);
    $readmemh("RAM3.hex",iDUT.iRAM3.mem);
    $stop();
    // Check dump channel
    send_UART_mstr_cmd({DUMP_CH, 16'h0000});
    //$stop;
end

endmodule
