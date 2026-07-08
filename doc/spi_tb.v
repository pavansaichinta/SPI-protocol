`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 20:21:28
// Design Name: 
// Module Name: spi_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module tb_spi_master;

    // Simulation Parameters
    parameter DATA_WIDTH = 8;
    parameter CLK_DIVIDE = 4;
    parameter CLK_PERIOD = 20; // 50 MHz System Clock

    // Configure Test Mode (Mode 0 standard for evaluation)
    parameter TEST_CPOL = 0; 
    parameter TEST_CPHA = 0;

    // Testbench Signals
    reg                  clk;
    reg                  rst_n;
    reg                  start;
    reg  [DATA_WIDTH-1:0] tx_data;
    wire [DATA_WIDTH-1:0] rx_data;
    wire                 ready;
    
    wire                 sclk;
    wire                 mosi;
    wire                 miso;
    wire                 cs_n;

    // Instantiate Unit Under Test (UUT)
    spi_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLK_DIVIDE(CLK_DIVIDE),
        .CPOL(TEST_CPOL),
        .CPHA(TEST_CPHA)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .ready(ready),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // Direct Loopback: Output ties back to Input
    assign miso = mosi;

    // Continuous Clock Generator (50 MHz)
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

  
  initial begin
        $dumpfile("spi_master_simulation.vcd");
        $dumpvars(0, tb_spi_master);
    end
  
  
    // Stimulus Engine
    initial begin
        // Initialize Inputs
        clk     = 0;
        rst_n   = 0;
        start   = 0;
        tx_data = 0;

        $display("[TB] Initiating System Reset...");
        #(CLK_PERIOD * 2);
        rst_n = 1; // Release Reset
        #(CLK_PERIOD * 2);
        $display("[TB] Reset Lifted. Operational Ready Signal: %b", ready);

        // --- TEST CASE 1: Payload 0x5A ---
        $display("\n--- Starting Test Case 1: Transmitting 0x5A ---");
        wait(ready == 1); 
        @(posedge clk);
        tx_data = 8'h5A; // Binary: 01011010
        start   = 1;     // Pulse Start Signal
        
        @(posedge clk);
        start   = 0;     // De-assert instantly on the next edge

        // Wait for the single-process FSM to shift, sample, and return to IDLE
        wait(ready == 1);
        #(CLK_PERIOD * 2); // Small settle buffer
        
        if (rx_data == 8'h5A) begin
            $display("[SUCCESS] Test Case 1 Passed! Received: 0x%h", rx_data);
        end else begin
            $display("[ERROR] Test Case 1 Mismatch! Sent: 0x5A, Received: 0x%h", rx_data);
        end


        // --- TEST CASE 2: Payload 0xF0 ---
       $display("\n--- Starting Test Case 2: Transmitting 0xF0 ---");
        wait(ready == 1);
        @(posedge clk);
        tx_data = 8'hF0; // Binary: 11110000
        start   = 1;
        
        @(posedge clk);
        start   = 0;

        wait(ready == 1);
        #(CLK_PERIOD * 2);
        
        if (rx_data == 8'hF0) begin
            $display("[SUCCESS] Test Case 2 Passed! Received: 0x%h", rx_data);
        end else begin
            $display("[ERROR] Test Case 2 Mismatch! Sent: 0xF0, Received: 0x%h", rx_data);
        end

        // End Traces
        $display("\n[TB] Verification Completed.");
        $finish;
    end

    // Real-time Console Monitor Output
    initial begin
        $monitor("Time=%0t ns | State=%b | CS_N=%b | SCLK=%b | MOSI=%b | MISO_SYNC=%b", 
                 $time, uut.state, cs_n, sclk, mosi, uut.miso_sync2);
    end

endmodule