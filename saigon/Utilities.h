//
//  Utilities.h
//  saïgon
//
//  Created by Abraham Masri on 8/18/17.
//

#ifndef Utilities_h
#define Utilities_h

#include <stdint.h>
#include <stdlib.h>
#include "task_ports.h"
#include "offsets.h"


char * get_internal_model_name();
int ami_jailbroken();
int is_cydia_installed();

kern_return_t set_ports(mach_port_t privileged_port);

void set_procs(uint64_t _self_proc, uint64_t _kern_proc, uint64_t _containermanager);
void get_procs(uint64_t * _self_proc, uint64_t * _kern_proc, uint64_t * _containermanager);

void set_privileged_port(mach_port_t _privileged_port, task_t launchd_task);
mach_port_t get_privileged_port();
mach_port_t get_launchd_task();

void set_self_port_name(mach_port_name_t pt_name);
mach_port_name_t get_self_port_name();

char * utils_get_base64_payload(void * buffer, size_t length);


kern_return_t offsets_init();

void panic_device();
void kill_backboardd();

#endif /* Utilities_h */
