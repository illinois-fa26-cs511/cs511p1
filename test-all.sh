#!/bin/bash
# Grade the whole project: startup, HDFS, Spark and WikiIndexing.
# Run `bash start-all.sh` first.

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

mkdir -p out
total=0

# --- Startup (20 points) ------------------------------------------------------
function test_startup() {
    local node
    for node in main worker1 worker2; do
        node_running "$node" || { echo "container ${node} is not running"; return 1; }
    done
    main_exec 'hdfs version' || { echo "hdfs is not on PATH on main"; return 1; }
    main_exec 'hadoop version' || { echo "hadoop is not on PATH on main"; return 1; }
    main_exec 'spark-submit --version' || { echo "spark-submit is not on PATH on main"; return 1; }
    main_exec 'command -v spark-shell' || { echo "spark-shell is not on PATH on main"; return 1; }
    # start-all.sh also supports the unfinished Part 0 starter, so service
    # readiness belongs here, after checking that the commands are installed.
    wait_for_datanodes 3 any "${STARTUP_TIMEOUT:-600}" out/test_0_readiness.out || {
        echo "HDFS did not report 3 live DataNodes; see out/test_0_readiness.out"
        return 1
    }
    main_exec 'hdfs dfs -ls /' || { echo "the namenode at hdfs://main:9000 is unreachable"; return 1; }
}

echo -n "Testing startup ..."
if test_startup > out/test_0_startup.out 2>&1; then
    pass
    (( total += 20 ))
    startup_score=20
else
    fail
    echo "  see out/test_0_startup.out" >&2
    startup_score=0
fi

# --- Suites -------------------------------------------------------------------
# Run a test script, show its output, and leave the score it printed in
# SUITE_SCORE.
SUITE_SCORE=0
function run_suite() {
    local script="$1" log="$2"
    bash "$script" 2>&1 | tee "$log"
    SUITE_SCORE=$(sed -n 's/^Result: \([0-9]\{1,\}\)\/[0-9]\{1,\} points.*/\1/p' "$log" | tail -n1)
    SUITE_SCORE="${SUITE_SCORE:-0}"
}

echo
run_suite test_1_hadoop.sh out/test_1_hadoop.log
hadoop_score=$SUITE_SCORE
(( total += hadoop_score ))

echo
run_suite test_2_spark.sh out/test_2_spark.log
spark_score=$SUITE_SCORE
(( total += spark_score ))

echo
run_suite test_3_wikiindex.sh out/test_3_wikiindex.log
wiki_score=$SUITE_SCORE
(( total += wiki_score ))

echo
# test_full.sh downloads the dataset itself when resources/wiki-full/ is empty,
# which it is in a fresh clone: the release cannot be committed to git.
run_suite test_full.sh out/test_full.log
full_score=$SUITE_SCORE
(( total += full_score ))

# --- Summary ------------------------------------------------------------------
echo
echo "-----------------------------------"
printf "Startup                     %3d/20\n" "$startup_score"
printf "Part 1  HDFS                %3d/30\n" "$hadoop_score"
printf "Part 2  Spark               %3d/30\n" "$spark_score"
printf "Part 3.1 WikiIndexing demo  %3d/15\n" "$wiki_score"
printf "Part 3.2 WikiIndexing full  %3d/5\n" "$full_score"
echo "-----------------------------------"
echo "Total Points/Full Points: ${total}/100"
echo "(Part 4, the report, is worth another 20 points and is graded by hand.)"
[ "$total" -eq 100 ]
