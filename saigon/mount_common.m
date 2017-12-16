//
//  mount_common.m
//  Saigon
//
//  Created by Abraham Masri on 11/30/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#import <sys/mount.h>
#import <Foundation/Foundation.h>

#include "remote_call.h"
#include "offsets.h"
#include "rwx.h"
#include "kernel_call.h"

/*
    Purpose: a workaround to get mount rootfs (see vfs_syscalls.c:408)
*/
kern_return_t mount_common () {
    
    kern_return_t ret = KERN_SUCCESS;
    
    vnode_t pvp = NULL;
   	vnode_t vp = NULL;
    int need_nameidone = 0;
    char fstypename[MFSNAMELEN];
    uint64_t nd;
    size_t dummy=0;
    char *labelstr = NULL;
    int flags = MNT_UPDATE;
    int error;
    
    
    uint64_t ctx = 0;
    ret = rwx_read(offsets_get_kernel_base() + OFFSET(vfs_context_current), &ctx, sizeof(ctx));
    
    if(ctx == 0) {
        printf("[ERROR]: could not get current vfs context\n");
        goto cleanup;
    }
    
    printf("[INFO]: ctx: %llx", ctx);
    
    
    /*
     * Get the fs type name from user space
     */
//    struct kernel_call_argument copyinstr[4] = {
//        KERNEL_CALL_ARG(uint64_t, allocated_port), // (const user_addr_t) user_addr
//        KERNEL_CALL_ARG(uint64_t, remap_addr), // (char *) kernel_addr
//        KERNEL_CALL_ARG(uint32_t, 2), // (vm_size_t) nbytes
//    };
//    
//    ret = kernel_call(NULL, 0, offsets_get_kernel_base() + OFFSET(ipc_kobject_set), 3, ipc_kobject_set_args);
//    if (ret != KERN_SUCCESS) {
//        printf("[ERROR]: failed calling ipc_kobject_set\n");
//        return KERN_FAILURE; // Fail
//    } else {
//        printf("[INFO]: successfully called ipc_kobject_set\n");
//    }
   
    
#define NDINIT(ndp, op, pop, flags, segflg, namep, ctx) { \
(ndp)->ni_cnd.cn_nameiop = op; \
(ndp)->ni_op = pop; \
(ndp)->ni_cnd.cn_flags = flags; \
if ((segflg) == UIO_USERSPACE) { \
(ndp)->ni_segflg = UIO_USERSPACE64; \
} \
else { \
(ndp)->ni_segflg = segflg; \
} \
(ndp)->ni_dirp = namep; \
(ndp)->ni_cnd.cn_context = ctx; \
(ndp)->ni_flag = 0; \
(ndp)->ni_cnd.cn_ndp = (ndp); \

    /*
     * Get the vnode to be covered
     */
//    NDINIT(&nd, <#op#>, <#pop#>, <#flags#>, <#segflg#>, <#namep#>, <#ctx#>);
    
cleanup:
    return ret;
}
