`ifndef DEFS_SV
`define DEFS_SV

parameter NUM_ROWS=8;
parameter WIDTH=8;
typedef logic[NUM_ROWS-1:0] t_addr;
typedef logic[WIDTH-1:0]    t_data;

`define DFF_EN(q,d,clk,en) always @(posedge clk) if (en) q <= d;
`define DFF(q,d,clk) always @(posedge clk) q <= d;

module icg (
    output logic clk_out,
    input  logic clk_in,
    input  logic en
);

logic gate;

always_ff @(negedge clk_in) begin
    gate <= en;
end

always_comb begin
    clk_out = clk_in & en;
end

endmodule

`endif //DEFS_SV
