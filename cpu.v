module cpu (
	output	reg[15:0]	addr,
	inout		[7:0]			data,

	output	reg	re,
	output	reg	we,

	input		clk,
	
	input		rst
);

	reg		[7:0]		opcode;
	
// Registers
	reg		[7:0]		r0;
	reg		[7:0]		r1;
	reg		[7:0]		r2;
	reg		[7:0]		r3;
	reg		[7:0]		r4;
	reg		[7:0]		r5;
	reg		[7:0]		r6;
	reg		[7:0]		r7;
	reg		[15:0]	a0;
	reg		[15:0]	a1;
	reg		[15:0]	a2;
	reg		[15:0]	a3;

	reg		[7:0]		a;
	reg		[7:0]		b;

	reg		[15:0]	pc;
	reg		[15:0]	sp;
	
	reg		[7:0]		flags;

// Program Counter Tasks
	task pc_inc;
		pc = pc + 1'b1;
	endtask

// Address/Data Latches
	reg		[7:0]		data_latch;
	reg		[15:0]	addr_latch;
	
	reg		indirect_addr_flag;
	
	assign	data = re ? 8'bzzzzzzzz : data_latch;
	
	task addr_latch_set_high (
		input		[7:0]		addr_h
	);
		addr_latch[15:8] = addr_h;
	endtask

	task addr_latch_set_low (
		input		[7:0]		addr_l
	);
		addr_latch[7:0] = addr_l;
	endtask

// Instruction Counter
	reg		[3:0]		ic;
	
	task ic_inc;
		ic = ic + 1'b1;
	endtask

	task ic_rst;
		ic = 4'd0;
	endtask

// Compare Flags
	reg		cmp_equal_flag = 1'b0;
	reg		cmp_less_than_flag = 1'b0;

// Address Register Tasks
	task addr_latch_set (
		input		[1:0]		addr_reg_sel
	);
		case (addr_reg_sel)
			2'd0:		addr_latch = a0;
			2'd1:		addr_latch = a1;
			2'd2:		addr_latch = a2;
			2'd3:		addr_latch = a3;
		endcase
	endtask

	task branch_addr_reg (
		input		[1:0]		addr_reg_sel
	);
		case (addr_reg_sel)
			2'd0:		pc = a0;
			2'd1:		pc = a1;
			2'd2:		pc = a2;
			2'd3:		pc = a3;
		endcase
	endtask
	
// Task - Load / Store
	// Positive edge
	task load_store_posedge (
		input		[3:0]		inst_cycle
	);
	
		if (opcode[7:4] == 4'b0000) begin
			casez (opcode[3:0])
				4'b11??:
					// STA (An)
					if (inst_cycle == 4'd1)
						re = 1'b0;
				4'b1011:
					// STA $addr
					if (inst_cycle == 4'd3)
						re = 1'b0;
			endcase
		end
		
	endtask
	
	// Negative edge
	task load_store_negedge (
		input		[3:0]		inst_cycle
	);
	
		if (opcode[7:4] == 4'b0000) begin
			casez (opcode[3:0])
				4'b1010:
					// LDA #imm
					case (inst_cycle)
						4'd0: begin
							ic_inc;
							pc_inc;
						end
						4'd1: begin
							a = data;
							
							ic_rst;
							pc_inc;
						end
					endcase
				4'b01??:
					// LDA (An)
					case (inst_cycle)
						4'd0: begin
							addr_latch_set(opcode[1:0]);
							indirect_addr_flag = 1'b1;
							
							ic_inc;
						end
						4'd1: begin
							a = data;
							indirect_addr_flag = 1'b0;
							
							ic_rst;
							pc_inc;
						end
					endcase
				4'b11??:
					// STA (An)
					case (inst_cycle)
						4'd0: begin
							data_latch = a;
							indirect_addr_flag = 1'b1;
							addr_latch_set(opcode[1:0]);
							
							ic_inc;
						end
						4'd1: begin
							we = 1'b1;
							
							ic_inc;
						end
						4'd2: begin
							we = 1'b0;
							indirect_addr_flag = 1'b0;
							
							ic_rst;
							pc_inc;
						end
					endcase
				4'b1001:
					// LDA ($addr)
					case (inst_cycle)
						4'd0: begin
							ic_inc;
							pc_inc;
						end
						4'd1: begin
							addr_latch_set_high(data);
						
							ic_inc;
							pc_inc;
						end
						4'd2: begin
							addr_latch_set_low(data);
							indirect_addr_flag = 1'b1;
						
							ic_inc;
						end
						4'd3: begin
							a = data;
							indirect_addr_flag = 1'b0;
							
							ic_rst;
							pc_inc;
						end
					endcase
				4'b1011:
					// STA ($addr)
					case (inst_cycle)
						4'd0: begin
							ic_inc;
							pc_inc;
						end
						4'd1: begin
							addr_latch_set_high(data);
						
							ic_inc;
							pc_inc;
						end
						4'd2: begin
							addr_latch_set_low(data);
							
							data_latch = a;
							indirect_addr_flag = 1'b1;
						
							ic_inc;
						end
						4'd3: begin
							we = 1'b1;
						
							ic_inc;
						end
						4'd4: begin
							we = 1'b0;
							indirect_addr_flag = 1'b0;
							
							ic_rst;
							pc_inc;
						end
					endcase
				/*
				4'b10?1:
					// LDA/STA ($addr)
					case (inst_cycle)
						4'd0: begin
							ic_inc;
							pc_inc;
						end
						4'd1: begin
							// addr_h
							addr_latch_set_high(data);
							ic_inc;
							pc_inc;
						end
						4'd2: begin
							// addr_l
							addr_latch_set_low(data);
							addr_latch_flag = 1'b1;
							
							if (opcode[1]) begin
								//rw_clk_mode = 1'b1;
								write = 1'b1;
								write_neg = ~write_neg;
								data_latch = a;
							end
								
							ic_inc;
						end
						4'd3: begin
							// load/store
							if (!opcode[1])
								a = data;
							
							//rw_clk_mode = 1'b0;
							write = 1'b0;
							addr_latch_flag = 1'b0;
							
							ic_rst;
							pc_inc;
						end
					endcase
				*/
			endcase
		end
		
	endtask
	
// Task - Transfer
	// Negative edge
	task transfer_negedge;
	
		if (opcode == 8'b00001000) begin
			// TAB
			b = a;
			
			pc_inc;
		end else if (opcode[7:6] == 2'b00) begin
			casez (opcode[5:4])
				2'b01: begin
						// TRB
						case (opcode[3:0])
							4'd0:		b = r0;
							4'd1:		b = r1;
							4'd2:		b = r2;
							4'd3:		b = r3;
							4'd4:		b = r4;
							4'd5:		b = r5;
							4'd6:		b = r6;
							4'd7:		b = r7;
							4'd8:		b = a0[7:0];
							4'd9:		b = a0[15:8];
							4'd10:	b = a1[7:0];
							4'd11:	b = a1[15:8];
							4'd12:	b = a2[7:0];
							4'd13:	b = a2[15:8];
							4'd14:	b = a3[7:0];
							4'd15:	b = a3[15:8];
						endcase
						
						pc_inc;
					end
				2'b11: begin
						// TAR
						case (opcode[3:0])
							4'd0:		r0			= a;
							4'd1:		r1			= a;
							4'd2:		r2			= a;
							4'd3:		r3			= a;
							4'd4:		r4			= a;
							4'd5:		r5			= a;
							4'd6:		r6			= a;
							4'd7:		r7			= a;
							4'd8:		a0[7:0]	= a;
							4'd9:		a0[15:8]	= a;
							4'd10:	a1[7:0]	= a;
							4'd11:	a1[15:8]	= a;
							4'd12:	a2[7:0]	= a;
							4'd13:	a2[15:8]	= a;
							4'd14:	a3[7:0]	= a;
							4'd15:	a3[15:8]	= a;
						endcase
						
						pc_inc;
					end
				2'b10: begin
						// TRA
						case (opcode[3:0])
							4'd0:		a = r0;
							4'd1:		a = r1;
							4'd2:		a = r2;
							4'd3:		a = r3;
							4'd4:		a = r4;
							4'd5:		a = r5;
							4'd6:		a = r6;
							4'd7:		a = r7;
							4'd8:		a = a0[7:0];
							4'd9:		a = a0[15:8];
							4'd10:	a = a1[7:0];
							4'd11:	a = a1[15:8];
							4'd12:	a = a2[7:0];
							4'd13:	a = a2[15:8];
							4'd14:	a = a3[7:0];
							4'd15:	a = a3[15:8];
						endcase
						
						pc_inc;
					end
			endcase
		end
	
	endtask

// Task - Arithmetic	& Logic
	// Negative edge
	task arithmetic_logic_negedge;
		
		if (opcode[7:4] == 4'b0100) begin
			case (opcode[3:0])
				4'b0000:		a = a + b;				// ADD
				4'b0001:		a = a - b;				// SUB
				4'b0010:		a = a & b;				// AND
				4'b0011:		a = a | b;				// ORA
				4'b0110:		a = ~a;					// NOT
				4'b0111:		a = a ^ b;				// EOR
				4'b0100:		a = a << b[2:0];											//LSL
				4'b0101:		a = a >> b[2:0];											//LSR
				4'b1000:		a = (a << b[2:0]) | (a >> (~b[2:0] + 3'd1));		//ROL
				4'b1001:		a = (a >> b[2:0]) | (a << (~b[2:0] + 3'd1));		//ROR
			endcase
			
			pc_inc;
		end
		
	endtask
	
// Task - Compare & Branch

	wire	bra_condition;
	assign branch_condition = (cmp_equal_flag && opcode[1:0] == 2'b11)	||
									(cmp_less_than_flag && opcode[1:0] == 2'b10)	||
									opcode[1:0] == 2'b01;
									
	assign branch_condition_indirect = (cmp_equal_flag && opcode[3:2] == 2'b11)	||
												(cmp_less_than_flag && opcode[3:2] == 2'b10) ||
												opcode[3:2] == 2'b01;
	
	// Negative edge
	task compare_branch_negedge (
		input		[3:0]		inst_cycle
	);
	
		if (opcode == 8'b01010000) begin
			cmp_equal_flag = (a == b ? 1'b1 : 1'b0);
			cmp_less_than_flag = (a < b ? 1'b1 : 1'b0);
			
			pc_inc;
		end else if (opcode[7:4] == 4'b0101) begin
			case (opcode[3:2])
				2'b00:
					case (inst_cycle)
						// BRA/BEQ/BLT $addr
						4'd0: begin
								ic_inc;
								pc_inc;
							end
						4'd1: begin
								// addr_h
								addr_latch_set_high(data);
								
								ic_inc;
								pc_inc;
							end
						4'd2: begin
								// addr_l
								addr_latch_set_low(data);
								
								if (branch_condition)
									pc = pc + addr_latch;
								else
									pc_inc;
								
								ic_rst;
							end
						/*
						4'd3: begin
							pc <= pc + addr_latch;
							
							ic_rst;
						end
						*/
					endcase
				default: begin
						if (branch_condition_indirect) begin
							addr_latch_set(opcode[1:0]);
							pc = addr_latch;
						end else
							pc_inc;
					end
			endcase
		end
	
	endtask
	
// Control

	task reset_neg;
		begin
			r0 = 8'b00000000;
			r1 = 8'b00000000;
			r2 = 8'b00000000;
			r3 = 8'b00000000;
			r4 = 8'b00000000;
			r5 = 8'b00000000;
			r6 = 8'b00000000;
			r7 = 8'b00000000;
			a0 = 16'b0000000000000000;
			a1 = 16'b0000000000000000;
			a2 = 16'b0000000000000000;
			a3 = 16'b0000000000000000;
			
			pc = 16'b0000000000000000;
			sp = 16'b0000000000000000;
			
			a = 8'b00000000;
			b = 8'b00000000;
			
			ic = 4'b0000;
			
			we = 1'b0;
			
			opcode = 8'b00000000;
			
			data_latch = 8'b00000000;
			addr_latch = 16'b0000000000000000;
			indirect_addr_flag = 1'b0;
			
		end

	endtask
	
	always @(posedge clk) begin
		
		if (!rst)
			re = 1'b1;
			
		if (ic == 4'd0)
			re = 1'b1;
			
		if (opcode != 8'b00000000)
			load_store_posedge(ic);
			
		addr = indirect_addr_flag ? addr_latch : pc;
		
	end
	
	always @(negedge clk or negedge rst) begin
	
		if (!rst) begin
			reset_neg;
		end else begin

			if (ic == 4'd0)
				opcode = data;
			
			if (opcode != 8'b00000000) begin
				load_store_negedge(ic);
				transfer_negedge;
				arithmetic_logic_negedge;
				compare_branch_negedge(ic);
			end else
				// NOP
				pc_inc;
			
		end
	end

endmodule