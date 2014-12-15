module Command_Config(clk, rst_n, SPI_done, EEP_data, cmd, cmd_rdy, resp_sent, RAM_rdata,
                      SPI_data, wrt_SPI, ss, clr_cmd_rdy, resp_data, send_resp, trig_pos,
					  trig_cfg, decimator, dump, dump_ch, set_capture_done, ch1_AFEgain,
                      ch2_AFEgain, ch3_AFEgain, flopGain, flopOffset);
  ////////////////////////////////////////////////////////////////
  //This module reads in commands and controls rclk and adc_clk//
  //////////////////////////////////////////////////////////////
  input clk, rst_n, SPI_done, cmd_rdy, resp_sent;
  input [7:0] EEP_data, RAM_rdata;
  input [23:0] cmd;
  input set_capture_done;
  input flopGain, flopOffset; //Signals to flop the offset or gain from the EEPROM during Dump

  output logic wrt_SPI, clr_cmd_rdy, send_resp;
  output logic [2:0] ss;
  output logic [7:0] resp_data;
  output logic [8:0] trig_pos;
  output logic [15:0] SPI_data;
  output logic [7:0] trig_cfg;
  output logic [3:0] decimator;
  output logic [1:0] dump_ch;
  output logic dump;
  output logic [2:0] ch1_AFEgain, ch2_AFEgain, ch3_AFEgain;
  logic [7:0] offset, gain;

  logic set_command;
  logic [23:0] command;
  logic [15:0] AFEgainSPI; //Serves as the output of a LUT for the possible gain settings
  logic wrt_trig_cfg;
  logic flopAFEgain, flopDec;
  logic [7:0] correctedRAM;

  Gain_Corrector iCorrector(.raw(RAM_rdata), .offset(offset), .gain(gain), .corrected(correctedRAM));

  assign capture_done = trig_cfg[5];

  typedef enum logic [2:0] { IDLE, CMD, SPI, RD_EEP, UART } state_t;
  state_t currentState, nextState;

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

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ////////////////////////////////////////
  // 4-bit Decimator Flop.             //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      decimator <= 4'b0000;
    else if(flopDec)
      decimator <= command[3:0];
    else
      decimator <= decimator;
  end
  
   ///////////////////////////////////////
  // 3x 3-bit AFEgain registers.       //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      ch1_AFEgain <= 3'b000;
      ch2_AFEgain <= 3'b000;
      ch3_AFEgain <= 3'b000;
    end else if(flopAFEgain) begin
      case(command[9:8])
        2'b00: begin
          ch1_AFEgain <= command[12:10];
          ch2_AFEgain <= ch2_AFEgain;
          ch3_AFEgain <= ch3_AFEgain;
        end
        2'b01: begin
          ch1_AFEgain <= command[12:10];
          ch2_AFEgain <= ch2_AFEgain;
          ch3_AFEgain <= ch3_AFEgain;
	end
        2'b10: begin
          ch1_AFEgain <= command[12:10];
          ch2_AFEgain <= ch2_AFEgain;
          ch3_AFEgain <= ch3_AFEgain;
	  end
	default: begin
          ch1_AFEgain <= ch1_AFEgain;
          ch2_AFEgain <= ch2_AFEgain;
          ch3_AFEgain <= ch3_AFEgain;			
	end
      endcase
    end else begin
      ch1_AFEgain <= ch1_AFEgain;
      ch2_AFEgain <= ch2_AFEgain;
      ch3_AFEgain <= ch3_AFEgain;
    end
  end
  
   /////////////////////////////////////////
  // 8-bit gain register for use in dump //
  ////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      gain <= 8'h00;
    else if(flopGain)
      gain <= EEP_data;
    else
      gain <= gain;
  end

   ///////////////////////////////////////////
  // 8-bit offset register for use in dump //
  //////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      offset <= 8'h00;
    else if(flopGain)
      offset <= EEP_data;
    else
      offset <= offset;
  end

  ///////////////////////////////////////////////////////
  //Flop the relevant bits of the command when moving //
  //into command mode from IDLE.                     //
  ////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      command <= 20'h00000;
    end else if(set_command)
      command <= cmd[23:0];
  end

  //////////////////////////////////////////////////////
  //trig_cfg FlipFlop.                               //
  ////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      trig_cfg <= 8'h00;
    else if(set_capture_done)
      trig_cfg <= {2'b00, 1'b1, trig_cfg[4:0]};
    else if(wrt_trig_cfg)
      trig_cfg <= {2'b00, command[13:8]};
    else
      trig_cfg <= trig_cfg;
  end

  //////////////////////////////////////////////////////////////////////
  //Our wonderful state machine.  CMD is a one cycle command         //
  //decode state.  SPI waits for the spi transaction to complete    //
  //and UART is a place holder for when the full API is implemented//
  //////////////////////////////////////////////////////////////////
  always @(*) begin
    //Default output values
    set_command = 0;
    clr_cmd_rdy = 0;
    wrt_SPI = 0;
    send_resp = 0;
    wrt_trig_cfg = 0;
    flopAFEgain = 0;
    flopDec = 0;
    case(currentState)
      IDLE: if(cmd_rdy) begin
          nextState = CMD;
          resp_data = correctedRAM;
          SPI_data = 16'h0000;
          ss = 3'b000;
          set_command = 1;
          dump = 0;
          dump_ch = 2'b00;
        end else begin
          nextState = IDLE;
        end
      CMD: if(command[23:16] == DUMP_CH) begin
          // Dump channel command. Channel to dump to UART is specified in the lower 2-bits
          // of the 2ndbyte.
          // cc=00 implies channel 1, cc=10 implies channel 3. and cc=11 is reserved
          dump = 1;
          dump_ch = command[9:8];
          clr_cmd_rdy = 1;
          nextState = IDLE;
        end else if(command[23:16] == CFG_GAIN) begin
          // Configure analog gain of channel (this would correspond to volts/div on an opamp).
          // Channel to set gain on is specified in lower 2-bits of the 2ndbyte (cc).
          // 3-bit registers storing the current gain for each will be used for accessing the
          // proper calibration coefficients from EEPROM.
          // <DONE>
          nextState = SPI;
          wrt_SPI = 1;
          ss = {1'b0,command[9:8]};
          SPI_data = AFEgainSPI;
		  flopAFEgain = 1;
        end else if((command[23:16] == TRIG_LVL) && (command[7:0] >= 46) && (command[7:0] <= 201)) begin
          // Set trigger level. This command is used to set the trigger level.
          // The value in the 3rdbyte (8’hLL) determines the trigger level.
          // Only values between 46 and 201 are valid.
          // <DONE>
          nextState = SPI;
          wrt_SPI = 1;
          ss = 3'b000;
          SPI_data = {8'h13,command[7:0]};
        end else if(command[23:16] == TRIG_POS) begin
          // Write the trigger position register.
          // Determines how many samples to capture after the trigger occurs.
          // This is a 9-bit value <DONE>
          trig_pos = command[8:0];
          resp_data = 8'hA5;
          send_resp = 1;
          nextState = UART;
        end else if(command[23:16] == SET_DEC) begin
          // Set decimator (essentially the sample rate).
          // A 4-bit value is specified in bits[3:0] of the 3rd byte.
          // <DONE>
          flopDec = 1;
          resp_data = 8'hA5;
          send_resp = 1;
          nextState = UART;
        end else if(command[23:16] == TRIG_CFG) begin
          // Write trig_cfg register. This command is used to clear the capture_donebit (bit[5] = d).
          // This command is also used to configure the trigger parameters (edge, trigger type, channel)
          // <DONE>
          wrt_trig_cfg = 1;
          resp_data = 8'hA5;
          send_resp = 1;
          nextState = UART;
        end else if(command[23:16] == TRIG_RD) begin
          // Read trig_cfg register. The trig_cfg register is sent out the UART.
          // <DONE>
          nextState = UART;
          send_resp = 1;
          resp_data = trig_cfg;
        end else if(command[23:16] == EEP_WRT) begin
          // Write location specified by 6-bit address of calibration EEPROM with data
          // specified in the 3rdbyte.
          // <DONE>
          nextState = SPI;
          wrt_SPI = 1;
          ss = 3'b100;
          SPI_data = {2'b01, command[13:0]};
        end else if(command[23:16] == EEP_RD) begin
          // Read calibration EEPROM location specified by 6-bit address.
          // <DONE>
          nextState = RD_EEP;
          wrt_SPI = 1;
          ss = 3'b100;
          SPI_data = {2'b00, command[13:0]};
        end else begin
          // Failed response
          // <DONE>
          resp_data = 8'hEE;
          send_resp = 1;
          nextState = UART;
        end
      RD_EEP : if(SPI_done) begin
            wrt_SPI = 1;
            SPI_data = {16'hbcbc};
            nextState = SPI;
        end else
            nextState = RD_EEP;
      SPI: if(SPI_done) begin
          nextState = UART;
          send_resp = 1;
          if(!SPI_data[14] && ss[2]) // Send calibration EEPROM data
            resp_data = EEP_data;
          else // Sent SPI, indicate positive response
            resp_data = 8'hA5;
        end else
          nextState = SPI;

      UART: if(resp_sent) begin
           nextState = IDLE;
           clr_cmd_rdy = 1;
        end else
           nextState = UART;
      default: ;
    endcase
    
  end

  always @(*)begin
    case(command[12:10])
      3'b000: AFEgainSPI = 16'h1302;
      3'b001: AFEgainSPI = 16'h1305;
      3'b010: AFEgainSPI = 16'h1309;
      3'b011: AFEgainSPI = 16'h1314;
      3'b100: AFEgainSPI = 16'h1328;
      3'b101: AFEgainSPI = 16'h1346;
      3'b110: AFEgainSPI = 16'h136B; 
      3'b111: AFEgainSPI = 16'h13DD;
    endcase

  end


endmodule
