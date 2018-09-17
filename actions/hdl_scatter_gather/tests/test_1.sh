#!/bin/bash

#
# Copyright 2017 International Business Machines
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

verbose=0
snap_card=0
duration="SHORT"
num=1024
scatter_size=2048
interrupt=0

# Get path of this script
THIS_DIR=$(dirname $(readlink -f "$BASH_SOURCE"))
ACTION_ROOT=$(dirname ${THIS_DIR})
SNAP_ROOT=$(dirname $(dirname ${ACTION_ROOT}))

function usage() {
    echo "Usage:"
    echo "  test_<action_type>.sh"
    echo "    [-C <card>]        card to be used for the test"
    echo "    [-t <trace_level>]"
    echo "    [-duration SHORT/NORMAL/LONG] run tests"
    echo "    [-n num]  num of blocks"
    echo "    [-s scatter_size] scatter_size: how many bytes in a block"
    echo "    [-I] enable interrupt"
    echo
}

while getopts ":C:t:d:n:s:Ih" opt; do
    case $opt in
	C)
	snap_card=$OPTARG;
	;;
	t)
	export SNAP_TRACE=$OPTARG;
	;;
	d)
	duration=$OPTARG;
	;;
	n)
	num=$OPTARG;
	;;
	s)
	scatter_size=$OPTARG;
	;;
	I)
	interrupt=1;
	;;
	h)
	usage;
	exit 0;
	;;
	\?)
	echo "Invalid option: -$OPTARG" >&2
	;;
    esac
done

export PATH=$PATH:${SNAP_ROOT}/software/tools:${ACTION_ROOT}/sw:${ACTION_ROOT}/tests

snap_peek --help > /dev/null || exit 1;
snap_poke --help > /dev/null || exit 1;

#### VERSION ##########################################################

# [ -z "$STATE" ] && echo "Need to set STATE" && exit 1;

if [ -z "$SNAP_CONFIG" ]; then
	echo "CARD VERSION"
	snap_maint -C ${snap_card} -v || exit 1;
	snap_peek -C ${snap_card} 0x0 || exit 1;
	snap_peek -C ${snap_card} 0x8 || exit 1;
	echo
fi

#### RUN  ##########################################################
rm -f snap_scatter_gather.log
touch snap_scatter_gather.log

if [ $duration = "SHORT" ]; then
	tests=5
elif [ $duration = "NORMAL" ]; then
	tests=20
else
	tests=100
fi
echo "Run $tests tests for each testpoint. (num = $num, scatter_size = $scatter_size)"

args=("-W" "-K1" "-RK1" "-RK4" "-RK16" "-RK64" "-RK256" "-RK2048")
#args=("-W" " " "-RK4" "-RK16" "-RK64" "-RK256" "-RK2048" "-RK8192")

for arg in ${args[*]} ; do
    echo "Testpoint: -n$num -s$scatter_size $arg" >> snap_scatter_gather.log 
    for i in $(seq 1 ${tests}) ; do
    echo -n "Run $i: "
	cmd="snap_scatter_gather -C${snap_card} -n$num -s$scatter_size $arg \
			>> snap_scatter_gather.log 2>&1"
	echo -n "$cmd ..."

	echo "$cmd" >> snap_scatter_gather.log
	eval ${cmd}


	if [ $? -ne 0 ]; then
		echo "Check snap_scatter_gather.log"
		echo "cmd: ${cmd}"
		echo "failed"
		exit 1
	fi
	echo "ok"
    done
done

cmd="process.awk snap_scatter_gather.log"
eval ${cmd}
if [ $? -ne 0 ]; then
   echo "failed"
   exit 1
fi
rm -f  *.txt *.out
echo "Test OK"
exit 0
