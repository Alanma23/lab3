//=============================================================================
// EE180 Lab 3
//
// MIPS CPU Module. Contains the five stages in the single-cycle MIPS CPU.
//=============================================================================

`include "mips_defines.v"

module alu (
    input [4:0] alu_opcode,
    input [31:0] alu_op_x,
    input [31:0] alu_op_y,
    output reg [31:0] alu_result,
    output alu_op_y_zero,
    output wire alu_overflow
);

//******************************************************************************
// Shift operation: ">>>" will perform an arithmetic shift, but the operand
// must be reg signed, also useful for signed vs. unsigned comparison.
//******************************************************************************
    wire signed [31:0] alu_op_x_signed = alu_op_x;
    wire signed [31:0] alu_op_y_signed = alu_op_y;

//******************************************************************************
// ALU datapath
//******************************************************************************

    // Packed byte lanes (8-bit each)
    wire [7:0] px0 = alu_op_x[7:0];
    wire [7:0] px1 = alu_op_x[15:8];
    wire [7:0] px2 = alu_op_x[23:16];
    wire [7:0] px3 = alu_op_x[31:24];
    wire [7:0] py0 = alu_op_y[7:0];
    wire [7:0] py1 = alu_op_y[15:8];
    wire [7:0] py2 = alu_op_y[23:16];
    wire [7:0] py3 = alu_op_y[31:24];
    wire signed [15:0] px0_s = {{8{px0[7]}}, px0};
    wire signed [15:0] px1_s = {{8{px1[7]}}, px1};
    wire signed [15:0] px2_s = {{8{px2[7]}}, px2};
    wire signed [15:0] px3_s = {{8{px3[7]}}, px3};
    wire [7:0] add0 = px0 + py0;
    wire [7:0] add1 = px1 + py1;
    wire [7:0] add2 = px2 + py2;
    wire [7:0] add3 = px3 + py3;
    wire [7:0] sub0 = px0 - py0;
    wire [7:0] sub1 = px1 - py1;
    wire [7:0] sub2 = px2 - py2;
    wire [7:0] sub3 = px3 - py3;
    wire [2:0] pshamt = alu_op_x[2:0];
    wire [7:0] sll0 = py0 << pshamt;
    wire [7:0] sll1 = py1 << pshamt;
    wire [7:0] sll2 = py2 << pshamt;
    wire [7:0] sll3 = py3 << pshamt;
    wire [15:0] neg0 = -px0_s;
    wire [15:0] neg1 = -px1_s;
    wire [15:0] neg2 = -px2_s;
    wire [15:0] neg3 = -px3_s;
    wire [7:0] abs_b0 = (px0_s < 0) ? neg0[7:0] : px0;
    wire [7:0] abs_b1 = (px1_s < 0) ? neg1[7:0] : px1;
    wire [7:0] abs_b2 = (px2_s < 0) ? neg2[7:0] : px2;
    wire [7:0] abs_b3 = (px3_s < 0) ? neg3[7:0] : px3;

    always @* begin
        case (alu_opcode)
            // PERFORM ALU OPERATIONS DEFINED ABOVE
            `ALU_ADD:   alu_result = alu_op_x + alu_op_y;
            `ALU_ADDU:  alu_result = alu_op_x + alu_op_y;
            `ALU_AND:   alu_result = alu_op_x & alu_op_y;
            `ALU_OR:    alu_result = alu_op_x | alu_op_y;
            `ALU_SUB:   alu_result = alu_op_x - alu_op_y;
            `ALU_SUBU:  alu_result = alu_op_x - alu_op_y;
            `ALU_SLTU:  alu_result = alu_op_x < alu_op_y;
            `ALU_SLT:   alu_result = alu_op_x_signed < alu_op_y_signed;
            `ALU_SRL:   alu_result = alu_op_y >> alu_op_x[4:0]; // shift operations are Y >> X
            `ALU_SLL:   alu_result = alu_op_y << alu_op_x[4:0];
            `ALU_XOR:   alu_result = alu_op_x ^ alu_op_y;
            `ALU_NOR:   alu_result = ~(alu_op_x | alu_op_y);
            `ALU_SRA:   alu_result = alu_op_y_signed >>> alu_op_x[4:0];
            `ALU_MUL:   alu_result = alu_op_x * alu_op_y;
            `ALU_PASSX: alu_result = alu_op_x;
            `ALU_PASSY: alu_result = alu_op_y;
            // Packed SIMD: 4 bytes per 32-bit reg, result truncated to 8 bits per lane
            `ALU_PADD_B:  alu_result = {add3[7:0], add2[7:0], add1[7:0], add0[7:0]};
            `ALU_PSUB_B:  alu_result = {sub3[7:0], sub2[7:0], sub1[7:0], sub0[7:0]};
            `ALU_PSLL_B:  alu_result = {sll3[7:0], sll2[7:0], sll1[7:0], sll0[7:0]};
            `ALU_PABS_B:   alu_result = {abs_b3, abs_b2, abs_b1, abs_b0};
            `ALU_PUNPKLO:  alu_result = {8'b0, px1, 8'b0, px0};
            `ALU_PUNPKHI:  alu_result = {8'b0, px3, 8'b0, px2};
            `ALU_ABS:      alu_result = (alu_op_x_signed < 0) ? (-alu_op_x) : alu_op_x;
            default:    alu_result = 32'hxxxxxxxx;   // undefined
        endcase
    end

    wire alu_neg = alu_result[31];
    wire x_neg = alu_op_x[31];
    wire y_neg = alu_op_y[31];

    wire add_check = alu_opcode == `ALU_ADD;
    wire sub_check = alu_opcode == `ALU_SUB;

    wire add_pos_over = &{~x_neg, ~y_neg, alu_neg}; // postive + positive = negative
    wire add_neg_over = &{x_neg, y_neg, ~alu_neg}; // negative + negative = positive
    wire sub_pos_over = &{~x_neg, y_neg, alu_neg}; // positive - negative = negative
    wire sub_neg_over = &{x_neg, ~y_neg, ~alu_neg}; // negative - positive = positive

    assign alu_op_y_zero = ~|{alu_op_y};

    assign alu_overflow = |{add_check & (add_pos_over | add_neg_over),
                            sub_check & (sub_pos_over | sub_neg_over)};

endmodule
