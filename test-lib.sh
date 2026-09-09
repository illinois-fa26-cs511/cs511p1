#!/bin/bash
# Helpers shared by start-all.sh, stop-all.sh and the test_*.sh scripts.
# Source this file, do not execute it.

COMPOSE_FILE="${COMPOSE_FILE:-cs511p1-compose.yaml}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Compose V2 (`docker compose`) is the default on Ubuntu 22.04; fall back to the
# standalone V1 binary (`docker-compose`) when that is what is installed.
if docker compose version >/dev/null 2>&1; then
    COMPOSE=(docker compose -f "$COMPOSE_FILE")
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE=(docker-compose -f "$COMPOSE_FILE")
else
    echo "ERROR: neither 'docker compose' nor 'docker-compose' is available." >&2
    exit 1
fi

# dc <compose args ...>
function dc() {
    "${COMPOSE[@]}" "$@"
}

# node_exec <node> <bash command ...>: run a command on a node. -T is required
# because the test scripts do not run on a terminal.
function node_exec() {
    local node="$1"
    shift
    dc exec -T "$node" bash -c "$*"
}

# main_exec <bash command ...>
function main_exec() {
    node_exec main "$@"
}

function pass() { echo -e " ${GREEN}PASS${NC}"; }
function fail() { echo -e " ${RED}FAIL${NC}"; }
function skip() { echo -e " ${YELLOW}SKIP${NC}"; }

function print_score() {
    echo "-----------------------------------"
    echo "Result: $*"
}

# node_running <node>: true when the container is up.
function node_running() {
    [ -n "$(dc ps -q "$1" 2>/dev/null)" ] && \
        dc ps "$1" 2>/dev/null | grep -Eq 'Up|running'
}

# hdfs_report: dump `hdfs dfsadmin -report` (empty when HDFS is unreachable).
function hdfs_report() {
    main_exec 'hdfs dfsadmin -report' 2>/dev/null
}

# datanode_count <live|dead> [report file]: number reported by the NameNode.
function datanode_count() {
    local kind="$1" report="${2:-}" count temporary=false
    if [ -z "$report" ]; then
        report="$(mktemp)"
        temporary=true
        hdfs_report > "$report"
    fi
    case "$kind" in
        live) count=$(sed -n 's/^Live datanodes (\([0-9]\+\)).*/\1/p' "$report" | head -n1) ;;
        dead) count=$(sed -n 's/^Dead datanodes (\([0-9]\+\)).*/\1/p' "$report" | head -n1) ;;
    esac
    [ "$temporary" = false ] || rm -f "$report"
    echo "${count:-0}"
}

# wait_for_datanodes <live count> <dead count|any> <timeout seconds> [log file]
function wait_for_datanodes() {
    local want_live="$1" want_dead="$2" timeout="$3" log="${4:-/dev/null}"
    local deadline=$((SECONDS + timeout)) report live dead
    report="$(mktemp)"
    while [ "$SECONDS" -lt "$deadline" ]; do
        if ! hdfs_report > "$report" 2>&1; then
            sleep 5
            continue
        fi
        live=$(datanode_count live "$report")
        dead=$(datanode_count dead "$report")
        {
            echo "[$(date +%T)] live=${live} dead=${dead} (want live=${want_live} dead=${want_dead})"
        } >> "$log"
        if [ "$live" = "$want_live" ] && { [ "$want_dead" = "any" ] || [ "$dead" = "$want_dead" ]; }; then
            cat "$report" >> "$log"
            rm -f "$report"
            return 0
        fi
        sleep 5
    done
    cat "$report" >> "$log"
    rm -f "$report"
    return 1
}
