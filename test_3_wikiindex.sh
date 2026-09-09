#!/bin/bash
# Part 3.1: WikiIndexing on the demo data (15 points).

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

INPUT_URI="hdfs://main:9000/wiki/input/sample.jsonl"
OUTPUT_URI="hdfs://main:9000/wiki/output/sample"

RUN_LOG=out/test_3_wikiindex.out
INDEX_RAW=out/wiki-sample-index.raw
INDEX_OUT=out/wiki-sample-index.txt
VOCAB_OUT=out/wiki-sample-vocab.txt

# Upload the sample and build the index.
function run_wikiindex_demo() {
    dc cp resources/wiki-sample.jsonl main:/wiki-sample.jsonl || return 1
    dc exec -T main bash -e -c '
        hdfs dfs -mkdir -p /wiki/input
        hdfs dfs -put -f /wiki-sample.jsonl /wiki/input/sample.jsonl
    ' || return 1

    bash run-wikiindex.sh "$INPUT_URI" "$OUTPUT_URI"
}

mkdir -p out
rm -f "$INDEX_RAW" "$INDEX_OUT" "$VOCAB_OUT"
score=0

echo -n "Running WikiIndexing on the sample ..."
if run_wikiindex_demo > "$RUN_LOG" 2>&1; then
    pass
else
    fail
    echo "  the application did not finish; see ${RUN_LOG}" >&2
    print_score "0/15 points"
    exit 1
fi

# Collect the index itself: stdout is the file content, stderr goes to the log.
main_exec "hdfs dfs -cat '${OUTPUT_URI}/part-*'" > "$INDEX_RAW" 2>> "$RUN_LOG" || {
    echo "Cannot read the produced index; see ${RUN_LOG}" >&2
    print_score "0/15 points"
    exit 1
}
sed -e 's/\r$//' -e '/^[[:space:]]*$/d' "$INDEX_RAW" | LC_ALL=C sort > "$INDEX_OUT"
cut -f1 "$INDEX_OUT" | LC_ALL=C sort -u > "$VOCAB_OUT"

echo -n "Testing WikiIndexing tokenization (3.1.1) ..."
if [ -s "$VOCAB_OUT" ] && \
   diff --strip-trailing-cr resources/wiki-sample-vocab.truth "$VOCAB_OUT" \
        > out/wiki-sample-vocab.diff 2>&1; then
    pass
    (( score += 5 ))
else
    fail
    echo "  see out/wiki-sample-vocab.diff (expected words vs. produced words)" >&2
fi

echo -n "Testing WikiIndexing index records (3.1.2) ..."
if [ -s "$INDEX_OUT" ] && \
   diff --strip-trailing-cr resources/wiki-sample-index.truth "$INDEX_OUT" \
        > out/wiki-sample-index.diff 2>&1; then
    pass
    (( score += 10 ))
else
    fail
    echo "  see out/wiki-sample-index.diff (expected records vs. produced records)" >&2
fi

print_score "${score}/15 points"
[ "$score" -eq 15 ]
