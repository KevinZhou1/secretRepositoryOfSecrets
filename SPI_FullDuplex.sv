///////////////////////////////////////////////////////////////////////////////////////////////////
//Full-Duplex SPI Master for HW4 Problem 3                                                      //
//                                                                                             //
//Interface Inputs:                                                                           //
//  clk -- The clock, nothing complicated here.                                              //
//  rst_n -- Active low asynchronous reset.                                                 //
//  wrt -- Synchronous start of SPI communication.                                         //
//  MISO -- The master-in slave-out line from the slaves.                                 //
//  cmd -- The command for the master to write out to the slave.                         //
//                                                                                      //
//Interface Outputs:                                                                   //
//  SCLK -- The SPI clock, runs at 1/32 the clk input.                                //
//  SS_n -- Active low signal to the slave that a command is starting.               //
//          OR gates for specific slaves in higher level control logic?             //
//  done -- Signal that command write is completed.                                //
//  MOSI -- The master-out slave-in line to the slaves.                           //
//  SPI_data_out --  The data received from the slave during the command write.  //
//////////////////////////////////////////////////////////////////////////////////
module SPI_Master(clk, rst_n, cmd, wrt, MISO, SCLK, MOSI, SS_n, done, SPI_data_out);

  typedef enum logic [1:0] {IDLE, TX, BP1, BP2} state_t;
  
  input clk, rst_n, wrt, MISO;
  input [15:0] cmd;
  output logic SCLK, SS_n, done, MOSI;
  output logic [15:0] SPI_data_out;
  logic MISO_FF1, MISO_FF2;
  logic [4:0] SCLK_cnt;
  logic [3:0] pulse_cnt;
  logic [15:0] TX_REG;//, RX_REG;


  reg done_pff; // done before flip flop
  state_t currentState, nextState;

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ///////////////////////////////////////
  //Stability flopping of MISO input. //
  /////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      MISO_FF1 <= 1'b0;
      MISO_FF2 <= 1'b0;
    end else begin
      MISO_FF1 <= MISO;
      MISO_FF2 <= MISO_FF1; 
    end
  end

  /////////////////////////////////////////////////////////////////////
  //The following is my transmit shift register.  Reset is redundant//
  //, but I like having it.  Flops in the cmd value on the IDLE to //
  //TX transition.  Shifts a zero in from the right as SCLK is    //
  //falling.  Maintains value otherwise.                         //
  ////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      TX_REG <= 16'h0000;
    else if((currentState == IDLE)&&wrt)
      TX_REG <= cmd;
    else if((currentState == TX)&&(&SCLK_cnt))
      TX_REG <= {TX_REG[14:0],MISO_FF2};
    else
      TX_REG <= TX_REG;
  end

  /*////////////////////////////////////////////////////////////////////
  //The following is my receive shift register.  Reset is redundant //
  //, but I like having it. Shifts MISO in from the right as SCLK  //
  //is falling.  Maintains value otherwise.                       //
  /////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      RX_REG <= 16'h0000;
    else if((currentState == TX)&&(&SCLK_cnt))
      RX_REG <= {RX_REG[14:0],MISO_FF2};
    else
      RX_REG <= RX_REG;
  end*/
  
  ////////////////////////////////////////////////////////////////////
  //Following code is for the counter that counts up to 32 for SCLK//
  //Should be zero when outside of TX and BP1. Should not get high//
  //enough in BP1 to set SCLK.  Just counting for a short delay  //
  //before moving to BP2.                                       //
  ///////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      SCLK_cnt <= 5'b00000;
    else if(currentState == TX || currentState == BP1)
      SCLK_cnt <= SCLK_cnt + 1;
    else
      SCLK_cnt <= 5'b00000;
  end

  /////////////////////////////////////////////////////////////////
  //Following code is for the counter that counts up the 16 SCLK//
  //pulses.                                                    //
  //////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      pulse_cnt <= 4'b0000;
    else if(&SCLK_cnt)
      pulse_cnt <= pulse_cnt + 1;
    else if(currentState == IDLE)
      pulse_cnt <= 4'b0000;
    else
      pulse_cnt <= pulse_cnt;
  end

  always_ff @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        done <= 1'b0;
    else
        done <= done_pff;
  end
  /////////////////////////////////////////////////////////////////
  //Our wonderful state machine.  BP1 and BP2 are 'back porch'  //
  //states that are there to assist in clean-up of SCLK pulses //
  //16 times.                                                 //
  /////////////////////////////////////////////////////////////
  always @(*) begin
    //Default output values
    SS_n = 1;
    SCLK = SCLK_cnt[4];
    done_pff = 0;
    nextState = IDLE;
    MOSI = TX_REG[15];
    SPI_data_out = TX_REG;

    //All possible cases enumerated, no need for a default case.
    case(currentState)
      IDLE: if(wrt)
          nextState = TX;
        else
          nextState = IDLE;
      TX: if((&pulse_cnt)&(&SCLK_cnt))begin
          SS_n = 0;
          nextState = BP1;
        end else begin
          SS_n = 0;
          nextState = TX;
        end
      BP1: if(&(SCLK_cnt[2:0]))begin
          nextState = BP2;
        end else begin
          SS_n = 0;
          nextState = BP1;
        end
      BP2: begin
        done_pff = 1;
        nextState = IDLE;
        end
    endcase
    
  end

endmodule


/*//////////////////////////////////////////////////////////////////////////////////////////////////
//Full-Duplex SPI Slave for HW4 Problem 3                                                       //
//                                                                                             //
//Interface Inputs:                                                                           //
//  clk -- The clock, nothing complicated here.                                              //
//  rst_n -- Active low asynchronous reset.                                                 //
//  SCLK -- The SPI clock from the master.  Expected 1/32 clk.                             //
//  MOSI -- The master-out slave-in line from the master.                                 //
//  SS_n -- Active low signal that a command write to this slave is starting.            //
//  SPI_slave_out -- The data to write out on MISO during the command from the master.  //
//                                                                                     //
//Interface Outputs:                                                                  //
//  cmd_rdy -- Signal that the command write has completed and that                  //
//             the command data is valid.                                           //
//  MISO -- The master-in slave-out line to the master.                            //
//  cmd -- The command data that was written by the Master.                       //
///////////////////////////////////////////////////////////////////////////////////
module SPI_Slave(clk, rst_n, cmd, cmd_rdy, MISO, SCLK, MOSI, SS_n, SPI_slave_out);

  typedef enum logic [1:0] {IDLE, RX, BP1, BP2} state_t;

  input clk, rst_n, SCLK, MOSI, SS_n;
  input [15:0] SPI_slave_out;
  output logic cmd_rdy, MISO;
  output logic [15:0]cmd;

  logic SCLK_FF1, SCLK_FF2, SCLK_FF3;
  logic MOSI_FF1, MOSI_FF2, MOSI_FF3;
  logic SS_n_FF1, SS_n_FF2;
  logic [3:0]bit_cnt;
  logic neg_SCLK;
  logic [15:0]RX_REG, TX_REG;

  state_t currentState, nextState;

  ////////////////////////////////////////
  // Following code is the state flops //
  //////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      currentState <= IDLE;
    else
      currentState <= nextState;
  end

  ////////////////////////////////////////////////////
  //Stability flopping of inputs.  Additional flop //
  //stage for negedge detection on SCLK and logic.//
  /////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n) begin
      SCLK_FF1 <= 1'b0;
      SCLK_FF2 <= 1'b0;
      SCLK_FF3 <= 1'b0;
      MOSI_FF1 <= 1'b0;
      MOSI_FF2 <= 1'b0;
      MOSI_FF3 <= 1'b0;
      SS_n_FF1 <= 1'b1;
      SS_n_FF2 <= 1'b1;
    end else begin
      SCLK_FF1 <= SCLK;
      SCLK_FF2 <= SCLK_FF1;
      SCLK_FF3 <= SCLK_FF2;
      MOSI_FF1 <= MOSI;
      MOSI_FF2 <= MOSI_FF1;
      MOSI_FF3 <= MOSI_FF2;
      SS_n_FF1 <= SS_n;
      SS_n_FF2 <= SS_n_FF1;  
    end
  end

  /////////////////////////////////////////////////////////////////
  //Following code is for the counter that counts up the 16 MOSI//
  //received bits.                                             //
  //////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      bit_cnt <= 4'b0000;
    else if(neg_SCLK)
      bit_cnt <= bit_cnt + 1;
    else if(currentState == IDLE)
      bit_cnt <= 4'b0000;
    else
      bit_cnt <= bit_cnt;
  end

  /////////////////////////////////////////////////////////////////////
  //The following is my receive shift register.  Reset is redundant //
  //, but I like having it.  Flops in the cmd value on the IDLE to //
  //TX transition.  Shifts a zero in from the right as SCLK is    //
  //falling.  Maintains value otherwise.                         //
  ////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      RX_REG <= 16'h0000;
    else if((currentState == RX)&&(neg_SCLK))
      RX_REG <= {RX_REG[14:0],MOSI_FF3};
    else
      RX_REG <= RX_REG;
  end

  /////////////////////////////////////////////////////////////////////
  //The following is my transmit shift register.  Reset is redundant//
  //, but I like having it.  Flops in the cmd value on the IDLE to //
  //TX transition.  Shifts a zero in from the right as SCLK is    //
  //falling.  Maintains value otherwise.                         //
  ////////////////////////////////////////////////////////////////
  always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
      TX_REG <= 16'h0000;
    else if(currentState == IDLE)
      TX_REG <= SPI_slave_out;
    else if((currentState == RX)&&(neg_SCLK))
      TX_REG <= {TX_REG[14:0],1'b0};
    else
      TX_REG <= TX_REG;
  end

  /////////////////////////////////////////////////////////////////
  //Our wonderful state machine.  BP1 is a holding state that   //
  //waits for SS_n_FF2 to go high before returning to IDLE.    //
  //////////////////////////////////////////////////////////////
  always @(*) begin
    //Default output values
    cmd_rdy = 0;
    cmd = RX_REG;
    neg_SCLK = SCLK_FF3&(~SCLK_FF2);

    //MISO is HiZ when the chip select is high to avoid bus contention with other slaves.
    //Not sure if I should use the flopped SS_n or not, but I want to yield the line 
    //immediately on SS_n going high to avoid contention.
    MISO = (SS_n) ? 1'bz : TX_REG[15];

    case(currentState)
      IDLE: if(~SS_n_FF2) begin
          nextState = RX;
        end else begin
          cmd_rdy = 1;
          nextState = IDLE;
        end
      RX: if(~neg_SCLK)begin
          nextState = RX;
        end else if(neg_SCLK && ~&bit_cnt) begin
          nextState = RX;
        end else begin
          nextState = BP1;
        end
      BP1: if(SS_n_FF2)
          nextState = IDLE;
        else
          nextState = BP1;
      default:
        nextState = IDLE;
    endcase
    
  end

endmodule
*/


/*//////////////////////////////////////////////////////////////////////////////////
//Simple test bench that initiates 2 wrt series with cmd values for comparison.  //
//////////////////////////////////////////////////////////////////////////////////
module SPI_Master_Slave_tb();

  logic clk, rst_n, wrt, SCLK, MOSI, SS_n, done, MISO;
  logic [15:0]cmd, cmd_s, SPI_data_out, SPI_slave_out;
  SPI_Master iDUT(clk, rst_n, cmd, wrt, MISO, SCLK, MOSI, SS_n, done, SPI_data_out);
  SPI_Slave iDUT2(clk, rst_n, cmd_s, cmd_rdy, MISO, SCLK, MOSI, SS_n, SPI_slave_out);

  always
    #5 clk = ~clk;

  initial begin
    
    ////////////////////////////////////////////////////////
    //Initialization block.                              //
    //Reset states, setup clock, initialize wrt signal. //
    /////////////////////////////////////////////////////
    rst_n = 0;
    clk = 1;
    wrt = 0;

    /////////////////////////////////////////////////
    //Test command block one:                     //
    //    Master Command:	16'h70C3         //
    //    Slave Command:	16'h12EF        //
    //                                         //
    //Expected outputs at done:               //
    //    SPI_data_out:		16'h12EF     //
    //    cmd_s:		16'h70C3    //
    /////////////////////////////////////////

    cmd = 16'h70C3;
    SPI_slave_out = 16'h12EF;
    #500;
    @(negedge clk);
    rst_n = 1;
    wrt = 1;
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    @(negedge clk);
    wrt = 0;
    @(negedge done);
    if(cmd != cmd_s)
      $display("Error at time %0d, Slave's receive out is 0x%h, should be 0x%h.\n", $time, cmd_s, cmd);
    if(SPI_slave_out != SPI_data_out)
      $display("Error at time %0d, Master's receive out is 0x%h, should be 0x%h.\n", $time, SPI_data_out, SPI_slave_out);

    /////////////////////////////////////////////////
    //Test command block two:                     //
    //    Master Command:	16'hDEAD         //
    //    Slave Command:	16'hBEEF        //
    //                                         //
    //Expected outputs at done:               //
    //    SPI_data_out:		16'hBEEF     //
    //    cmd_s:		16'hDEAD    //
    /////////////////////////////////////////

    cmd = 16'hDEAD;
    SPI_slave_out = 16'hBEEF;
    wrt = 1;
    @(posedge clk);
    wrt = 0;
    @(negedge done);
    if(cmd != cmd_s)
      $display("Error at time %0d, Slave's receive out is 0x%h, should be 0x%h.\n", $time, cmd_s, cmd);
    if(SPI_slave_out != SPI_data_out)
      $display("Error at time %0d, Master's receive out is 0x%h, should be 0x%h.\n", $time, SPI_data_out, SPI_slave_out);
    #500;
    $stop;
  end
endmodule
*/
