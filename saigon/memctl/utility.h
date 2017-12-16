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
#ifndef SAIGON__MEMCTL__UTILITY_H_
#define SAIGON__MEMCTL__UTILITY_H_

#include <assert.h>
#include <stdint.h>

/*
 * MACRO round2_down
 *
 * Description:
 * 	Round `a` down to the nearest multiple of `b`, which must be a power of 2.
 *
 * Parameters:	a			The value to round
 * 		b			The rounding granularity
 */
#define round2_down(a, b)	((a) & ~((b) - 1))

/*
 * MACRO round2_up
 *
 * Description:
 * 	Round `a` up to the nearest multiple of `b`, which must be a power of 2.
 *
 * Parameters:	a			The value to round
 * 		b			The rounding granularity
 */
#define round2_up(a, b)							\
	({ __typeof__(a) _a = (a);					\
	   __typeof__(b) _b = (b);					\
	   round2_down(_a + _b - 1, _b); })

/*
 * MACRO min
 *
 * Description:
 * 	Return the minimum of the two arguments.
 */
#define min(a, b)							\
	({ __typeof__(a) _a = (a);					\
	   __typeof__(b) _b = (b);					\
	   (_a < _b ? _a : _b); })

/*
 * MACRO max
 *
 * Description:
 * 	Return the maximum of the two arguments.
 */
#define max(a, b)							\
	({ __typeof__(a) _a = (a);					\
	   __typeof__(b) _b = (b);					\
	   (_a > _b ? _a : _b); })

/*
 * MACRO ispow2
 *
 * Description:
 * 	Returns whether the argument is a power of 2 or 0.
 */
#define ispow2(x)							\
	({ __typeof__(x) _x = (x);					\
	   ((_x & (_x - 1)) == 0); })

/*
 * lobit
 *
 * Description:
 * 	Returns a mask of the least significant 1 bit.
 */
static inline uintmax_t
lobit(uintmax_t x) {
	return (x & (-x));
}

/*
 * pack_uint
 *
 * Description:
 * 	Store the integer `value` into `dest` as a `width`-byte integer.
 *
 * Parameters:
 * 	out	dest			The place to store the result
 * 		value			The value to store
 * 		width			The width of the integer to store. `width` must be 1, 2,
 * 					4, or 8.
 */
static inline void
pack_uint(void *dest, uintmax_t value, unsigned width) {
	switch (width) {
		case 1: *(uint8_t  *)dest =  (uint8_t) value; break;
		case 2: *(uint16_t *)dest = (uint16_t) value; break;
		case 4: *(uint32_t *)dest = (uint32_t) value; break;
		case 8: *(uint64_t *)dest = (uint64_t) value; break;
	}
}

#endif
