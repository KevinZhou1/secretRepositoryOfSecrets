module dumpSM(clk, rst_n, rclk, addr, channel, ch_sel, startDump, startUARTresp, SPIrdy, dumpDone, flopGain, flopOffset);

  input clk, rst_n, rclk, startDump, SPIrdy;
  input [1:0] channel;
  input [7:0] addr;

  output logic startUARTresp;
  output logic dumpDone;
  output logic flopGain
  output logic flopOffset;
  output logic [1:0] ch_sel;  //Flops in the channel select.

  logic [8:0] startAddr;  //Captures the starting addr at begining for comparison.
  
  typedef enum reg [2:0] { IDLE, READGAIN, READOFFSET, READJUNK, READRAM1, UARTSEND, INC, CHECK, DONE} state_t; 
  state_t currentState, nextState;   // State registers

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end
  
  logic flopIn;

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
    
    case(currentState)
      IDLE: if(startDump) begin
        nextState = READGAIN;
        flopIn = 1;
      end else
        nextState = IDLE;
      default:
        nextState = IDLE;
    endcase
    
  end



endmodule
