// Write a module that sorts the values of a memory. The memory has one
// combinational read port and one clocked write port.  (We give them the
// implementation of the memory. It has read address, write address, a write
// enable.) The module should start sorting when 'start' is asserted and raise
// a 'done' signal when the memory is sorted. The goal is write
// a synthesizable module that is correct and minimizes the total energy
// consumed while sorting.

`ifndef MEMORY_SV
`define MEMORY_SV


module memory (
    input  logic clk,

    input  t_addr rd_addr,
    output t_data rd_data,

    input  logic  wr_en,
    input  t_addr wr_addr,
    input  t_data wr_data
);

t_data MEM [NUM_ROWS-1:0];

`define SWAP(i,j) \
    MEM[i] ^= MEM[j]; \
    MEM[j] ^= MEM[i]; \
    MEM[i] ^= MEM[j];

task automatic dump_state();
    string disp;
    disp = "";
    for (int i=0; i<NUM_ROWS; i++) begin
        disp = $sformatf("%s%-2d ", disp, MEM[i]);
    end
    $display("%t: %s", $time(), disp);
endtask

initial begin
    for (int i=0; i<NUM_ROWS; i++) begin
        MEM[i] = t_data'(i);
    end

    `SWAP(2,3)
    `SWAP(4,7)
    `SWAP(0,1)
    // `SWAP(5,15)

    dump_state();
end

assign rd_data = MEM[rd_addr];

always_ff @(posedge clk) begin
    if (wr_en) begin
        MEM[wr_addr] <= wr_data;
    end
end

logic wr_en_dly;
`DFF(wr_en_dly, wr_en, clk)

always_ff @(posedge clk) begin
    if (wr_en_dly) begin
        dump_state();
    end
end

endmodule

`endif //MEMORY_SV
