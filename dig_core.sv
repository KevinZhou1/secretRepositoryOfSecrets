///////////////////////////////////////////////////////////////////////////////
//Jared Pierce and Maggie White                                             //
//                                                                         //
//I wasn't sure how much we actually had to implement, so I just          //
//did the minimum to decode incoming commands and send out their         //
//SPI requests.                                                         //
/////////////////////////////////////////////////////////////////////////
module dig_core(clk,rst_n,adc_clk,trig1,trig2,SPI_data,wrt_SPI,SPI_done,ss,EEP_data,
                rclk,en,we,addr,ch1_rdata,ch2_rdata,ch3_rdata,cmd,cmd_rdy,clr_cmd_rdy,
				resp_data,send_resp,resp_sent);
  // Universal signals
  input clk,rst_n;								// clock and active low reset
  // ADC control signals
  output logic adc_clk,rclk;				    // 20MHz clocks to ADC and RAM
  input trig1,trig2;							// trigger inputs from AFE
  // EEPROM SPI control signals
  output [15:0] SPI_data;						// typically a config command to digital pots or EEPROM
  output wrt_SPI;								// control signal asserted for 1 clock to initiate SPI transaction
  output [2:0] ss;								// determines which Slave gets selected 000=>trig, 001-011=>chX_ss, 1XX=>EEP
  input SPI_done;								// asserted by SPI peripheral when finished transaction
  input [7:0] EEP_data;							// Formed from MISO from EEPROM.  only lower 8-bits needed from SPI periph
  output en,we;									// RAM block control signals (common to all 3 RAM blocks)
  output [8:0] addr;							// Address output to RAM blocks (common to all 3 RAM blocks)
  input [7:0] ch1_rdata,ch2_rdata,ch3_rdata;	// data inputs from RAM blocks
  // UART control signals
  input [23:0] cmd;								// 24-bit command from HOST
  input cmd_rdy;								// tell core command from HOST is valid
  output clr_cmd_rdy;
  output [7:0] resp_data;						// response byte to HOST
  output send_resp;								// control signal to UART comm block that initiates a response
  input resp_sent;								// input from UART comm block that indicates response finished sending
  
  //////////////////////////////////////////////////////////////////////////
  // Interconnects between modules...declare any wire types you need here//
  ////////////////////////////////////////////////////////////////////////
  wire trig_en;                                 // Enable signal from Command to Capture
  wire capture_done;                            // Signal from capture module that it has triggered and capture is complete
  wire clr_cap_done;                            // Signal to clear current capture status on the Capture module
  wire [8:0] addr_ptr;                          // Current address from the Capture module
  wire [8:0] trig_pos;                          // The trigger position from the CNC to the Capture
  wire [7:0] RAM_rdata;                         // Data from RAM Interface to CNC
  wire [7:0] trig_cfg;
  wire [3:0] decimator;
 
 
   ////////////////////////////////////////////////////////
  // Run rclk for interaction with channel RAM modules //
  //////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      rclk <= 1'b0;
    else
      rclk <= ~rclk;
  end
  
  assign adc_clk = ~rclk; // adc_clk and rclk in opposite phases
  
  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////
  
  ADC_Capture iADC_Cap(.clk(clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2), .trig_en(trig_en),
                       .trig_pos(trig_pos), .clr_cap_done(clr_cap_done), .addr_ptr(addr_ptr),
                       .capture_done(capture_done), .decimator(decimator), .dump(dump),
                       .dump_fin(dumpDone), .trig_cfg(trig_cfg));


  RAMInterface iRAM_Int(.clk(clk), .rst_n(rst_n), .rclk(rclk), .ch1_rdata(ch1_rdata),
                         .ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata), .addr_ptr(addr_ptr),
                         .capture_done(capture_done), .ch_sel(ch_sel), .cap_en(), .cap_we(),
                         .en(en), .we(we), .addr(addr), .read_data(RAM_rdata), .dump_en(dump_en));

  Command_Config iCNC(.clk(clk), .rst_n(rst_n), .SPI_done(SPI_done), .EEP_data(EEP_data),
                      .cmd(cmd), .cmd_rdy(cmd_rdy), .resp_sent(resp_sent),
                      .capture_done(capture_done), .RAM_rdata(RAM_rdata), .SPI_data(SPI_data),
                      .wrt_SPI(wrt_SPI), .ss(ss), .clr_cmd_rdy(clr_cmd_rdy), 
                      .resp_data(resp_data), .send_resp(send_resp),
                      .trig_pos(trig_pos), .trig_cfg(trig_cfg),
                      .decimator(decimator), .dump(dump), .dump_ch(dump_ch));

  DSM dsm(.clk(clk), .rst_n(rst_n), .rclk(rclk), .addr(addr_ptr), .incAddr(),
          .channel(), .ch_sel(ch_sel), .ch1_AFEGain(), .ch2_AFEGain(),
          .ch3_AFEGain(), .startDump(dump), .startUARTresp(send_resp), .startSPI(wrt_SPI),
          .SPIrdy(SPI_done), .UARTrdy(resp_sent), .dumpDone(dump_fin),
          .flopGain(), .flopOffset(), .spiTXdata(SPI_data));
  
endmodule
