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
  wire incAddr;                                 // Signal to inc the addr_ptr from the DSM to the ADC_SM
  wire capture_done;                            // Signal from capture module that it has triggered and capture is complete
  wire clr_cap_done;                            // Signal to clear current capture status on the Capture module
  wire set_capture_done;
  wire dump;
  wire dumpDone;
  wire cap_we, cap_en;
  wire dump_en;
  wire dump_fin;
  wire flopGain;
  wire flopOffset;
  wire wrt_SPICNC, wrt_SPIDSM;
  wire send_respCNC, send_respDSM;
  wire [7:0] resp_dataCNC;
  wire [1:0] ch_sel;
  wire [1:0] dump_ch;
  wire [2:0] ch1_AFEGain, ch2_AFEGain, ch3_AFEGain;
  wire [8:0] addr_ptr;                          // Current address from the Capture module
  wire [8:0] trig_pos;                          // The trigger position from the CNC to the Capture
  wire [7:0] RAM_rdata;                         // Data from RAM Interface to CNC
  wire [7:0] trig_cfg;
  wire [3:0] decimator;
  wire [15:0] SPI_dataCNC, SPI_dataDSM;
 
   ////////////////////////////////////////////////////////
  // Run rclk for interaction with channel RAM modules //
  //////////////////////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      rclk <= 1'b0;
    else
      rclk <= ~rclk;
  end
  
  assign adc_clk = ~rclk; // adc_clk and rclk in opposite phases
  assign addr = addr_ptr;
  
  assign wrt_SPI = (dump_en) ? wrt_SPIDSM : wrt_SPICNC;
  assign SPI_data = (dump_en) ? SPI_dataDSM : SPI_dataCNC;
  assign resp_data = resp_dataCNC;
  assign send_resp = (dump_en) ? send_respDSM : send_respCNC;
  
  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////
  
  ADC_Capture iADC_Cap(.clk(clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2),
                       .trig_pos(trig_pos), .clr_cap_done(clr_cap_done), .addr_ptr(addr_ptr),
                       .set_capture_done(set_capture_done), .decimator(decimator), .dump(dump),
                       .dump_fin(dumpDone), .trig_cfg(trig_cfg), .we(cap_we), .en(cap_en),
                       .adc_clk(adc_clk), .incAddr(incAddr));

  RAM_Interface iRAM_Int(.ch1_rdata(ch1_rdata),
                         .ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata),
                         .ch_sel(ch_sel), .cap_en(cap_en), .cap_we(cap_we),
                         .en(en), .we(we), .read_data(RAM_rdata), .dump_en(dump_en));

  Command_Config iCNC(.clk(clk), .rst_n(rst_n), .SPI_done(SPI_done), .EEP_data(EEP_data),
                      .cmd(cmd), .cmd_rdy(cmd_rdy), .resp_sent(resp_sent),
                      .set_capture_done(set_capture_done), .RAM_rdata(RAM_rdata), .SPI_data(SPI_dataCNC),
                      .wrt_SPI(wrt_SPICNC), .ss(ss), .clr_cmd_rdy(clr_cmd_rdy), 
                      .resp_data(resp_dataCNC), .send_resp(send_respCNC),
                      .trig_pos(trig_pos), .trig_cfg(trig_cfg),
                      .decimator(decimator), .dump(dump), .dump_ch(dump_ch), .ch1_AFEgain(ch1_AFEGain),
                      .ch2_AFEgain(ch2_AFEGain), .ch3_AFEgain(ch3_AFEGain),
                      .flopGain(flopGain), .flopOffset(flopOffset));

  DSM dsm(.clk(clk), .rst_n(rst_n), .addr(addr_ptr), .incAddr(incAddr),
          .channel(dump_ch), .ch_sel(ch_sel), .ch1_AFEGain(ch1_AFEGain), .ch2_AFEGain(ch2_AFEGain),
          .ch3_AFEGain(ch3_AFEGain), .startDump(dump), .startUARTresp(send_respDSM), .startSPI(wrt_SPIDSM),
          .SPIrdy(SPI_done), .UARTrdy(resp_sent), .dumpDone(dump_fin),
          .flopGain(flopGain), .flopOffset(flopOffset), .spiTXdata(SPI_dataDSM), .dump_en(dump_en));
  
endmodule
