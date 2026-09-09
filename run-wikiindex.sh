#!/bin/bash
# Run the WikiIndexing application (Part 3) on the cluster.
#
#   bash run-wikiindex.sh <input_uri> <output_uri>
#
# The test scripts reach your application only through this file, so do not
# modify it. It submits wikiindex.py, or a wikiindex.jar taking its main class
# from the jar manifest when no wikiindex.py is present.

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

if [ "$#" -ne 2 ]; then
    echo "usage: bash run-wikiindex.sh <input_uri> <output_uri>" >&2
    exit 2
fi

INPUT_URI="$1"
OUTPUT_URI="${2%/}"
case "$INPUT_URI" in hdfs://main:9000/?*) ;; *) echo "Input must use hdfs://main:9000/" >&2; exit 2 ;; esac
case "$OUTPUT_URI" in hdfs://main:9000/?*) ;; *) echo "Output must be a directory below hdfs://main:9000/" >&2; exit 2 ;; esac
for uri in "${INPUT_URI%/}" "$OUTPUT_URI"; do
    case "/${uri#hdfs://main:9000/}/" in
        *'/../'*|*'/./'*|*'//'*) echo "Use normalized HDFS paths" >&2; exit 2 ;;
    esac
done
case "${INPUT_URI%/}/" in "$OUTPUT_URI/"*) echo "Output must not contain the input" >&2; exit 2 ;; esac

if [ -f wikiindex.py ]; then
    APP=wikiindex.py
elif [ -f wikiindex.jar ]; then
    APP=wikiindex.jar
else
    echo "neither wikiindex.py nor wikiindex.jar is in the repository root" >&2
    exit 1
fi

dc cp "$APP" "main:/${APP}" || exit 1

# Spark refuses to write into an existing directory.
dc exec -T main hdfs dfs -rm -r -f "$OUTPUT_URI" || exit 1

dc exec -T main spark-submit \
    --master spark://main:7077 \
    "/${APP}" "$INPUT_URI" "$OUTPUT_URI"
