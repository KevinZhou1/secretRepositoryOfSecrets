////////////////////////////////////////////////////////////////////////
//Gain correction module.  Pure combinational corection on data from //
// the RAM during a RAM dump command.                               //
/////////////////////////////////////////////////////////////////////
module Gain_Corrector(raw, offset, gain, corrected);

input [7:0] raw;	//Raw RAM Channel data to correct before sending it to the host
input [7:0] offset;	//Offset data from EEPROM
input [7:0] gain;	//Gain to apply from EEPROM.  0x80 is unity.

output [7:0] corrected;	//

wire [7:0] sum, sat_sum;
wire [15:0] prod, sat_prod;

//// add offset before saturation
assign sum = raw + offset;

/// Raw is unsigned and offset is signed. Saturate ///
assign sat_sum = 	(~offset[7] && raw[7] && ~sum[7])	?	8'hFF	:
			(offset[7] && ~raw[7] && sum[7])	?	8'h00	:	sum;

//Apply gain, 8 by 8 multiply
assign prod = sat_sum * gain;

// Saturate product down to 0x7FFF if needed.
assign sat_prod = (prod[15])	?	16'h7fff	:	prod;

// take the 7 bit rightshifted product, sans the top bit.
assign corrected = sat_prod[14:7];

endmodule
	  
