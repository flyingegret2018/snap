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

int verbose_flag = 0;

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
	"  -n, --num                 How many small blocks (<=4096)\n"
	"  -s, --size_scatter        Size of each scattered block (Total Bytes <= 2MiB)\n"
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
static void snap_prepare_scatter_gather(struct snap_job *cjob,
				 struct scatter_gather_job *mjob_in,
				 struct scatter_gather_job *mjob_out,
				 // Software-Hardware Interface
				 uint64_t WED_addr,
				 uint64_t ST_addr)
{
//	fprintf(stderr, "  prepare scatter_gather job of %ld bytes size\n", sizeof(*mjob_in));
	mjob_in->WED_addr = WED_addr;
	mjob_in->ST_addr  = ST_addr;

	snap_job_set(cjob, mjob_in, sizeof(*mjob_in), mjob_out, sizeof(*mjob_out));
}


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
	struct snap_job cjob;
	struct scatter_gather_job mjob_in, mjob_out;
//	struct timeval etime, stime;
	unsigned long timeout = 30;
	// default is interrupt mode disabled (take polling)
	snap_action_flag_t action_irq = 0;
	int exit_code = EXIT_SUCCESS;

	int check_pass = 1;
	uint16_t mode=1;
	uint32_t size_scatter=2048;
	uint32_t num=8;
	//////////////////////////////////////////////////
	// Prepare the scattered blocks
	//////////////////////////////////////////////////
	
	uint32_t i, j;

	int32_t *gather_ptr;
	int32_t *result_ptr_golden;
	int32_t *result_ptr;
	int32_t **scatter_ptr_list;
	ssize_t *scatter_size_list;
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
			{ "irq",	 no_argument,	    NULL, 'I' },
			{ "version",	 no_argument,	    NULL, 'V' },
			{ "verbose",	 no_argument,	    NULL, 'v' },
			{ "help",	 no_argument,	    NULL, 'h' },
			{ 0,		 no_argument,	    NULL, 0   },
		};

		ch = getopt_long(argc, argv,
                                 "C:t:m:s:n:IVvh",
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
                case 'I':
                        action_irq = 1;
                        break;
			/* service */
		case 'V':
			printf("%s\n", version);
			exit(EXIT_SUCCESS);
		case 'v':
			verbose_flag ++;
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

	if(mode >= 4 || num > 4096 || num*size_scatter > 2*1024*1024) {
		VERBOSE0("illegal arguments.\n");
		usage(argv[0]);
		exit(EXIT_FAILURE);
	}

	
	// Timer starts
	gettimeofday(&curr_time, NULL);

	/////////////////////////////////////////////////////////////////////////////////
	// Allocate memories
	scatter_size_list = snap_malloc(sizeof(size_t) * num);
	scatter_ptr_list = snap_malloc(sizeof(int32_t *) * num);
	result_ptr_golden = snap_malloc(size_scatter * num);
	result_ptr = snap_malloc(size_scatter * num);
	gather_ptr = snap_malloc(size_scatter * num);
	as_pack = snap_malloc(num*sizeof(as_pack_t));


	for (i = 0; i < num; i++) {
		scatter_size_list[i] = size_scatter;
	}
	for (i = 0; i < num; i++) {
		scatter_ptr_list[i] = snap_malloc(scatter_size_list[i]);
		for (j = 0; j < size_scatter/sizeof(uint32_t); j++)
			scatter_ptr_list[i][j] = rand()&0xFF;
		as_pack[i].addr = (unsigned long long ) scatter_ptr_list[i]; //8B

		//Copy the golden gathered block
		memcpy(result_ptr_golden + i * size_scatter/sizeof(uint32_t), scatter_ptr_list[i], size_scatter);
	}


	/////////////////////////////////////////////////////////////////////////////////
	// WED and STATUS
	wed_ptr = snap_malloc(sizeof(wed_t));
	status_ptr = snap_malloc(sizeof(status_t));
	// Set init value
	memset(wed_ptr, 0, 128);
	memset(status_ptr, 0, 128);
	
	/* Display the parameters that will be used for the example */
	VERBOSE0("PARAMETERS:\n"
		 " gather @ %p\n"
		 " golden @ %p\n"
		 " result @ %p\n",
		 gather_ptr,
		 result_ptr_golden,
		 result_ptr);

	VERBOSE0("Mode = %d\n", mode);
	VERBOSE0("Num = %d\n", num);
	VERBOSE0("Size_scatter = %d\n", size_scatter);
	

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


	snap_prepare_scatter_gather(&cjob, &mjob_in, &mjob_out,
				(unsigned long long) wed_ptr,
				(unsigned long long) status_ptr);

	print_timestamp("SNAP prepare job_t structure");

	//Write the registers into the FPGA's action
	rc = snap_action_sync_execute_job_set_regs(action, &cjob);
	if (rc != 0)
		goto out_error2;


	print_timestamp("Use MMIO to transfer the parameters");

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
	snap_action_start(action);
	print_timestamp("Use MMIO to kick off \"Action Start\"");


	// stop the action if not done and read all registers from the action
	// rc = snap_action_sync_execute_job_check_completion(action, &cjob,
	//			timeout);

	//Just check stop bit and don't read registers
	snap_action_completed(action, &rc, timeout);
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
				VERBOSE0("ERROR, compare mismatch at %d, (%d <> %d)\n", i,
						result_ptr[i], result_ptr_golden[i]);
				check_pass = 0;
				break;
			}
		}
		if(check_pass)
			VERBOSE0("Checking Passed.\n");
	}

	//Check return code
	switch(cjob.retc) {
	case SNAP_RETC_SUCCESS:
		fprintf(stdout, "SUCCESS\n");
		break;
//	case SNAP_RETC_TIMEOUT:
//		fprintf(stdout, "ACTION TIMEOUT\n");
//		break;
	case SNAP_RETC_FAILURE:
		fprintf(stdout, "FAILED\n");
		fprintf(stderr, "err: Unexpected RETC=%x!\n", cjob.retc);
		goto out_error2;
		break;
	default:
		break;
	}

	// Detach action + disallocate the card
	printf("====================  All job finished ==================\n");
	snap_detach_action(action);
	print_timestamp("Detach action");
	
	snap_card_free(card);
	print_timestamp("Close the card");

	for(i = 0; i < num; i++) {
		__free((uint32_t *)scatter_ptr_list[i]);
	}
	__free(scatter_ptr_list);
	__free(scatter_size_list);
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
	for(i = 0; i < num; i++)
		__free(scatter_ptr_list[i]);
	__free(scatter_ptr_list);
	__free(scatter_size_list);
	__free(result_ptr_golden);
	__free(result_ptr);
	__free(as_pack);
	__free(gather_ptr);
 out_error:
	exit(EXIT_FAILURE);
}
