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
#ifndef SAIGON__MEMCTL__KERNEL_CALL_H_
#define SAIGON__MEMCTL__KERNEL_CALL_H_

#include <stdbool.h>
#include <stdint.h>
#include <unistd.h>
#include <stdlib.h>
#include <mach/mach.h>

/*
 * struct kernel_call_argument
 *
 * Description:
 * 	An argument to kernel_call.
 */
struct kernel_call_argument {
	// The size of the argument in bytes. This must be a power of 2 between 1 and the kernel
	// word size.
	size_t   size;
	// The argument value.
	uint64_t value;
};

/*
 * macro KERNEL_CALL_ARG
 *
 * Description:
 * 	A helper macro to construct argument arrays for kernel_call.
 */
#define KERNEL_CALL_ARG(type, argument)	\
	((struct kernel_call_argument) { sizeof(type), argument })

/*
 * kernel_call
 *
 * Description:
 * 	Call a kernel function with the given arguments.
 *
 * Parameters:
 * 	out	result			The return value of the kernel function.
 * 		result_size		The size of the return value in bytes. Must be 1, 2, 4, or
 * 					8.
 * 		func			The function to call, or 0 to test if the given function
 * 					call is possible given the available functionality.
 * 		arg_count		The number of arguments to the function. Maximum allowed
 * 					value is 32. The actual upper limit on the number of
 * 					arguments will usually be lower, and will vary by platform
 * 					based on the loaded functionality.
 * 		args			The arguments to the kernel function.
 *
 * Returns:
 * 	KERN_SUCCESS if the function call succeeded, KERN_FAILURE if there was an error.
 *
 * Dependencies:
 * 	ziVA
 *
 * Notes:
 * 	This implementation assumes that the platform is 64-bit and that PAN (Arm64's SMAP) is not
 * 	enabled.
 */
kern_return_t kernel_call(void *result, unsigned result_size,
		uint64_t func, unsigned arg_count, const struct kernel_call_argument args[]);

/*
 * kernel_call_x
 *
 * Description:
 * 	Call a kernel function with the given word-sized arguments.
 *
 * Parameters:
 * 	out	result			The return value of the kernel function.
 * 		result_size		The size of the return value in bytes. Must be 1, 2, 4, or
 * 					8.
 * 		func			The function to call, or 0 to test if the given function
 * 					call is possible given the available functionality.
 * 		arg_count		The number of arguments to the function. Maximum allowed
 * 					value is 14. The actual upper limit on the number of
 * 					arguments will usually be lower, and will vary by platform
 * 					based on the loaded functionality.
 * 		args			The arguments to the kernel function. The kernel function
 * 					must expect every argument to be word-sized.
 *
 * Returns:
 * 	KERN_SUCCESS if the function call succeeded, KERN_FAILURE if there was an error.
 *
 * Dependencies:
 * 	ziVA
 *
 * Notes:
 * 	See kernel_call.
 *
 * 	This is a convenience wrapper around kernel_call, for the common case when the kernel
 * 	function being called is known to expect word-sized arguments. This is true for example
 * 	when the kernel function takes all its arguments in registers.
 */
kern_return_t kernel_call_x(void *result, unsigned result_size,
		uint64_t func, unsigned arg_count, const uint64_t args[]);

#endif
