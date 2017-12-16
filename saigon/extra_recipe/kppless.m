//
//  kppless.m
//  Saigon
//
//  Created by xerub on 16/05/2017.
//  Copyright © 2017 xerub. All rights reserved.
//  Modified by Abraham Masri @cheesecakeufo on 10/18/17.

#include "rwx.h"
#include "unjail.h"
#include "offsets.h"
#include "libjb.h"
#include "jailbreak.h"
#include "Utilities.h"
#include "kernel_call.h"
#include "patchfinder64.h"
#include "kppless_inject.h"

kern_return_t go_kppless() {
    
    kern_return_t ret = KERN_SUCCESS;
    
//    uint64_t kaslr_shift = OFFSET(main_kernel_base) - OFFSET(kernel_text);
    uint64_t kernel_base = OFFSET(main_kernel_base);
    
    int rv = init_kernel(kernel_base, NULL);
    
    if(rv != 0) {
        printf("[ERROR]: could not initialize kernel\n");
        ret = KERN_FAILURE;
        goto cleanup;
    }
    
    printf("[INFO]: sucessfully initialized kernel\n");
    
    uint64_t trust_chain = find_trustcache();
    uint64_t amficache = find_amficache();
    
    term_kernel();
    
    uint64_t kern_proc = 0;
    uint64_t self_proc = 0;
    uint64_t containermanager = 0;
    
    get_procs(&kern_proc, &self_proc, &containermanager);
    
    uint64_t c_cred = 0;

    // fix 'containermanagerd'
    if (containermanager) {
        c_cred = kread_uint64(containermanager + offsetof_p_ucred);
        
        uint64_t kern_cred = kread_uint64(kern_proc + offsetof_p_ucred);
        kwrite_uint64(self_proc + offsetof_p_ucred, kern_cred);
        
        kwrite_uint64(containermanager + offsetof_p_ucred, kern_cred); // credpatch
    }
    
    
    /* 2. remount "/" */
    
    {
        struct utsname uts;
        uname(&uts);
        
        vm_offset_t off = 0xd8;
        if (strstr(uts.version, "16.0.0")) {
            off = 0xd0;
        }
        
        uint64_t _rootvnode = find_gPhysBase() + 0x38;
        uint64_t rootfs_vnode = kread_uint64(_rootvnode);
        uint64_t v_mount = kread_uint64(rootfs_vnode + off);
        uint32_t v_flag = kread_uint32(v_mount + 0x71);
        
        kwrite_uint32(v_mount + 0x71, v_flag & ~(1 << 6));
        
//        char *nmz = strdup("/dev/disk0s1s1");
        
        
//        uint64_t args[] = { pid };
//        void * result;
//        bool kernel_call_x(&result, sizeof(result), OFFSET(mount_common), 10, []);
        
        
//        rv = mount("hfs", "/", MNT_UPDATE, (void *)&nmz);
        NSLog(@"remounting: %d", rv);
        
        v_mount = kread_uint64(rootfs_vnode + off);
        kwrite_uint32(v_mount + 0x71, v_flag);
    }
    
    
    
    
    char path[4096];
    uint32_t size = sizeof(path);
    _NSGetExecutablePath(path, &size);
    char *pt = realpath(path, NULL);
    
    NSString *execpath = [[NSString stringWithUTF8String:pt] stringByDeletingLastPathComponent];
    
    
    NSString *bootstrap = [execpath stringByAppendingPathComponent:@"bootstrap.dmg"];
    const char *jl;

    /* 2. extract and run hdik */
    jl = "/tmp/hdik";
    long dmg = HFSOpen("/usr/standalone/update/ramdisk/arm64SURamDisk.dmg", 27);
    if (dmg >= 0) {
        long len = HFSReadFile(dmg, "/usr/sbin/hdik", gLoadAddr, 0, 0);
        printf("[INFO]: hdik = %ld\n", len);
        if (len > 0) {
            int fd = creat(jl, 0755);
            if (fd >= 0) {
                write(fd, gLoadAddr, len);
                close(fd);
            }
        }
        HFSClose(dmg);
    }
    
    pid_t pid;
    posix_spawn(&pid, jl, NULL, NULL, (char **)&(const char*[]){ jl, [bootstrap UTF8String], "-nomount", NULL }, NULL);
    waitpid(pid, NULL, 0);
    

    char thedisk[11];
    strcpy(thedisk, "/dev/diskN");
    for (int i = 9; i > 2; i--) {
        struct stat st;
        thedisk[9] = i + '0';
        rv = stat(thedisk, &st);
        if (rv == 0) {
            break;
        }
    }
    printf("[INFO]: thedisk: %s\n", thedisk);
    
    
    // 3. mount
    memset(&args, 0, sizeof(args));
    args.fspec = thedisk;
    args.hfs_mask = 0777;
    rv = mount("hfs", "/Developer", MNT_RDONLY, &args);
    printf("[INFO]: mount: %d\n", rv);

    
    // inject trust cache
    printf("[INFO]: trust_chain = 0x%llx\n", trust_chain);
    
    struct trust_mem mem;
    mem.next = kread_uint64(trust_chain);
    *(uint64_t *)&mem.uuid[0] = 0xabadbabeabadbabe;
    *(uint64_t *)&mem.uuid[8] = 0xabadbabeabadbabe;
    
    rv = grab_hashes("/Developer", kread, amficache, mem.next);
    
    printf("[INFO]: rv = %d, numhash = %d\n", rv, numhash);

    size_t length = (sizeof(mem) + numhash * 20 + 0xFFFF) & ~0xFFFF;
    uint64_t kernel_trust = 0;
    mach_vm_allocate(tfp0, (mach_vm_address_t *)&kernel_trust, length, VM_FLAGS_ANYWHERE);
    printf("[INFO]: alloced: 0x%zx => 0x%llx\n", length, kernel_trust);

    mem.count = numhash;
    kwrite(kernel_trust, &mem, sizeof(mem));
    kwrite(kernel_trust + sizeof(mem), allhash, numhash * 20);
    kwrite_uint64(trust_chain, kernel_trust);
    
    free(allhash);
    free(allkern);
    free(amfitab);

//    rv = posix_spawn(&pid, pt, NULL, NULL, (char **)&(const char*[]){ pt, "derp", "/Developer/Library/LaunchDaemons/com.openssh.sshd.plist", NULL }, NULL);
    rv = posix_spawn(&pid, "/Developer/usr/bin/uicache", NULL, NULL, (char **)&(const char*[]){ "/Developer/usr/bin/uicache", NULL }, NULL);

    int tries = 3;
    while (tries-- > 0) {
        uint64_t containermanager = kread_uint64(offsets_get_kernel_base() + OFFSET(all_proc));
        while (containermanager) {
            uint32_t _pid = kread_uint32(containermanager + offsetof_p_pid);
            if (_pid == pid) {
                uint32_t csflags = kread_uint32(containermanager + offsetof_p_csflags);
                csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT | CS_KILL | CS_HARD);
                kwrite_uint32(containermanager + offsetof_p_csflags, csflags);
                printf("[INFO]: empower\n");
                tries = 0;
                break;
            }
            containermanager = kread_uint64(containermanager);
        }
    }
    
    waitpid(pid, NULL, 0);
    
    if (containermanager) {
        kwrite_uint64(containermanager + offsetof_p_ucred, c_cred);
    }

    printf("[INFO]: done\n");
    
    
    // a daemon I guess?
    {
//        while(1) {
//            
//            printf("------------------\n");
//            unsigned int i = 0;
//            uint64_t c_cred = 0;
//            uint64_t proc = kread_uint64(offsets_get_kernel_base() + OFFSET(all_proc));
//            for (i = 0; i < 0xffff; ++i) {
//                
//                if(proc == 0) {
//                    printf("Reached the end!\n");
//                    break;
//                }
//                
//                char comm[20];
//                kread(proc + offsetof_p_comm, comm, 16);
//                comm[17] = 0;
//                NSLog(@"[INFO]: process: %s with addr: %llx\n", comm, proc);
//                
//                // we skip the first run then compare the old list with the next list and so on
//                
//                
//                if (strstr("bash", comm) || strstr("login", comm)) {
//                    printf("Found Cydia: 0x%llx.\n", proc);
//                    
//                    int tries = 3;
//                    while (tries-- > 0) {
//                        sleep(1);
//
//                        uint32_t csflags = kread_uint32(proc + offsetof_p_csflags);
//                        csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT | CS_KILL | CS_HARD);
//                        kwrite_uint32(proc + offsetof_p_csflags, csflags);
//                        printf("[INFO]: we empowered %s.\n", comm);
//                        tries = 0;
//                        kwrite_uint64(proc + offsetof_p_ucred, c_cred);
//                        
//                    }
//                
//                    break;
//                }
//                proc = kread_uint64(proc);
//            }
////            sleep(9r);
//        }
    }

cleanup:
    return ret;
}

