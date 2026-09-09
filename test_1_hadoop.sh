#!/bin/bash
# Part 1: HDFS deployment tests (30 points).

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

# A DataNode is only declared dead after the NameNode has missed enough
# heartbeats: 2 * dfs.namenode.heartbeat.recheck-interval + 10 *
# dfs.heartbeat.interval, which is ~10.5 minutes out of the box. Configuring
# those two properties shortens this test considerably.
# The supplied startup helper sets 1s / 1000ms (about 12s detection).
DEAD_TIMEOUT="${DEAD_TIMEOUT:-60}"
RECOVER_TIMEOUT="${RECOVER_TIMEOUT:-300}"

# Q1: 3 live datanodes on main, worker1 and worker2.
function test_hadoop_q1() {
    dc exec -T main hdfs dfsadmin -report
}

# Q2: HDFS writes and reads a file correctly.
function test_hadoop_q2() {
    dc cp resources/fox.txt main:/test_fox.txt || return 1
    dc exec -T main bash -ex -o pipefail -c '\
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt'
}

# Q3: a worker dies, the data stays readable, and the worker rejoins.
function test_hadoop_q3() {
    local result=0
    echo "Stopping worker2 ..."
    dc stop worker2 || return 1
    trap 'dc start worker2 >/dev/null 2>&1' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    echo "Waiting up to ${DEAD_TIMEOUT}s for the NameNode to report the dead datanode ..."
    if wait_for_datanodes 2 1 "$DEAD_TIMEOUT" /dev/stdout; then
        echo "FAILURE DETECTED"
    else
        echo "the NameNode still does not report 2 live / 1 dead datanode"
        result=1
    fi

    echo "Reading /test/fox.txt with one datanode down ..."
    dc exec -T main hdfs dfs -cat /test/fox.txt || result=1

    echo "Restarting worker2 ..."
    dc start worker2 || return 1

    echo "Waiting up to ${RECOVER_TIMEOUT}s for 3 live datanodes ..."
    if wait_for_datanodes 3 any "$RECOVER_TIMEOUT" /dev/stdout; then
        echo "RECOVERY COMPLETE"
    else
        echo "worker2 did not rejoin the cluster"
        result=1
    fi
    trap - EXIT INT TERM
    return "$result"
}

# Run question <n>, keep its output under out/, and return whether it passed.
function grade_hadoop() {
    local n="$1"
    local out="out/test_1_hadoop_q${n}.out"
    echo -n "Testing Hadoop Q${n} ..."
    "test_hadoop_q${n}" > "$out" 2>&1 || return 1
    case "$n" in
        1) grep -q "Live datanodes (3)" "$out" ;;
        2) grep -E -q '^The quick brown fox jumps over the lazy dog[[:space:]]*$' "$out" ;;
        3) grep -q "^FAILURE DETECTED$" "$out" && \
           grep -q "^RECOVERY COMPLETE$" "$out" && \
           grep -E -q '^The quick brown fox jumps over the lazy dog[[:space:]]*$' "$out" ;;
    esac
}

mkdir -p out
score=0

for q in 1 2 3; do
    if grade_hadoop "$q"; then
        pass
        (( score += 10 ))
    else
        fail
    fi
done

print_score "${score}/30 points"
[ "$score" -eq 30 ]
