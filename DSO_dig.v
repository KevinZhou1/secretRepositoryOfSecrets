`timescale 1ns/10ps
module DSO_dig(clk,rst_n,adc_clk,ch1_data,ch2_data,ch3_data,trig1,trig2,MOSI,MISO,
               SCLK,trig_ss_n,ch1_ss_n,ch2_ss_n,ch3_ss_n,EEP_ss_n,TX,RX);
				
  input clk,rst_n;								// clock and active low reset
  output adc_clk;								// 20MHz clocks to ADC
  input [7:0] ch1_data,ch2_data,ch3_data;		// input data from ADC's
  input trig1,trig2;							// trigger inputs from AFE
  input MISO;									// Driven from SPI output of EEPROM chip
  output MOSI;									// SPI output to digital pots and EEPROM chip
  output SCLK;									// SPI clock (40MHz/16)
  output reg ch1_ss_n,ch2_ss_n,ch3_ss_n;			// SPI slave selects for configuring channel gains (active low)
  output reg trig_ss_n;								// SPI slave select for configuring trigger level
  output reg EEP_ss_n;								// Calibration EEPROM slave select
  output TX;									// UART TX to HOST
  input RX;										// UART RX from HOST
  //output LED_n;									// control to active low LED
  
  ////////////////////////////////////////////////////
  // Define any wires needed for interconnect here //
  //////////////////////////////////////////////////
  wire wrt_SPI, SPI_done, SS_n;
  wire [2:0]ss;
  wire [15:0]SPI_cmd;
  wire [15:0]SPI_data_out;
  wire [7:0]EEP_data;
  assign EEP_data = SPI_data_out[7:0];
  
  wire rclk;
 
  wire en, we;
  wire [8:0]addr;
  wire [7:0]ch1_rdata, ch2_rdata, ch3_rdata;

  wire [23:0]cmd;
  wire cmd_rdy,resp_sent, trmt, clr_cmd_rdy, rdy, clr_rdy;
  wire [7:0] resp_data, rx_data;
  /////////////////////////////
  // Instantiate SPI master //
  ///////////////////////////
  SPI_Master iSPI(.clk(clk), .rst_n(rst_n), .wrt(wrt_SPI), .MISO(MISO), .cmd(SPI_cmd), .SCLK(SCLK), .SS_n(SS_n), .done(SPI_done), .MOSI(MOSI), .SPI_data_out(SPI_data_out));
  ///////////////////////////////////////////////////////////////
  // You have a SPI master peripheral with a single SS output //
  // you might have to do something creative to generate the //
  // 5 individual SS needed (3 AFE, 1 Trigger, 1 EEP)       //
  ///////////////////////////////////////////////////////////
  always@(*)begin
    ch1_ss_n = 1;
    ch2_ss_n = 1;
    ch3_ss_n = 1;
    trig_ss_n = 1;
    EEP_ss_n = 1;
    case (ss)
      3'b000: trig_ss_n = 0;
      3'b001: ch1_ss_n = 0;
      3'b010: ch2_ss_n = 0;
      3'b011: ch3_ss_n = 0;
      3'b100: EEP_ss_n = 0;
      default: ;
    endcase
  end
  ///////////////////////////////////
  // Instantiate UART_comm module //
  /////////////////////////////////
  //Note to self, restructure UART wrapper to be an actual wrapper
  UART_comm iUART_comm(.cmd_rdy(cmd_rdy), .clr_rdy(clr_rdy), .cmd(cmd), .clk(clk), .rst_n(rst_n), .rdy(rdy), .clr_cmd_rdy(clr_cmd_rdy), .trmt(trmt), .rx_data(rx_data));
  UART iUART(.RX(RX), .clr_rdy(clr_rdy), .trmt(trmt), .clk(clk), .rst_n(rst_n), 
          .tx_data(resp_data), .TX(TX), .tx_done(resp_sent), .rdy(rdy), .rx_data(rx_data));
  
  ///////////////////////////
  // Instantiate dig_core //
  /////////////////////////
  dig_core idig_core(.clk(clk),.rst_n(rst_n),.adc_clk(adc_clk),.trig1(trig1),.trig2(trig2),.SPI_data(SPI_cmd),.wrt_SPI(wrt_SPI),.SPI_done(SPI_done),.ss(ss),.EEP_data(EEP_data),
                     .rclk(rclk),.en(en),.we(we),.addr(addr),.ch1_rdata(ch1_rdata),.ch2_rdata(ch2_rdata),.ch3_rdata(ch3_rdata),.cmd(cmd),.cmd_rdy(cmd_rdy),.clr_cmd_rdy(clr_cmd_rdy),
				     .resp_data(resp_data),.send_resp(trmt),.resp_sent(resp_sent));
  //////////////////////////////////////////////////////////////
  // Instantiate the 3 512 RAM blocks that store A2D samples //
  ////////////////////////////////////////////////////////////
  RAM512 iRAM1(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch1_data),.rdata(ch1_rdata));
  RAM512 iRAM2(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch2_data),.rdata(ch2_rdata));
  RAM512 iRAM3(.rclk(rclk),.en(en),.we(we),.addr(addr),.wdata(ch3_data),.rdata(ch3_rdata));

endmodule
  