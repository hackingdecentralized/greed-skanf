#!/bin/bash
set -euo pipefail

count=0
MAX_RETRIES=10
TIMEOUT=120
FIX=false
LOOP=false

while (( $# >= 1 )); do
    case "$1" in
        --file)
            if (( $# < 2 )); then
                echo "error: --file requires an argument"
                exit 1
            fi
            HEX_FILE="$2"
            shift 2
            ;;
        --timeout)
            if (( $# < 2 )); then
                echo "error: --timeout requires an argument"
                exit 1
            fi
            TIMEOUT="$2"
            shift 2
            ;;
        --fix)
            FIX=true
            shift
            ;;
        --loop)
            LOOP=true
            shift
            ;;
        *)
            echo "unknown argument: $1"
            echo "usage: analyze_hex.sh --file <contract .hex file> [--timeout <timeout>] [--fix] [--loop]"
            exit 1
            ;;
    esac
done

if [[ -z "${HEX_FILE:-}" ]]; then
    echo "usage: analyze_hex.sh --file <contract .hex file> [--timeout <timeout>] [--fix] [--loop]"
    exit 1
fi

if [[ ! -f "$HEX_FILE" ]]; then
    echo "$HEX_FILE is not a file"
    exit 1
fi

# Downstream analysis expects the input file to be named contract.hex.
# If the user provides another file name, normalize it to ./contract.hex.
if [[ "$(basename "$HEX_FILE")" != "contract.hex" ]]; then
    cp -- "$HEX_FILE" contract.hex
    HEX_FILE="contract.hex"
fi

FILEPATH=`readlink -f "${BASH_SOURCE[0]}"`
GREED_DIR=`dirname $FILEPATH`
GREED_DIR=`readlink -f $GREED_DIR/../`
GIGAHORSE_DIR=$GREED_DIR/gigahorse-toolchain

if [ ! -f $GIGAHORSE_DIR/clients/main.dl_compiled ]; then
  echo "Can't find main.dl_compiled (something went wrong in setup.sh)"
  exit 1
elif [ ! -f $GIGAHORSE_DIR/clients/greed_client.dl_compiled ]; then
  echo "Can't find greed_client.dl_compiled (something went wrong in setup.sh)"
  exit 1
fi

if [[ $FIX == true ]]; then
  $GIGAHORSE_DIR/gigahorse.py  $HEX_FILE -q -T $TIMEOUT --reuse_datalog_bin --disable_inline -C $GIGAHORSE_DIR/clients/greed_client.dl_compiled,$GIGAHORSE_DIR/clients/visualizeout.py,$GIGAHORSE_DIR/clients/jump_table_analysis.dl_compiled
  echo "Round 0 done. Now starting fix loop."
  /usr/bin/time -v $GIGAHORSE_DIR/gigahorse.py  $HEX_FILE -q -T $TIMEOUT --reuse_datalog_bin --disable_inline -C $GIGAHORSE_DIR/clients/greed_client.dl_compiled,$GIGAHORSE_DIR/clients/visualizeout.py,$GIGAHORSE_DIR/clients/jump_table_analysis.dl_compiled --fix &> exec_info && curr_dir=$(pwd) && cd $GIGAHORSE_DIR && gigahorse_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tGigahorse version: $gigahorse_version\n" >> exec_info && curr_dir=$(pwd) && cd $GREED_DIR && greed_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tgreed version: $greed_version\n" >> exec_info
  if [ "$LOOP" = true ]; then
    while true; do
      curr_dir=$(pwd)
      output=$(python3 $GIGAHORSE_DIR/check_jumptable.py $curr_dir/.temp/contract/out $curr_dir/.temp/contract_fixed/out)

      if [ "$output" == "DONE" ]; then
          echo "Execution result is DONE. Exiting loop."
          break
      fi

      count=$((count+1))
      if [ $count -ge $MAX_RETRIES ]; then
          echo "Exceeded maximum retries. Exiting."
          break
      fi

      echo "Output: $output. Retrying $count..."
      rm -rf .temp/contract_fixed
      /usr/bin/time -v $GIGAHORSE_DIR/gigahorse.py  $HEX_FILE -q -T $TIMEOUT --reuse_datalog_bin --disable_inline -C $GIGAHORSE_DIR/clients/greed_client.dl_compiled,$GIGAHORSE_DIR/clients/visualizeout.py,$GIGAHORSE_DIR/clients/jump_table_analysis.dl_compiled --fix &> exec_info && curr_dir=$(pwd) && cd $GIGAHORSE_DIR && gigahorse_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tGigahorse version: $gigahorse_version\n" >> exec_info && curr_dir=$(pwd) && cd $GREED_DIR && greed_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tgreed version: $greed_version\n" >> exec_info
    done
  fi
  cp .temp/contract_fixed/out/* .
  cp .temp/contract_fixed/contract.dasm .
  cp .temp/contract_fixed/contract_patch.dasm .
  cp .temp/contract_fixed/*.csv .
  cp .temp/contract/out/JTA* .
else
  /usr/bin/time -v $GIGAHORSE_DIR/gigahorse.py  $HEX_FILE -q -T $TIMEOUT --reuse_datalog_bin --disable_inline -C $GIGAHORSE_DIR/clients/greed_client.dl_compiled,$GIGAHORSE_DIR/clients/visualizeout.py,$GIGAHORSE_DIR/clients/jump_table_analysis.dl_compiled &> exec_info && curr_dir=$(pwd) && cd $GIGAHORSE_DIR && gigahorse_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tGigahorse version: $gigahorse_version\n" >> exec_info && curr_dir=$(pwd) && cd $GREED_DIR && greed_version=$(git rev-parse HEAD) && cd $curr_dir && printf "\tgreed version: $greed_version\n" >> exec_info
  cp .temp/contract/out/* .
  cp .temp/contract/contract.dasm .
  cp .temp/contract/*.csv .
fi
mv bytecode.hex contract.hex
rm -rf .temp Analytics_ReachableUnderContext.csv Analytics_Contexts.csv
chmod 664 *
