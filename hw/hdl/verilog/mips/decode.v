//=============================================================================
// EE180 Lab 3
//
// Decode module. Determines what to do with an instruction.
//=============================================================================

`include "mips_defines.v"

module decode (
    input [31:0] pc,
    input [31:0] instr,
    input [31:0] rs_data_in,
    input [31:0] rt_data_in,

    output wire [4:0] reg_write_addr,
    output wire jump_branch,
    output wire jump_target,
    output wire jump_reg,
    output wire [31:0] jr_pc,
    output wire [31:0] branch_target,
    output reg [3:0] alu_opcode,
    output wire [31:0] alu_op_x,
    output reg [31:0] alu_op_y,
    output wire mem_we,
    output wire [31:0] mem_write_data,
    output wire mem_read,
    output wire mem_byte,
    output wire mem_halfword,
    output wire mem_signextend,
    output wire reg_we,
    output wire movn,
    output wire movz,
    output wire [4:0] rs_addr,
    output wire [4:0] rt_addr,
    output wire atomic_id,
    input  atomic_ex,
    output wire mem_sc_mask_id,
    output wire mem_sc_id,

    output wire stall,

    input reg_we_ex,
    input [4:0] reg_write_addr_ex,
    input [31:0] alu_result_ex,
    input mem_read_ex,

    input reg_we_mem,
    input [4:0] reg_write_addr_mem,
    input [31:0] reg_write_data_mem
);

//******************************************************************************
// instruction field
//******************************************************************************

    wire [5:0] op = instr[31:26];
    assign rs_addr = instr[25:21];
    assign rt_addr = instr[20:16];
    wire [4:0] rd_addr = instr[15:11];
    wire [4:0] shamt = instr[10:6];
    wire [5:0] funct = instr[5:0];
    wire [15:0] immediate = instr[15:0];

    reg [31:0] rs_data, rt_data;

//******************************************************************************
// branch instructions decode
//******************************************************************************

    wire isBEQ = (op == `BEQ);
    wire isBGEZNL = (op == `BLTZ_GEZ) && (rt_addr == `BGEZ);
    wire isBGEZAL = (op == `BLTZ_GEZ) && (rt_addr == `BGEZAL);
    wire isBGTZ = (op == `BGTZ) && (rt_addr == 5'b00000);
    wire isBLEZ = (op == `BLEZ) && (rt_addr == 5'b00000);
    wire isBLTZNL = (op == `BLTZ_GEZ) && (rt_addr == `BLTZ);
    wire isBLTZAL = (op == `BLTZ_GEZ) && (rt_addr == `BLTZAL);
    wire isBNE = (op == `BNE);
    wire isBranchLink = isBGEZAL || isBLTZAL;

//******************************************************************************
// jump instructions decode
//******************************************************************************

    wire isJ = (op == `J);
    wire isJAL = (op == `JAL);
    wire isJR = (op == `SPECIAL) && (funct == `JR);
    wire isJALR = (op == `SPECIAL) && (funct == `JALR);

//******************************************************************************
// shift instruction decode
//******************************************************************************

    wire isSLL = (op == `SPECIAL) && (funct == `SLL);
    wire isSRL = (op == `SPECIAL) && (funct == `SRL);
    wire isSRA = (op == `SPECIAL) && (funct == `SRA);
    wire isSLLV = (op == `SPECIAL) && (funct == `SLLV);
    wire isSRLV = (op == `SPECIAL) && (funct == `SRLV);
    wire isSRAV = (op == `SPECIAL) && (funct == `SRAV);

    wire isShiftImm = isSLL || isSRL || isSRA;
    wire isShift = isShiftImm || isSLLV || isSRLV || isSRAV;

//******************************************************************************
// ALU instructions decode / control signal for ALU datapath
//******************************************************************************

    always @* begin
        casex({op, funct})
            {`ADDI, `DC6}:      alu_opcode = `ALU_ADD;
            {`ADDIU, `DC6}:     alu_opcode = `ALU_ADDU;
            {`SLTI, `DC6}:      alu_opcode = `ALU_SLT;
            {`SLTIU, `DC6}:     alu_opcode = `ALU_SLTU;
            {`ANDI, `DC6}:      alu_opcode = `ALU_AND;
            {`ORI, `DC6}:       alu_opcode = `ALU_OR;
            {`XORI, `DC6}:      alu_opcode = `ALU_XOR;
            {`LB, `DC6}:        alu_opcode = `ALU_ADD;
            {`LBU, `DC6}:       alu_opcode = `ALU_ADD;
            {`LH, `DC6}:        alu_opcode = `ALU_ADD;
            {`LW, `DC6}:        alu_opcode = `ALU_ADD;
            {`LL, `DC6}:        alu_opcode = `ALU_ADD;
            {`SB, `DC6}:        alu_opcode = `ALU_ADD;
            {`SH, `DC6}:        alu_opcode = `ALU_ADD;
            {`SW, `DC6}:        alu_opcode = `ALU_ADD;
            {`SC, `DC6}:        alu_opcode = `ALU_ADD;
            {`BEQ, `DC6}:       alu_opcode = `ALU_SUBU;
            {`BNE, `DC6}:       alu_opcode = `ALU_SUBU;
            {`SPECIAL, `ADD}:   alu_opcode = `ALU_ADD;
            {`SPECIAL, `ADDU}:  alu_opcode = `ALU_ADDU;
            {`SPECIAL, `SUB}:   alu_opcode = `ALU_SUB;
            {`SPECIAL, `SUBU}:  alu_opcode = `ALU_SUBU;
            {`SPECIAL, `AND}:   alu_opcode = `ALU_AND;
            {`SPECIAL, `OR}:    alu_opcode = `ALU_OR;
            {`SPECIAL, `XOR}:   alu_opcode = `ALU_XOR;
            {`SPECIAL, `NOR}:   alu_opcode = `ALU_NOR;
            {`SPECIAL, `MOVN}:  alu_opcode = `ALU_PASSX;
            {`SPECIAL, `MOVZ}:  alu_opcode = `ALU_PASSX;
            {`SPECIAL, `SLT}:   alu_opcode = `ALU_SLT;
            {`SPECIAL, `SLTU}:  alu_opcode = `ALU_SLTU;
            {`SPECIAL, `SLL}:   alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRL}:   alu_opcode = `ALU_SRL;
            {`SPECIAL, `SRA}:   alu_opcode = `ALU_SRA;
            {`SPECIAL, `SLLV}:  alu_opcode = `ALU_SLL;
            {`SPECIAL, `SRLV}:  alu_opcode = `ALU_SRL;
            {`SPECIAL, `SRAV}:  alu_opcode = `ALU_SRA;
            {`SPECIAL2, `MUL}:  alu_opcode = `ALU_MUL;
            // compare rs data to 0, only care about 1 operand
            {`BGTZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLEZ, `DC6}:      alu_opcode = `ALU_PASSX;
            {`BLTZ_GEZ, `DC6}: begin
                if (isBranchLink)
                    alu_opcode = `ALU_PASSY; // pass link address for mem stage
                else
                    alu_opcode = `ALU_PASSX;
            end
            // pass link address to be stored in $ra
            {`JAL, `DC6}:       alu_opcode = `ALU_PASSY;
            {`SPECIAL, `JALR}:  alu_opcode = `ALU_PASSY;
            // or immediate with 0
            {`LUI, `DC6}:       alu_opcode = `ALU_PASSY;
            default:            alu_opcode = `ALU_PASSX;
    	endcase
    end

//******************************************************************************
// Compute value for 32 bit immediate data
//******************************************************************************

    // Use immediate when the instruction is not R-type, BEQ, or BNE
    wire use_imm = (op != `SPECIAL) && (op != `SPECIAL2) && (op != `BNE) && (op != `BEQ);

    wire [31:0] imm_sign_extend = {{16{immediate[15]}}, immediate};
    wire [31:0] imm_zero_extend = {16'b0, immediate};
    wire [31:0] imm_upper = {immediate, 16'b0};

    // Logical immediates (ANDI, ORI, XORI) are zero-extended; others sign-extended
    wire is_logical_imm = (op == `ANDI) || (op == `ORI) || (op == `XORI);

    reg [31:0] imm;
    always @(*) begin
        if (op == `LUI)
            imm = imm_upper;
        else if (is_logical_imm)
            imm = imm_zero_extend;
        else
            imm = imm_sign_extend;
    end

//******************************************************************************
// forwarding and stalling logic
//******************************************************************************

    // EX-stage forwarding (not for loads: result not ready until MEM stage)
    wire forward_rs_ex = (rs_addr == reg_write_addr_ex) && (rs_addr != `ZERO) && reg_we_ex && ~mem_read_ex;
    wire forward_rt_ex = (rt_addr == reg_write_addr_ex) && (rt_addr != `ZERO) && reg_we_ex && ~mem_read_ex;

    // MEM-stage forwarding
    wire forward_rs_mem = (rs_addr == reg_write_addr_mem) && (rs_addr != `ZERO) && reg_we_mem;
    wire forward_rt_mem = (rt_addr == reg_write_addr_mem) && (rt_addr != `ZERO) && reg_we_mem;

    // EX takes priority over MEM over register file
    always @(*) begin
        if (forward_rs_ex)
            rs_data = alu_result_ex;
        else if (forward_rs_mem)
            rs_data = reg_write_data_mem;
        else
            rs_data = rs_data_in;
    end

    always @(*) begin
        if (forward_rt_ex)
            rt_data = alu_result_ex;
        else if (forward_rt_mem)
            rt_data = reg_write_data_mem;
        else
            rt_data = rt_data_in;
    end

    // Load-use stall: wait 1 cycle if consuming the result of a load in EX
    wire rs_mem_dependency = (rs_addr == reg_write_addr_ex) && mem_read_ex && (rs_addr != `ZERO);
    wire rt_mem_dependency = (rt_addr == reg_write_addr_ex) && mem_read_ex && (rt_addr != `ZERO);

    wire isLUI = (op == `LUI);

    // Rs is read by all instructions except LUI, jump-target, and shift-immediate
    wire read_from_rs = ~(isLUI || jump_target || isShiftImm);

    // Instructions that use an immediate as their second ALU input (Rt is not an ALU source)
    wire isALUImm = (op == `ADDI)  || (op == `ADDIU) || (op == `SLTI) ||
                    (op == `SLTIU) || (op == `ANDI)  || (op == `ORI)  || (op == `XORI);

    // Rt is read unless the instruction is LUI, a jump-target, uses an immediate, or is a load
    wire read_from_rt = ~(isLUI || jump_target || isALUImm || mem_read);

    assign stall = (rs_mem_dependency && read_from_rs) || (rt_mem_dependency && read_from_rt);

    assign jr_pc = rs_data;
    assign mem_write_data = rt_data;

//******************************************************************************
// Determine ALU inputs and register writeback address
//******************************************************************************

    // For shift operations, use either the shamt field or the lower 5 bits of rs
    wire [31:0] shift_amount = isShiftImm ? shamt : rs_data[4:0];
    assign alu_op_x = isShift ? shift_amount : rs_data;

    // For link instructions, the second ALU operand carries PC+8 (the return address)
    // For immediate instructions, use the decoded immediate
    // Otherwise use rt
    wire isLinkInstr = isJAL || isJALR || isBGEZAL || isBLTZAL;
    wire [31:0] pc_plus8 = pc + 32'd8;

    always @(*) begin
        if (isLinkInstr)
            alu_op_y = pc_plus8;
        else if (use_imm)
            alu_op_y = imm;
        else
            alu_op_y = rt_data;
    end

    // JAL / BGEZAL / BLTZAL: the rt field is not a register; force writeback to $ra
    // Immediate instructions write to rt; R-type instructions write to rd
    reg [4:0] reg_write_addr_r;
    always @(*) begin
        if (isJAL || isBranchLink)
            reg_write_addr_r = `RA;
        else if (use_imm)
            reg_write_addr_r = rt_addr;
        else
            reg_write_addr_r = rd_addr;
    end
    assign reg_write_addr = reg_write_addr_r;

    // Disable register writeback for plain stores, non-linking jumps, and non-linking branches
    wire is_non_writing_instr = (mem_we && (op != `SC)) ||
                                 isJ      ||
                                 isBGEZNL ||
                                 isBGTZ   ||
                                 isBLEZ   ||
                                 isBLTZNL ||
                                 isBNE    ||
                                 isBEQ;
    assign reg_we = ~is_non_writing_instr;

    // Conditional moves: write only when condition register meets criterion
    assign movn = (op == `SPECIAL) && (funct == `MOVN);
    assign movz = (op == `SPECIAL) && (funct == `MOVZ);

//******************************************************************************
// Memory control
//******************************************************************************

    // Write to memory for store instructions
    assign mem_we = (op == `SW) || (op == `SB) || (op == `SH) || (op == `SC);

    // Read from memory and write result to register for load instructions
    assign mem_read = (op == `LW) || (op == `LB) || (op == `LBU) || (op == `LH) || (op == `LL);

    // Sub-word access width
    assign mem_byte = (op == `SB) || (op == `LB) || (op == `LBU);
    assign mem_halfword = (op == `LH) || (op == `SH);

    // Sign-extend the loaded value for all loads except LBU (unsigned byte)
    assign mem_signextend = (op != `LBU);

//******************************************************************************
// Load linked / Store conditional
//******************************************************************************

    assign mem_sc_id = (op == `SC);

    // atomic_id is high when LL is in ID; it sets the atomic flag as LL moves to EX
    assign atomic_id = (op == `LL);

    // mem_sc_mask_id suppresses the SC store when no preceding LL set the atomic flag
    assign mem_sc_mask_id = mem_sc_id && ~atomic_ex;

//******************************************************************************
// Branch resolution
//******************************************************************************

    wire isEqual = (rs_data == rt_data);

    // Signed comparisons of rs against zero
    wire rs_ltz = rs_data[31];                           // rs < 0  (sign bit set)
    wire rs_gtz = (~rs_data[31]) && (rs_data != 32'b0); // rs > 0  (positive and nonzero)
    wire rs_lez = rs_ltz || (rs_data == 32'b0);          // rs <= 0 (negative or zero)
    wire rs_gez = ~rs_data[31];                          // rs >= 0 (sign bit clear)

    // Individual branch-taken conditions
    wire branch_beq = isBEQ && isEqual;
    wire branch_bne = isBNE && ~isEqual;
    wire branch_bgtz = isBGTZ && rs_gtz;
    wire branch_blez = isBLEZ && rs_lez;
    wire branch_bltz = (isBLTZNL || isBLTZAL) && rs_ltz;
    wire branch_bgez = (isBGEZNL || isBGEZAL) && rs_gez;

    assign jump_branch = branch_beq  ||
                         branch_bne  ||
                         branch_bgtz ||
                         branch_blez ||
                         branch_bltz ||
                         branch_bgez;

    assign branch_target = pc + 32'd4 + {imm_sign_extend[29:0], 2'b0};

    assign jump_target = isJ   || isJAL;
    assign jump_reg = isJR || isJALR;

endmodule
