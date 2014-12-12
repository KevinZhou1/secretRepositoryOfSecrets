module dumpSM(clk, rst_n, rclk, addr, incAddr, channel, ch_sel, ch1_AFEGain, ch2_AFEGain, ch3_AFEGain, startDump, startUARTresp, startSPI, SPIrdy, UARTrdy, dumpDone, flopGain, flopOffset, spiTXdata);

  input clk, rst_n, rclk, startDump, SPIrdy, UARTrdy;
  //startDump, input to kick off dump SM
  //SPIrdy, input to tell the SM that the SPI is ready to transmit
  //UARTrdy, input to tell the SM that the UART is ready to transmit
  input [1:0] channel;
  //channel, What channel are we dumping?  Can be pulled from the host command
  input [2:0] ch1_AFEGain, ch2_AFEGain, ch3_AFEGain;
  //chX_AFEGain, outputs of the AFEGain state registers.  Used in forming EEPROM SPI commands.
  input [8:0] addr;
  //addr, The addr counter. Captured for comparison whech checking if we are done

  output logic startUARTresp, startSPI;
  //Outputs to kisck off UART and SPI transactions

  output logic dumpDone;
  //dumpDone, signal that the dump is complete
  output logic flopGain;
  output logic flopOffset;
  //flopGain, flopOffset, Signals to the gain and offset registers that gain or offset is available on the SPI data out.
  output logic incAddr;
  //incAddr, signal to increment the address register
  output logic [1:0] ch_sel;  //Flops in the channel select.
  //ch_sel, flopped copy of which channel is being dumped, routed to the RAMInterface to select which RAM output we want.
  output logic [15:0] spiTXdata;
  //spiTXdata, the SPI command for the EEPROM

  logic [2:0] ggg;        //The gain code of the channel selected for dumping.  Used to construct spiTXdata.
  logic [8:0] startAddr;  //Captures the starting addr at begining for comparison.
  
  logic flopIn;  //Signal from SM to capture the addr and channel values.
  
  typedef enum reg [3:0] { IDLE, READGAIN, READOFFSET, READJUNK, EEPROMWAIT, UARTSEND, INC, CHECK, DONE} state_t; 
  state_t currentState, nextState;   // State registers

  assign ggg =	(ch_sel == 2'b00)	?	ch1_AFEGain	:
		(ch_sel == 2'b01)	?	ch2_AFEGain	:
		(ch_sel == 2'b10)	?	ch3_AFEGain	:
               	3'b000;
		

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ////////////////////////////////////////////////////////////////
  //Flop to capture the channel on an incoming dump CMD.       //
  //////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      ch_sel <= 2'b00;
    else if(flopIn)
      ch_sel <= channel;
    else
      ch_sel <= ch_sel;
  end

  ////////////////////////////////////////////////////////////////////
  //Flop to capture the starting address on an incoming dump CMD.  //
  //////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      startAddr <= 9'b000000000;
    else if(flopIn)
      startAddr <= addr;
    else
      startAddr <= startAddr;
  end


  /////////////////////////////////////////////////////////////////
  //Our wonderful state machine.                                //
  //////////////////////////////////////////////////////////////
  always @(*) begin
  //Default state output values.
    flopIn = 0;
    startUARTresp = 0;
    dumpDone = 0;
    flopGain = 0;
    flopOffset = 0;
    incAddr = 0;
    startSPI = 0;
    spiTXdata = 16'h0000;
    
    case(currentState)
      IDLE: if(startDump) begin
        nextState = READGAIN;
        flopIn = 1;
      end else
        nextState = IDLE;
      READGAIN: begin
        spiTXdata = {2'b00, ch_sel, ggg, 9'b1_0000_0000};
        startSPI = 1;
        nextState = READOFFSET;
      end
      READOFFSET: if(~SPIrdy)
        nextState = READOFFSET;
      else begin
        spiTXdata = {2'b00, ch_sel, ggg, 9'b0_0000_0000};
        startSPI = 1;
        nextState = READJUNK;
      end
      READJUNK: if(~SPIrdy)
        nextState = READJUNK;
      else begin
        flopGain = 1;
        spiTXdata = {2'b00, ch_sel, ggg, 9'b0_0000_0000};
        startSPI = 1;
        nextState = EEPROMWAIT;
      end
      EEPROMWAIT: if(~SPIrdy)
        nextState = EEPROMWAIT;
      else begin
        flopOffset = 1;
        nextState = UARTSEND;
      end
      UARTSEND:  if(~UARTrdy)
        nextState = UARTSEND;
      else begin
        nextState = INC;
        startUARTresp = 1;
      end
      INC: begin
        incAddr = 1;
        nextState = CHECK;
      end
      CHECK: if(addr == startAddr) begin
        nextState = DONE;
      end else
        nextState = UARTSEND;
      DONE:  if(~UARTrdy)
        nextState = DONE;
      else begin
        nextState = IDLE;
        dumpDone = 1;
      end
      default:
        nextState = IDLE;
    endcase
    
  end



endmodule
