// Write a module that sorts the values of a memory. The memory has one
// combinational read port and one clocked write port.  (We give them the
// implementation of the memory. It has read address, write address, a write
// enable.) The module should start sorting when 'start' is asserted and raise
// a 'done' signal when the memory is sorted. The goal is write
// a synthesizable module that is correct and minimizes the total energy
// consumed while sorting.

`include "memory.sv"
`include "ctl.sv"

module top ();

    ////////////////////
    // Nets ////////////
    ////////////////////

    logic clk;
    logic rst;

    t_addr rd_addr;
    t_data rd_data;

    logic  wr_en;
    t_addr wr_addr;
    t_data wr_data;

    logic start;
    logic done;

    ////////////////////
    // Instances ///////
    ////////////////////

    ctl ctl (
        .clk,
        .rst,
        .start,
        .done,
        .rd_addr,
        .rd_data,
        .wr_en,
        .wr_addr,
        .wr_data
    );


    memory memory (
        .clk,
        .rd_addr,
        .rd_data,
        .wr_en,
        .wr_addr,
        .wr_data
    );

    ////////////////////
    // Misc ////////////
    ////////////////////

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        $dumpfile("test.vcd");
        $dumpvars(0,top);

        repeat(10) @(negedge clk);
        rst = 1'b0;
        repeat(2) @(negedge clk);

        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        repeat(800) @(negedge clk);
        $finish();
    end

    initial begin
        @(negedge rst);
        @(negedge done);
        repeat(5) @(negedge clk);
        $finish();
    end

    always begin
        #100
        clk <= ~clk;
    end



endmodule
