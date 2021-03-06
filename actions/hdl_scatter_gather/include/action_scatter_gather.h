#ifndef __ACTION_SCATTER_GATHER_H__
#define __ACTION_SCATTER_GATHER_H__

/*
 * Copyright 2018 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <snap_types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* This number is unique and is declared in ~snap/ActionTypes.md */
#define SCATTER_GATHER_ACTION_TYPE 0x1014100B

	
#define ST_READ_WED_DONE 4
#define ST_READ_DATA_DONE 5
#define ST_DONE 6

#define ADDR0_ACADDR0   0x30
#define ADDR1_ACADDR1   0x34
#define ADDR2_START     0x38
#define ADDR3_DONE      0x3C
#define ADDR4_MODE      0x40
#define ADDR5_BLOCKSIZE 0x44
#define ADDR6_BLOCKNUM  0x48
#define ADDR7_WBADDR0   0x4C
#define ADDR8_WBADDR1   0x50
#define ADDR9_GADDR0    0x54
#define ADDR10_GADDR1   0x58
#define ADDR11_GSIZE    0x5C
    
	
typedef struct __attribute__ ((__packed__)) as_pack {
	uint64_t addr;
}as_pack_t;

//Status in shared memory
//It takes 128bytes. (1 cacheline)
typedef struct __attribute__((__packed__)) status {
	uint32_t stage;
	uint8_t paddings[124];
}status_t;

//Word element descriptor in shared memory
//It takes 128bytes. (1 cacheline)
typedef struct __attribute__((__packed__)) wed {
	uint64_t G_addr; 
	uint64_t AS_addr;
	uint64_t R_addr;
	uint32_t G_size;
	uint32_t AS_size;
	
	uint32_t num;
	uint32_t size_scatter;
	uint16_t mode;
	uint8_t paddings[94];
} wed_t ;


/* Data structure used to exchange information between action and application */
/* Size limit is 108 Bytes */
/* This will be reflected in FPGA action_reg */
typedef struct scatter_gather_job {
	uint64_t WED_addr;
	uint64_t ST_addr;
} scatter_gather_job_t;

#ifdef __cplusplus
}
#endif

#endif	/* __ACTION_SCATTER_GATHER_H__ */
