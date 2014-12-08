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
  output adc_clk,rclk;							// 20MHz clocks to ADC and RAM
  input trig1,trig2;							// trigger inputs from AFE
  // EEPROM SPI control signals
  output [15:0] SPI_data;						// typically a config command to digital pots or EEPROM
  output wrt_SPI;								// control signal asserted for 1 clock to initiate SPI transaction
  output [2:0] ss;								// determines which Slave gets selected 000=>trig, 001-011=>chX_ss, 100=>EEP
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
  wire trig_en; //Enable signal from Command to Capture
  wire capture_done; //Signal from capture module that it has triggered and capture is complete
  wire clr_cap_done; //Signal to clear current capture status on the Capture module
  wire [8:0]addr_ptr; //Current address from the Capture module
  wire [8:0]trig_pos; //The trigger position from the CNC to the Capture
  wire [7:0]RAM_rdata; //Data from RAM Interface to CNC
  wire [7:0]trig_cfg;
 
  ///////////////////////////////////////////////////////
  // Instantiate the blocks of your digital core next //
  /////////////////////////////////////////////////////
  
  ADC_Capture iADC_Cap(.clk(clk), .rst_n(rst_n), .trig1(trig1), .trig2(trig2), .trig_en(trig_en), .trig_pos(trig_pos), .clr_cap_done(clr_cap_done), .addr_ptr(addr_ptr), .capture_done(capture_done));


  RAM_Interface iRAM_Int(.clk(clk), .rst_n(rst_n), .ch1_rdata(ch1_rdata), .ch2_rdata(ch2_rdata), .ch3_rdata(ch3_rdata), .addr_ptr(addr_ptr),
                         .capture_done(capture_done), .en(en), .we(we), .addr(addr), .RAM_rdata(RAM_rdata));


  Command_Config iCNC(.clk(clk), .rst_n(rst_n), .SPI_done(SPI_done), .EEP_data(EEP_data), .cmd(cmd), .cmd_rdy(cmd_rdy), .resp_sent(resp_sent),
                      .capture_done(capture_done), .RAM_rdata(RAM_rdata), .adc_clk(adc_clk), .rclk(rclk), .SPI_data(SPI_data), .wrt_SPI(wrt_SPI),
					  .ss(ss), .clr_cmd_rdy(clr_cmd_rdy), .resp_data(resp_data), .send_resp(send_resp), .trig_pos(trig_pos),
					  .clr_cap_done(clr_cap_done), .trig_en(trig_en), .trig_cfg(trig_cfg));
  
  
endmodule

module ADC_Capture(clk, rst_n, trig1, trig2, trig_en, trig_pos, clr_cap_done, addr_ptr, capture_done);
  /////////////////////////////////////////////////////////////////
  //This module controls the flow of data capture from the ADCs.//
  //Contains arming logic that determines if it can trigger.   //
  //May also end up controlling channel dumps.                //
  /////////////////////////////////////////////////////////////
  input clk, rst_n;
  input trig1, trig2;
  input trig_en;
  input [8:0] trig_pos;
  input clr_cap_done;
  input [4:0] decimator;
  output logic [8:0] addr_ptr;
  output capture_done;
  
  typedef enum logic [2:0] { IDLE, WRT, SMPL, TRIG, DONE } state_t;
  state_t currentState, nextState;
  
  logic clr_cnt;
  wire [3:0] smpl_cnt, trig_cnt;
  wire en_smpl_cnt, en_trig_cnt;
  logic armed;
  wire [7:0] trace_end;
  
  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ///////////////////////
  // Control smpl_cnt //
  /////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      smpl_cnt <= 4'h0;
    end else if(clr_cnt)
      smpl_cnt <= 4'h0;
    end else if(en_smpl_cnt)
      smpl_cnt <= smpl_cnt + 1;
  end

  ///////////////////////
  // Control trig_cnt //
  /////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      trig_cnt <= 4'h0;
    else if(clr_cnt)
      trig_cnt <= 4'h0;
    else if(en_trig_cnt)
      trig_cnt <= trig_cnt + 1;
  end
  
  always_comb begin
    addr_ptr = 9'h000;
    clr_cnt = 1'b0;
    en_trig_cnt = 1'b0;
    en_smpl_cnt = 1'b0;
    armed = 1'b0;
    nextState = IDLE;
    case(currentState)
      IDLE : 
        if(trig_en) begin
          nextState = WRT;
          clr_cnt = 1;
        end
      WRT : 
        if(trig1 || trig2) begin
          nextState = TRIG;
          en_trig_cnt = 1;
        end
        else begin
          nextState = SMPL;
          en_smpl_cnt = 1;
        end
      SMPL :
        nextState = WRT;
        if(smpl_cnt + trig_pos == 512) begin
          armed = 1; // Currently 1-clock cycle armed signal
        end
      TRIG :
        if(trig_cnt == trig_pos) begin
          nextState = DONE;
          capture_done = 1;
          trace_end = addr_ptr;
        end else
          nextState = WRT;
      DONE :
        if(capture_done)
          nextState = DONE;
        else begin
          nextState = IDLE;
          armed = 0;
        end
      endcase
  end
endmodule


module RAM_Interface(clk, rst_n, ch1_rdata, ch2_rdata, ch3_rdata, addr_ptr, capture_done, en, we, addr, RAM_rdata);
  //////////////////////////////////////////////////////////////
  //Control of the commands to the RAM blocks that record and//
  //return ADC data.                                        //
  ///////////////////////////////////////////////////////////
  input clk, rst_n;
  input [7:0] ch1_rdata, ch2_rdata, ch3_rdata;
  input [8:0] addr_ptr;
  input capture_done;
  output en, we;
  output [8:0] addr;
  output [7:0] RAM_rdata;
  
endmodule


module Command_Config(clk, rst_n, SPI_done, EEP_data, cmd, cmd_rdy, resp_sent, capture_done, RAM_rdata,
                      adc_clk, rclk, SPI_data, wrt_SPI, ss, clr_cmd_rdy, resp_data, send_resp, trig_pos,
					  clr_cap_done, trig_en, trig_cfg,);
  input clk, rst_n, SPI_done, cmd_rdy, capture_done, resp_sent;
  input [7:0] EEP_data, RAM_rdata;
  input [23:0] cmd;

  output logic adc_clk, rclk, wrt_SPI, clr_cmd_rdy, send_resp, clr_cap_done, trig_en;
  output logic [2:0] ss;
  output logic [7:0] resp_data;
  output logic [8:0] trig_pos;
  output logic [15:0] SPI_data;
  output logic [7:0] trig_cfg;

  logic set_command;
  logic [23:0] command;
  logic [15:0] AFEgainSPI; //Serves as the output of a LUT for the possible gain settings

  typedef enum logic [1:0] { IDLE, CMD, SPI, UART } state_t;
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

assign adc_clk = ~rclk; // adc_clk and rclk in opposite phases

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ////////////////////////////////////////////////////////
  // Run rclk for interaction with channel RAM modules //
  //////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      rclk <= 1'b0;
    else
      rclk <= ~rclk;
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
    ss = 3'b000;
    SPI_data = 16'h0000;
    resp_data = 8'h00;
    send_resp = 0;
    case(currentState)
      IDLE: if(cmd_rdy) begin
          nextState = CMD;
          set_command = 1;
        end else begin
          nextState = IDLE;
        end
      CMD: if(command[23:16] == DUMP_CH) begin
          // Dump channel command. Channel to dump to UART is specified in the lower 2-bits
          // of the 2ndbyte.
          // cc=00 implies channel 1, cc=10 implies channel 3. and cc=11 is reserved
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
          nextState = IDLE;
        end else if(command[23:16] == SET_DEC) begin
          // Set decimator (essentially the sample rate).
          // A 4-bit value is specified in bits[3:0] of the 3rd byte.
        end else if(command[23:16] == TRIG_CFG) begin
          // Write trig_cfg register. This command is used to clear the capture_donebit (bit[5] = d).
          // This command is also used to configure the trigger parameters (edge, trigger type, channel)
          // <DONE>
          trig_cfg = {2'b00, command[13:8]};
          nextState = IDLE;
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
          nextState = SPI;
          wrt_SPI = 1;
          ss = 3'b100;
          SPI_data = {2'b00, command[13:0]};
        end else begin
          nextState = IDLE;
          clr_cmd_rdy = 1; //No valid command, clear command and return to IDLE
        end
      SPI: if(SPI_done) begin
          nextState = IDLE;
          clr_cmd_rdy = 1;  
        end else
          nextState = SPI;
      UART: if(resp_sent) begin
           nextState = IDLE;
           clr_cmd_rdy = 1;
        end else
           nextState = IDLE;
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

