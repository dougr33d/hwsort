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
    IDLE       = 3'b000,
    INIT       = 3'b001,
    WALK       = 3'b011,
    SWAP_TO_HI = 3'b111,
    SWAP_TO_LO = 3'b110,
    ADVANCE    = 3'b010,
    DONE       = 3'b100
} t_fsm;
t_fsm fsm, fsm_nxt;

/////////////////////////
// Nets /////////////////
/////////////////////////

t_addr walk_ptr; // advances inside the iter while walking
t_addr iter_ptr; // advances at end of iter

logic clk_busy; // gated clock that is active when FSM is active

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
//
//
// Assumptions:
//   - Array writes are primary consumer of power; fewer writes = less energy consumed
//   - ... this means that sorting algs with better big-O but more data movement are likely worse than Selection Sort
//
// Current energy optimizations:
//   - Only one full-width temp data register (using comb read to read the array and write the read data in the same cycle -- possible timing path)
//   - Greycoded FSM
//   - Skip the swap if trying to swap to/from same index
//   - Gated clock when FSM is idle
//
// Future optimizations:
//   - Walk from both sides simultaneously, keeping current_max_{addr,data,valid} as well (requires more FF storage, but fewer iterations)
//   - Capture prev read address so it can be held when not reading (IDLE, INIT, ADVANCE, DONE, SWAP_TO_LO)
//   - Some FSM states can be optimized (do initialization in IDLE, remove ADVANCE state, etc)
//

always_comb begin
    fsm_nxt = fsm;
    if (rst) begin
        fsm_nxt = IDLE;
    end else begin
        case(fsm)
            IDLE:       if ( start                  ) fsm_nxt = INIT;
            INIT:       if ( 1'b1                   ) fsm_nxt = WALK;

            WALK:       if ( walk_ptr == NUM_ROWS-1 & (iter_ptr != current_min_addr_nxt)) fsm_nxt = SWAP_TO_HI;
                   else if ( walk_ptr == NUM_ROWS-1 & (iter_ptr == current_min_addr_nxt)) fsm_nxt = ADVANCE;

            SWAP_TO_HI: if ( 1'b1                   ) fsm_nxt = SWAP_TO_LO;
            SWAP_TO_LO: if ( 1'b1                   ) fsm_nxt = ADVANCE;

            ADVANCE:    if ( iter_ptr == NUM_ROWS-1 ) fsm_nxt = DONE;
                   else if ( 1'b1                   ) fsm_nxt = WALK;

            DONE:       if ( 1'b1                   ) fsm_nxt = IDLE;
        endcase
    end
end
`DFF(fsm, fsm_nxt, clk_busy)

assign done = fsm == DONE;

logic busy_en;
assign busy_en = rst | start | (fsm != IDLE);
icg ckbusy ( clk_busy, clk, busy_en );

/////////////////////////
// Logic ////////////////
/////////////////////////

//
// Walk pointer: initializes to zero; increments each cycle during walk,
// resetting to the iter ptr in ADVANCE
//

t_addr walk_ptr_nxt;
always_comb begin
    case (fsm)
        INIT:    walk_ptr_nxt = t_addr'('0);
        ADVANCE: walk_ptr_nxt = t_addr'(iter_ptr + 1'b1);
        WALK:    walk_ptr_nxt = t_addr'(walk_ptr + 1'b1);
        default: walk_ptr_nxt = walk_ptr;
    endcase
end
`DFF(walk_ptr, walk_ptr_nxt, clk_busy)

//
// Iter pointer: initializes to zero; increments in ADVANCE
//

t_addr iter_ptr_nxt;
always_comb begin
    case (fsm)
        INIT:    iter_ptr_nxt = t_addr'('0);
        ADVANCE: iter_ptr_nxt = t_addr'(iter_ptr + 1'b1);
        default: iter_ptr_nxt = iter_ptr;
    endcase
end
`DFF(iter_ptr, iter_ptr_nxt, clk_busy)

//
// current_min addr/data/valid
//
// addr/data = Don'tCare when ~valid
//
// records the minimum data value seen (+ its address) during each walk
//

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
`DFF(current_min_addr, current_min_addr_nxt, clk_busy)
`DFF(current_min_data, current_min_data_nxt, clk_busy)
`DFF(current_min_valid, current_min_valid_nxt, clk_busy)

//
// Array is written only in SWAP_TO_{HI,LO} states.  
//
// SWAP_TO_HI means we need to read the value at iter_ptr and write it into
// current_min_addr
//
// SWAP_TO_LO means we need to write the saved current_min_data into the
// location specified by iter_ptr
//
// i.e. we are doing SWAP(iter_ptr, current_min_addr) using current_min_data
// as a temp holding register
//
// We only need to do the write if iter_ptr != current_min_addr (this is
// handled in the FSM)
//

always_comb begin
    wr_en   = '0;
    wr_addr = '0;
    wr_data = '0;
    rd_addr = '0;
    case(fsm)
        SWAP_TO_HI: begin
            rd_addr = iter_ptr;
            wr_en   = 1'b1;
            wr_addr = current_min_addr;
            wr_data = rd_data;
        end
        SWAP_TO_LO: begin
            rd_addr = '0;
            wr_en   = 1'b1;
            wr_addr = iter_ptr;
            wr_data = current_min_data;
        end
        default: begin
            wr_en   = '0;
            wr_addr = iter_ptr;
            wr_data = '0;
            rd_addr = walk_ptr;
        end
    endcase
end

endmodule

`endif //CTL_SV
