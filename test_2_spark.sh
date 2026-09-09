#!/bin/bash
# Part 2: Spark deployment tests (30 points).

cd "$(dirname "$0")" || exit 1
source ./test-lib.sh

# Q1: the Spark context has 3 executors, on main, worker1 and worker2.
function test_spark_q1() {
    dc cp resources/active_executors.scala main:/active_executors.scala || return 1
    dc exec -T main bash -ex -o pipefail -c '\
        cat /active_executors.scala | spark-shell --master spark://main:7077'
}

# Q2: the Pi estimation benchmark runs to completion.
function test_spark_q2() {
    dc cp resources/pi.scala main:/pi.scala || return 1
    dc exec -T main bash -ex -o pipefail -c '\
        cat /pi.scala | spark-shell --master spark://main:7077'
}

# Q3: Spark reads from HDFS.
function test_spark_q3() {
    dc cp resources/fox.txt main:/test_fox.txt || return 1
    dc exec -T main bash -ex -o pipefail -c '\
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt' || return 1
    dc exec -T main bash -ex -o pipefail -c '\
        echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | \
        spark-shell --master spark://main:7077'
}

# Run question <n>, keep its output under out/, and return whether it passed.
function grade_spark() {
    local n="$1"
    local out="out/test_2_spark_q${n}.out"
    echo -n "Testing Spark Q${n} ..."
    "test_spark_q${n}" > "$out" 2>&1 || return 1
    case "$n" in
        1) grep -q "^ACTIVE EXECUTORS: 3$" "$out" ;;
        2) grep -q '^PI VALIDATION: PASS$' "$out" ;;
        3) grep -q 'Array(The quick brown fox jumps over the lazy dog)' "$out" ;;
    esac
}

mkdir -p out
score=0

for q in 1 2 3; do
    if grade_spark "$q"; then
        pass
        (( score += 10 ))
    else
        fail
    fi
done

print_score "${score}/30 points"
[ "$score" -eq 30 ]
