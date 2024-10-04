`ifndef CTL_SV
`define CTL_SV

`include "defs.sv"

module ctl (
    input  logic clk,
    input  logic rst,
    input  logic start,
    output logic done,

    output t_addr rd_addr,
    input  t_data rd_data,

    output logic  wr_en,
    output t_addr wr_addr,
    output t_data wr_data
);

/////////////////////////
// Types ////////////////
/////////////////////////

typedef enum logic[2:0] {
    IDLE,
    INIT,
    WALK,
    SWAP_TO_LO,
    SWAP_TO_HI,
    ADVANCE,
    DONE
} t_fsm;
t_fsm fsm, fsm_nxt;

/////////////////////////
// Nets /////////////////
/////////////////////////

t_addr walk_ptr; // advances inside the iter while walking
t_addr iter_ptr; // advances at end of iter

/////////////////////////
// FSM //////////////////
/////////////////////////

//
// Algorithm
//
// for iter_ptr in (0..num_rows):
//   min_ptr = iter_ptr
//   min_data = mem[iter_ptr]
//   for walk_ptr in (iter_ptr..num_rows):
//     if mem[walk_ptr] < min_data:
//       update min_ptr, min_data
//   if (min_ptr != iter_ptr):
//     mem[min_ptr] = mem[iter_ptr] // SWAP_TO_HI
//     mem[iter_ptr] = min_data     // SWAP_TO_LO
always_comb begin
    fsm_nxt = fsm;
    if (rst) begin
        fsm_nxt = IDLE;
    end else begin
        case(fsm)
            IDLE:       if ( start                  ) fsm_nxt = INIT;
            INIT:       if ( 1'b1                   ) fsm_nxt = WALK;

            WALK:       if ( walk_ptr == NUM_ROWS-1 ) fsm_nxt = SWAP_TO_HI;

            SWAP_TO_HI: if ( 1'b1                   ) fsm_nxt = SWAP_TO_LO;
            SWAP_TO_LO: if ( 1'b1                   ) fsm_nxt = ADVANCE;

            ADVANCE:    if ( iter_ptr == NUM_ROWS-1 ) fsm_nxt = DONE;
                   else if ( 1'b1                   ) fsm_nxt = WALK;

            DONE:       if ( 1'b1                   ) fsm_nxt = IDLE;
        endcase
    end
end
`DFF(fsm, fsm_nxt, clk)

/////////////////////////
// Logic ////////////////
/////////////////////////

t_addr walk_ptr_nxt;
always_comb begin
    case (fsm)
        INIT:    walk_ptr_nxt = t_addr'('0);
        ADVANCE: walk_ptr_nxt = t_addr'(iter_ptr + 1'b1);
        WALK:    walk_ptr_nxt = t_addr'(walk_ptr + 1'b1);
        default: walk_ptr_nxt = walk_ptr;
    endcase
end
`DFF(walk_ptr, walk_ptr_nxt, clk)

t_addr iter_ptr_nxt;
always_comb begin
    case (fsm)
        INIT:    iter_ptr_nxt = t_addr'('0);
        ADVANCE: iter_ptr_nxt = t_addr'(iter_ptr + 1'b1);
        default: iter_ptr_nxt = iter_ptr;
    endcase
end
`DFF(iter_ptr, iter_ptr_nxt, clk)

t_addr current_min_addr;
t_addr current_min_addr_nxt;
t_data current_min_data;
t_data current_min_data_nxt;
logic  current_min_valid;
logic  current_min_valid_nxt;

always_comb begin
    current_min_addr_nxt = current_min_addr;
    current_min_data_nxt = current_min_data;
    current_min_valid_nxt = current_min_valid;
    if (fsm == INIT | fsm == ADVANCE) begin
        current_min_addr_nxt = 'x;
        current_min_data_nxt = 'x;
        current_min_valid_nxt = 1'b0;
    end else if(fsm == WALK) begin
        if ((rd_data < current_min_data) | ~current_min_valid) begin
            current_min_addr_nxt = walk_ptr;
            current_min_data_nxt = rd_data;
            current_min_valid_nxt = 1'b1;
        end
    end
end
`DFF(current_min_addr, current_min_addr_nxt, clk)
`DFF(current_min_data, current_min_data_nxt, clk)
`DFF(current_min_valid, current_min_valid_nxt, clk)

always_comb begin
    wr_en   = '0;
    wr_addr = '0;
    wr_data = '0;
    rd_addr = '0;
    case(fsm)
        SWAP_TO_HI: begin
            rd_addr = iter_ptr;
            wr_en   = iter_ptr != current_min_addr;
            wr_addr = current_min_addr;
            wr_data = rd_data;
        end
        SWAP_TO_LO: begin
            rd_addr = '0;
            wr_en   = iter_ptr != current_min_addr;
            wr_addr = iter_ptr;
            wr_data = current_min_data;
        end
        default: begin
            wr_en   = '0;
            wr_addr = '0;
            wr_data = '0;
            rd_addr = walk_ptr;
        end
    endcase
end

assign done = fsm == DONE;

endmodule

`endif //CTL_SV
