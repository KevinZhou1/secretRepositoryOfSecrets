module RAM_Interface(clk, rst_n, rclk, ch1_rdata, ch2_rdata, ch3_rdata, we, en, ch_sel, read_data, cap_en, cap_we, dump_en);

  input clk, rst_n;
  input rclk;				   // clock (1/2 of system clock, 200MHz)
  input cap_en, cap_we, dump_en;          // Enable/Write signals from capture and dump SMs
  output en;			 	 // Active high for reads or writes to occur
  output we;			 	// Has to be high in addition to en for writes
  input [1:0] ch_sel;		       // Selects which channel to take the read data from. CH1: {01} CH2: {10} CH3: {11} 
  input [7:0] ch1_rdata, ch2_rdata, ch3_rdata; // data to be written, writes occur on clock high
  output logic [7:0] read_data;	     // read data, read occurs on clock high


  assign read_data = 	(ch_sel == 2'b01)	?	ch1_rdata	:
			(ch_sel == 2'b10)	?	ch2_rdata	:
			(ch_sel == 2'b11)	?	ch3_rdata	:
							8'b0000_0000;
  assign en = (cap_en|dump_en);
  assign we = cap_we;



endmodule
	  
