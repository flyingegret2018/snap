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

/**
 * SNAP Scatter gather array fetch Evaluation
 *
 * Assume we have N small memory blocks, compare the time between
 * 1) Software copies them to a continuous memory space, and transfers to FPGA (mode=0)
 * 2) FPGA fetches the N blocks directly with an address list. (Only with CAPI) (mode=1)
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <getopt.h>
#include <malloc.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <assert.h>

#include <snap_tools.h>
#include <libsnap.h>
#include <action_scatter_gather.h>
#include <snap_hls_if.h>

int verbose_level = 0;

static const char *version = GIT_VERSION;
static struct timeval last_time, curr_time;

#define VERBOSE0(fmt, ...) do {		\
		printf(fmt, ## __VA_ARGS__);	\
	} while (0)

#define VERBOSE1(fmt, ...) do {		\
		if (verbose_level > 0)	\
			printf(fmt, ## __VA_ARGS__);	\
	} while (0)

#define VERBOSE2(fmt, ...) do {		\
		if (verbose_level > 1)	\
			printf(fmt, ## __VA_ARGS__);	\
	} while (0)


#define VERBOSE3(fmt, ...) do {		\
		if (verbose_level > 2)	\
			printf(fmt, ## __VA_ARGS__);	\
	} while (0)

#define VERBOSE4(fmt, ...) do {		\
		if (verbose_level > 3)	\
			printf(fmt, ## __VA_ARGS__);	\
	} while (0)


static void print_humanread_size(uint64_t in)
{
	uint64_t G, M, K;

	G = in / (1024*1024*1024);
	in = in - G*1024*1024*1024;

	M = in / (1024*1024);
	in = in - M*1024*1024;

	K = in / 1024;
	in = in - K*1024;

	if(G)
		VERBOSE0("%ld GiB ", G);
	if(M)
		VERBOSE0("%ld MiB ", M);
	if(K)
		VERBOSE0("%ld KiB ", K);
	if(in)
		VERBOSE0("%ld Bytes ", in);
}

/*
static void *memcpy_from_volatile(void *dest, volatile void *src, size_t n)
{
    char *dp = dest;
    volatile char *sp = src;
    while (n--)
        *dp++ = *sp++;
    return dest;
}
static int memcmp_volatile(volatile void* s1, const void* s2,size_t n)
{
    volatile unsigned char *p1 = s1;
    const unsigned char *p2 = s2;
    while(n--)
        if( *p1 != *p2 )
            return *p1 - *p2;
        else
            p1++,p2++;
    return 0;
}
static void memset_volatile(volatile void *s, char c, size_t n)
{
    volatile char *p = s;
    while (n-- > 0) {
        *p++ = c;
    }
}
*/
/**
 * @brief	prints valid command line options
 *
 * @param prog	current program's name
 */
static void usage(const char *prog)
{
	printf("Usage: %s [-h] [-V, --version]\n"
	"  -C, --card <cardno>       Can be (0...3)\n"
	"  -t, --timeout             Timeout in sec to wait for done.\n"
	"  -v, --verbose             Print timers for how long each job takes\n"
	"  -m, --mode                0: SW collects scattered memory blocks and send to FPGA. \n"
	"                            1: FPGA fetches scattered memory blocks directly. \n"
	"  -n, --num                 How many small blocks (<=16384)\n"
	"  -s, --size_scatter        Size of each scattered block (Total Bytes <= 8MiB)\n"
	"  -R, --rand_order          -R: Randomly choose 'num' blocks from 'K*num' blocks.\n"
        "     	                     Default(no -R): transfer 'num' blocks sequentially. K is forced to be 1. \n"
	"  -K,  (1,...,8192)         Make a wider memory range. Default: 1\n"
	"                            Malloc K*'num' blocks, and just pick up 'num' blocks to tranfer.\n"
	"  -I, --irq                 Use Interrupts (not suggested)\n"
	"\n"
	"Example on a real card:\n"
	"----------------------------\n"
        "cd /home/snap && export ACTION_ROOT=/home/snap/actions/hls_scatter_gather\n"
        "source snap_path.sh\n"
        "sudo snap_maint -vv\n"
        "------only once for above---\n"
        "\n",
        prog);
}

static inline void print_timestamp(const char * msg)
{
	last_time = curr_time;
	gettimeofday(&curr_time, NULL);
	unsigned long long int lcltime = 0x0ull;
	lcltime = (long long)(timediff_usec(&curr_time, &last_time));
	fprintf(stdout, "    It takes %lld usec for %s\n", lcltime, msg);
}

// Function that fills the MMIO registers / data structure 
// these are all data exchanged between the application and the action
//static void snap_prepare_scatter_gather(struct snap_job *cjob,
//				 struct scatter_gather_job *mjob_in,
//				 struct scatter_gather_job *mjob_out,
				 // Software-Hardware Interface
//				 uint64_t WED_addr,
//				 uint64_t ST_addr)
//{
//	fprintf(stderr, "  prepare scatter_gather job of %ld bytes size\n", sizeof(*mjob_in));
//	mjob_in->WED_addr = WED_addr;
//	mjob_in->ST_addr  = ST_addr;

//	snap_job_set(cjob, mjob_in, sizeof(*mjob_in), mjob_out, sizeof(*mjob_out));
//}


// main program of the application for the hls_scatter_gather example
// This application will always be run on CPU and will call either
// a software action (CPU executed) or a hardware action (FPGA executed)
int main(int argc, char *argv[])
{
	// Init of all the default values used 
	int ch, rc = 0;
	int card_no = 0;
	struct snap_card *card = NULL;
	struct snap_action *action = NULL;
	char device[128];
//	struct snap_job cjob;
//	struct scatter_gather_job mjob_in, mjob_out;
//	struct timeval etime, stime;
	unsigned long timeout = 30;
	// default is interrupt mode disabled (take polling)
	snap_action_flag_t action_irq = 0;
	int exit_code = EXIT_SUCCESS;

	int check_pass = 1;
	uint16_t mode=1;
	uint32_t size_scatter=2048;
	uint32_t num=1024;
	//////////////////////////////////////////////////
	// Prepare the scattered blocks
	//////////////////////////////////////////////////
	
	uint32_t i, j, s;
	int K = 1;
	int rand_order = 0;

	int32_t *gather_ptr;
	int32_t *result_ptr_golden;
	int32_t *result_ptr;
	int32_t **scatter_ptr_list;
	int32_t *mem_pool=NULL;
	//ssize_t *scatter_size_list;
	as_pack_t *as_pack;

	wed_t   *wed_ptr = NULL;
	status_t *status_ptr = NULL;

	
	// collecting the command line arguments
	while (1) {
		int option_index = 0;
		static struct option long_options[] = {
			{ "card",	 required_argument, NULL, 'C' },
			{ "timeout",	 required_argument, NULL, 't' },
			{ "mode", 	 required_argument, NULL, 'm' },
			{ "size", 	 required_argument, NULL, 's' },
			{ "num", 	 required_argument, NULL, 'n' },
			{ "K",	 	 required_argument, NULL, 'K' },
			{ "rand_order",	 no_argument,	    NULL, 'R' },
			{ "irq",	 no_argument,	    NULL, 'I' },
			{ "version",	 no_argument,	    NULL, 'V' },
			{ "verbose",	 no_argument,	    NULL, 'v' },
			{ "help",	 no_argument,	    NULL, 'h' },
			{ 0,		 no_argument,	    NULL, 0   },
		};

		ch = getopt_long(argc, argv,
                                 "C:t:m:s:n:K:RIVvh",
				 long_options, &option_index);
		if (ch == -1)
			break;

		switch (ch) {
		case 'C':
			card_no = strtol(optarg, (char **)NULL, 0);
			break;
                case 't':
                        timeout = strtol(optarg, (char **)NULL, 0);
                        break;		
                case 'm':
                        mode = strtol(optarg, (char **)NULL, 0);
                        break;		
                case 's':
                        size_scatter = strtol(optarg, (char **)NULL, 0);
                        break;		
                case 'n':
                        num = strtol(optarg, (char **)NULL, 0);
                        break;		
                case 'K':
                        K = strtol(optarg, (char **)NULL, 0);
                        break;		
                case 'R':
                        rand_order = 1;
                        break;
                case 'I':
                        action_irq = 1;
                        break;
			/* service */
		case 'V':
			printf("%s\n", version);
			exit(EXIT_SUCCESS);
		case 'v':
			verbose_level ++;
			break;
		case 'h':
			usage(argv[0]);
			exit(EXIT_SUCCESS);
			break;
		default:
			usage(argv[0]);
			exit(EXIT_FAILURE);
		}
	}

	if (optind != argc) {
		usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	if(mode >= 4 || num > 16384 || num*size_scatter > 8*1024*1024) {
		VERBOSE0("illegal arguments.\n");
		usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	
	// Timer starts
	gettimeofday(&curr_time, NULL);

	if(rand_order == 0) {
		VERBOSE0("All small blocks are in sequence. K = %d\n", K);
	}
	else
		VERBOSE0("Pick up blocks randomly. K = %d\n", K);

	/////////////////////////////////////////////////////////////////////////////////
	// Allocate memories
	//scatter_size_list = snap_malloc(sizeof(size_t) * num);
	
	scatter_ptr_list = snap_malloc(sizeof(int32_t *) * num);
	result_ptr_golden = snap_malloc(size_scatter * num);
	result_ptr = snap_malloc(size_scatter * num);
	gather_ptr = snap_malloc(size_scatter * num);
	as_pack = snap_malloc(num*sizeof(as_pack_t));


	//for (i = 0; i < num; i++) {
	//	scatter_size_list[i] = size_scatter;
	//}

	//Malloc scattered blocks in a bigger range, decided by K
	VERBOSE0("before malloc\n");
	mem_pool = snap_malloc((uint64_t)K*(uint64_t)num*(uint64_t)size_scatter);
	if(mem_pool == NULL)
	{
		print_humanread_size((uint64_t)K*(uint64_t)num*(uint64_t)size_scatter);
		VERBOSE0("Error: mem_pool allocation fail.\n");
		goto out_error0;
	}
	VERBOSE1("Print some addresses ............ \n");
	for (i = 0; i < num; i++) {

		if (rand_order)
			j = rand()%(num * K); 
		else
			j = i * K;


		scatter_ptr_list[i] = (int32_t *)((unsigned long long)mem_pool + j*size_scatter);

		//Initialize the scattered blocks
		for (s = 0; s < size_scatter/sizeof(int32_t); s++)
		{
			scatter_ptr_list[i][s] = rand()&0xFF;
		}

		as_pack[i].addr = (unsigned long long ) scatter_ptr_list[i]; //8B
		



		//Print addresses for checking. (part of them)
		if (i >= 996 )
		{
			VERBOSE1("%5d: 0x%016lx", i, as_pack[i].addr);
			if(i %6 == 5)
				VERBOSE1("\n");
		}
	}
	VERBOSE1("\n");

	for (i = 0; i < num; i++)
	{
		//Copy to the golden gathered block
		memcpy(result_ptr_golden + i * size_scatter/sizeof(int32_t), scatter_ptr_list[i], size_scatter);
	}

	/////////////////////////////////////////////////////////////////////////////////
	// WED and STATUS
	wed_ptr = snap_malloc(sizeof(wed_t));
	status_ptr = snap_malloc(sizeof(status_t));
	// Set init value
	memset(wed_ptr, 0, 128);
	memset(status_ptr, 0, 128);
	
	/* Display the parameters that will be used for the example */
	VERBOSE2("PARAMETERS:\n"
		 " gather @ %p\n"
		 " golden @ %p\n"
		 " result @ %p\n",
		 gather_ptr,
		 result_ptr_golden,
		 result_ptr);

	VERBOSE0("Mode = %d\n", mode);
	VERBOSE0("Num = %d, Size for each block is %d\n", num, size_scatter);
	VERBOSE0("Blocks are ");
	VERBOSE0(rand_order? "randomly ": "sequentially ");
	VERBOSE0("distributed in ");
	print_humanread_size((uint64_t)K*(uint64_t)num*(uint64_t)size_scatter);
	VERBOSE0("\n");
	VERBOSE0("Page size = %ld\n", sysconf(_SC_PAGESIZE));
	

	wed_ptr->mode = mode;
	wed_ptr->size_scatter = size_scatter;
	wed_ptr->num = num;
	wed_ptr->R_addr = (unsigned long long) result_ptr;
	wed_ptr->G_addr = (unsigned long long) gather_ptr;
	wed_ptr->G_size = num * size_scatter;
	wed_ptr->AS_addr = (unsigned long long) &as_pack[0]; 
	wed_ptr->AS_size = size_scatter;
	
	print_timestamp("Allocate and prepare buffers");



	/////////////////////////////////////////////////////////////////////////////////
	// Open the card

	// Allocate the card that will be used
	snprintf(device, sizeof(device)-1, "/dev/cxl/afu%d.0s", card_no);
	card = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM,
				   SNAP_DEVICE_ID_SNAP);
	if (card == NULL) {
		fprintf(stderr, "err: failed to open card %u: %s\n",
			card_no, strerror(errno));
		goto out_error;
	}
	print_timestamp("Open the card");

	// Attach the action that will be used on the allocated card
	action = snap_attach_action(card, SCATTER_GATHER_ACTION_TYPE, action_irq, 60);
	if (action == NULL) {
		fprintf(stderr, "err: failed to attach action %u: %s\n",
			card_no, strerror(errno));
		goto out_error1;
	}

	print_timestamp("Attach action");


//	snap_prepare_scatter_gather(&cjob, &mjob_in, &mjob_out,
//				(unsigned long long) wed_ptr,
//				(unsigned long long) status_ptr);
//
//	print_timestamp("SNAP prepare job_t structure");

	//Write the registers into the FPGA's action
//	rc = snap_action_sync_execute_job_set_regs(action, &cjob);
//	if (rc != 0)
//		goto out_error2;



	/////////////////////////////////////////////////////////////////////////////////
	//  Copy starts
	
	if ((mode & 0x1) == 0) {
		//Software collects the blocks first. 
		for(i = 0; i < num; i++) {
			memcpy(gather_ptr + i * size_scatter/sizeof(uint32_t), scatter_ptr_list[i], size_scatter);
		}
		print_timestamp("Software gathers blocks");
	}
	// Start Action

    VERBOSE2("as_pack first addr: 0x%lx\n", wed_ptr->AS_addr);
    VERBOSE2("timeout is %ld, but no use\n", timeout);
	
    VERBOSE0("==================== Starting Action  ==================\n");
    ///////////////////////
    snap_mmio_write32(card, (uint64_t)ADDR0_ACADDR0, 	wed_ptr->AS_addr >> 32);
    snap_mmio_write32(card, (uint64_t)ADDR1_ACADDR1, 	wed_ptr->AS_addr & 0xFFFFFFFF);
    snap_mmio_write32(card, (uint64_t)ADDR9_GADDR0, 	wed_ptr->G_addr >> 32);
    snap_mmio_write32(card, (uint64_t)ADDR10_GADDR1, 	wed_ptr->G_addr & 0xFFFFFFFF);
    snap_mmio_write32(card, (uint64_t)ADDR11_GSIZE, 	wed_ptr->G_size);
    snap_mmio_write32(card, (uint64_t)ADDR4_MODE, 	(uint32_t)mode);
    snap_mmio_write32(card, (uint64_t)ADDR5_BLOCKSIZE, 	size_scatter);
    snap_mmio_write32(card, (uint64_t)ADDR6_BLOCKNUM, 	num);
    snap_mmio_write32(card, (uint64_t)ADDR2_START,  	0x00000001);
	print_timestamp("Use MMIO to transfer the parameters");
	
//    snap_action_start(action);
//	print_timestamp("Use MMIO to kick off \"Action Start\"");


	// stop the action if not done and read all registers from the action
	// rc = snap_action_sync_execute_job_check_completion(action, &cjob,
	//			timeout);


    // Poll Register Done
    do {
        //int rc;
        uint32_t data;
        rc = snap_mmio_read32(card, (uint64_t)ADDR3_DONE, &data);
        if (data == 1) {
            VERBOSE0 ("scatter done!\n");
            break;
        }
    } while (1);


	//Just check stop bit and don't read registers
	//snap_action_completed(action, &rc, timeout);
	print_timestamp("Use MMIO to poll \"Action Stop\" bit");


	if (rc != 0) {
		fprintf(stderr, "err: job execution %d: %s!\n", rc,
			strerror(errno));
		goto out_error2;
	}

	/////////////////////////////////////////////////////////////////////////////////
	//Check result
	if ((mode & 0x2) == 2) {
		VERBOSE0("Copy data back for checking\n");
		for (i = 0; i < num *  size_scatter/sizeof(uint32_t); i++) {
			if (result_ptr[i] != result_ptr_golden[i])
			{
				VERBOSE0("ERROR, compare mismatch at %d, (%x <> %x)\n", i,
						result_ptr[i], result_ptr_golden[i]);
				check_pass = 0;
				break;
			}
		}
		if(check_pass)
			VERBOSE0("Checking Passed.\n");
	}

//	//Check return code
//	switch(cjob.retc) {
//	case SNAP_RETC_SUCCESS:
//		fprintf(stdout, "SUCCESS\n");
//		break;
////	case SNAP_RETC_TIMEOUT:
////		fprintf(stdout, "ACTION TIMEOUT\n");
////		break;
//	case SNAP_RETC_FAILURE:
//		fprintf(stdout, "FAILED\n");
//		fprintf(stderr, "err: Unexpected RETC=%x!\n", cjob.retc);
//		goto out_error2;
//		break;
//	default:
//		break;
//	}

	// Detach action + disallocate the card
	VERBOSE0("====================  All job finished ==================\n");
	snap_detach_action(action);
	print_timestamp("Detach action");
	
	snap_card_free(card);
	print_timestamp("Close the card");

	__free(scatter_ptr_list);
	__free(mem_pool);

	//__free(scatter_size_list);
	__free(result_ptr_golden);
	__free(result_ptr);
	__free(gather_ptr);
	__free(as_pack);
	print_timestamp("Free all buffers");
	exit(exit_code);

 out_error2:
	snap_detach_action(action);
 out_error1:
	snap_card_free(card);
 out_error0:
	__free(mem_pool);
	__free(scatter_ptr_list);
	//__free(scatter_size_list);
	__free(result_ptr_golden);
	__free(result_ptr);
	__free(as_pack);
	__free(gather_ptr);
 out_error:
	exit(EXIT_FAILURE);
}
