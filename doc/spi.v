`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.06.2026 20:20:41
// Design Name: 
// Module Name: spi
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


`timescale 1ns / 1ps

module spi_master #(
    parameter DATA_WIDTH = 8,
    parameter CLK_DIVIDE = 4,     // System clock divider (even number >= 4)
    parameter CPOL       = 0,     // Clock Polarity (0: idle low, 1: idle high)
    parameter CPHA       = 0      // Clock Phase (0: sample on 1st edge, 1: sample on 2nd edge)
)(
    input  wire                  clk,       // High-speed system clock
    input  wire                  rst_n,     // Asynchronous active-low reset
    input  wire                  start,     // Pulse high to start transmission
    input  wire [DATA_WIDTH-1:0] tx_data,   // Parallel data payload to transmit
    output reg  [DATA_WIDTH-1:0] rx_data,   // Parallel data payload received
    output reg                  ready,     // High when module is ready for next frame
    
    // SPI Physical Pins
    output reg                  sclk,
    output reg                  mosi,
    input  wire                  miso,
    output reg                  cs_n
);

    // Single-Process FSM States
    localparam IDLE   = 2'b00;
    localparam START  = 2'b01;
    localparam TX_RX  = 2'b10;
    localparam END    = 2'b11;

    reg [1:0] state;
    
    // Internal Data & Counter Registers
    reg [DATA_WIDTH-1:0] shift_reg_tx;
    reg [DATA_WIDTH-1:0] shift_reg_rx;
    reg [7:0]            clk_cnt;
    reg [4:0]            bit_cnt;

    // 2-Stage Synchronizer Registers for MISO (Clock Domain Crossing Protection)
    reg miso_sync1, miso_sync2;

    // Derived Edge Conditions based on CPHA configuration
    wire sample_edge = (CPHA == 0) ? (clk_cnt == (CLK_DIVIDE/2) - 1) : (clk_cnt == CLK_DIVIDE - 1);
    wire shift_edge  = (CPHA == 0) ? (clk_cnt == CLK_DIVIDE - 1)      : (clk_cnt == (CLK_DIVIDE/2) - 1);

    // 1. MISO Metastability Synchronizer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miso_sync1 <= 1'b0;
            miso_sync2 <= 1'b0;
        end else begin
            miso_sync1 <= miso;
            miso_sync2 <= miso_sync1;
        end
    end

    // 2. Monolithic Single-Process FSM & Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            clk_cnt      <= 0;
            bit_cnt      <= 0;
            shift_reg_tx <= 0;
            shift_reg_rx <= 0;
            rx_data      <= 0;
            ready        <= 1'b1;
            cs_n         <= 1'b1;
            mosi         <= 1'b0;
            sclk         <= CPOL;
        end else begin
            
            // --- Clock Divider Counter Management ---
            if (state == IDLE) begin
                clk_cnt <= 0;
            end else begin
                if (clk_cnt == CLK_DIVIDE - 1) begin
                    clk_cnt <= 0;
                end else begin
                    clk_cnt <= clk_cnt + 1;
                end
            end

            // --- FSM State Transitions and Flag Outputs ---
            case (state)
                
                IDLE: begin
                    ready   <= 1'b1;
                    cs_n    <= 1'b1;
                    mosi    <= 1'b0;
                    sclk    <= CPOL;
                    bit_cnt <= 0;
                    
                    if (start) begin
                        shift_reg_tx <= tx_data;
                        ready        <= 1'b0;
                        state        <= START;
                    end
                end
                
                START: begin
                    cs_n <= 1'b0;
                    if (CPHA == 0) begin
                        mosi <= shift_reg_tx[DATA_WIDTH-1]; // Pre-drive MSB immediately
                    end
                    
                    if (clk_cnt == (CLK_DIVIDE/2) - 1) begin
                        state <= TX_RX;
                    end
                end
                
                TX_RX: begin
                    // SCLK Generation
                    if (clk_cnt == (CLK_DIVIDE/2) - 1)       sclk <= ~CPOL;
                    else if (clk_cnt == CLK_DIVIDE - 1) sclk <= CPOL;

                    // Handle edge driving requirement for CPHA=1 window
                    if (CPHA == 1 && bit_cnt == 0 && clk_cnt == 0) begin
                        mosi <= shift_reg_tx[DATA_WIDTH-1];
                    end

                    // Data Sampling (Capture incoming stabilized MISO line)
                    if (sample_edge) begin
                        shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso_sync2};
                    end
                    
                    // Data Shifting (Drive outgoing MOSI line)
                    if (shift_edge) begin
                        if (bit_cnt < DATA_WIDTH - 1) begin
                            mosi <= shift_reg_tx[DATA_WIDTH - 2 - bit_cnt];
                        end
                    end

                    // Counter updating & State Escape Condition
                    if (clk_cnt == CLK_DIVIDE - 1) begin
                        if (bit_cnt == DATA_WIDTH - 1) begin
                            state   <= END; // Transition to capture the lagging sync bit
                        end else begin
                            bit_cnt <= bit_cnt + 1;
                        end
                    end
                end
                
                END: begin
                    sclk <= CPOL; // Instantly ground SCLK to its designated idle level

                    // Crucial: Sample the 8th synchronized bit as it catches up through the pipeline
                    if (clk_cnt == 0) begin
                        shift_reg_rx <= {shift_reg_rx[DATA_WIDTH-2:0], miso_sync2};
                    end

                    // Complete full hold time requirement before returning to IDLE
                    if (clk_cnt == (CLK_DIVIDE/2) - 1) begin
                        cs_n    <= 1'b1;
                        rx_data <= shift_reg_rx; // Safely release payload bus to upper layers
                        bit_cnt <= 0;
                        state   <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule