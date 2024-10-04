`ifndef DEFS_SV
`define DEFS_SV

parameter NUM_ROWS=8;
parameter WIDTH=8;
typedef logic[NUM_ROWS-1:0] t_addr;
typedef logic[WIDTH-1:0]    t_data;

`define DFF(q,d,clk) always_ff @(posedge clk) q <= d;
`define DFF_EN(q,d,clk,en) always_ff @(posedge clk) if (en) q <= d;

`endif //DEFS_SV
