module AFE_A2D(clk,rst_n,adc_clk,ch1_ss_n,ch2_ss_n,ch3_ss_n,trig_ss_n,MOSI,SCLK,trig1,trig2,ch1_data,ch2_data,ch3_data);

  input clk,rst_n;									// clock and reset
  input ch1_ss_n,ch2_ss_n,ch3_ss_n,trig_ss_n;		// slave selects for digital pots
  input MOSI,SCLK;									// SPI signals from master
  input adc_clk;									// clock to A2D

  output trig1,trig2;								// trigger outputs
  output [7:0] ch1_data,ch2_data,ch3_data;			// represents the output of the A2D converter

  reg signed [7:0]ch1_raw[0:255];					// memory array to hold analog data for ch1, read from ch1_analog.hex
  reg signed [7:0]ch2_raw[0:255];					// memory array to hold analog data for ch2, read from ch2_analog.hex
  reg signed [7:0]ch3_raw[0:255];					// memory array to hold analog data for ch3, read from ch3_analog.hex
  
  reg [7:0] cnt;

  wire [7:0] ch1_gain0,ch1_gain1;
  wire [7:0] ch2_gain0,ch2_gain1;
  wire [7:0] ch3_gain0,ch3_gain1;
  wire [7:0] trig1_lvl,trig2_lvl;
  
  wire signed [13:0] ch1_product,ch2_product,ch3_product;	// raw analog value times the gain factor

  /// CH1 Digital Pot for configuring gain ///
  dig_pot POT1(.clk(clk), .rst_n(rst_n), .MOSI(MOSI), .SCLK(SCLK), .SS(ch1_ss_n), .wipe_0(ch1_gain0), .wipe_1(ch1_gain1));

  always @(ch1_gain0,ch1_gain1)
    if (ch1_gain0!=ch1_gain1)
      begin
	    $display("ERROR: wiper 0 and wiper 1 of ch1 gain pot not equal\n");
	    $finish();
	  end

  /// CH2 Digital Pot for configuring gain ///
  dig_pot POT2(.clk(clk), .rst_n(rst_n), .MOSI(MOSI), .SCLK(SCLK), .SS(ch2_ss_n), .wipe_0(ch2_gain0), .wipe_1(ch2_gain1));

  always @(ch2_gain0,ch2_gain1)
    if (ch2_gain0!=ch2_gain1)
      begin
	    $display("ERROR: wiper 0 and wiper 1 of ch2 gain pot not equal\n");
	    $finish();
	  end	
	
  /// CH3 Digital Pot for configuring gain ///
  dig_pot POT3(.clk(clk), .rst_n(rst_n), .MOSI(MOSI), .SCLK(SCLK), .SS(ch3_ss_n), .wipe_0(ch3_gain0), .wipe_1(ch3_gain1));

  always @(ch3_gain0,ch3_gain1)
    if (ch3_gain0!=ch3_gain1)
      begin
	    $display("ERROR: wiper 0 and wiper 1 of ch3 gain pot not equal\n");
	    $finish();
	  end	
	
  /// Trigger Level Digital Pot  ///
  dig_pot POT4(.clk(clk), .rst_n(rst_n), .MOSI(MOSI), .SCLK(SCLK), .SS(trig_ss_n), .wipe_0(trig1_lvl), .wipe_1(trig2_lvl));

  //////////////////////////////////////////////////////////////
  // counter that sequences through analog samples from file //
  ////////////////////////////////////////////////////////////
  always @(posedge adc_clk, negedge rst_n)
    if (!rst_n)
	  cnt <= 8'h00;
	else
	  cnt <= cnt+1;

  /////////////////////////////////////////////////////////////////
  // Model amplification of raw data, plus A2D cast to unsigned //
  ///////////////////////////////////////////////////////////////
  assign ch1_product = ch1_raw[cnt]*$signed((ch1_gain0>>2)+1);
  assign ch2_product = ch2_raw[cnt]*$signed((ch2_gain0>>2)+1);
  assign ch3_product = ch3_raw[cnt]*$signed((ch3_gain0>>2)+1);
  assign ch1_data = ch1_product[13:6]+8'h80;
  assign ch2_data = ch2_product[13:6]+8'h80;
  assign ch3_data = ch3_product[13:6]+8'h80;
  
  assign trig1 = (ch1_data>trig1_lvl) ? 1'b1 : 1'b0;
  assign trig2 = (ch2_data>trig2_lvl) ? 1'b1 : 1'b0; 
  
  ////////////////////////////////////////////////////////////////////
  // Read a periodic set of analog data for each channel from file //
  //////////////////////////////////////////////////////////////////
  initial  begin
    $readmemh("ch1_analog.hex",ch1_raw);
	$readmemh("ch2_analog.hex",ch2_raw);
    $readmemh("ch3_analog.hex",ch3_raw);
  end
	
	
endmodule