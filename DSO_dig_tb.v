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
    gen_init();
    init_UART_comm_mstr();
    // Check analog gain configure (cmd 02)
    ggg = 3'b000; // analog gain value
    cc = 2'b00; // channel select
    send_cfg_gain_cmd(ggg, cc, 1'b1);
    // Check set trigger level     (cmd 03)
    LL = 8'h2E; // trigger level
    send_trig_lvl_cmd(LL, 1'b1);
    /*// Check write trigger position register (cmd 04)
    ULL = 9'h100; // trigger position
    send_trig_pos_cmd(ULL, 1'b1);
    // Check set decimator (cmd 05)
    L = 4'h0; // decimator
    send_set_dec_cmd(LL, 1'b1);
    // Check TRIG_CFG
    d = 1'b0; // capture_done
    e = 1'b1; // edge type, 1 == positive edge, 0 == negative edge
    tt = 2'b01; // trigger type, 10 = auto roll, 01 = normal, 00 = off
    cc = 2'b00; // channel select, 00 = channel 1, 01 = channel
    send_trig_cfg_cmd(d, e, tt, cc, 1'b1);
    // Read TRIG_CFG
    send_rd_trig_cfg_cmd(d, e, tt, cc);
    // Write calibration EEP
    aaaaaa = 6'h00; // calibration address
    VV = 8'h00; // EEPROM calibration data
    send_eep_wrt_cmd(aaaaaa, VV, 1'b1);
    // Read calibration EEP
    aaaaaa = 6'h00; // calibration address
    send_eep_rd_cmd(aaaaaa, VV);
    // Check dump channel
    send_UART_mstr_cmd({DUMP_CH, 16'h0000});*/
    $stop;
end

endmodule
