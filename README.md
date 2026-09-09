# CS 511: Project 1 WikiIndex on Hadoop

Follow the [course handout](https://docs.google.com/document/d/1OmlxwPLIj356uQ2wwOao0IGoDLguB0HFcey_WbaN1m8).
This repository is the student starter: HDFS/Spark setup and the three Python
TODO functions are intentionally incomplete.

## Setup and Part 0

Run commands in a Bash terminal on the host, from the repository root. The
host needs Docker with Compose, Python 3, curl, zstd, and GNU command-line
utilities including sha256sum, sort, and diff. The grading platform is Ubuntu
22.04. Check Docker access as the user who will run the assignment scripts:

```bash
docker run --rm hello-world
docker compose version
```

Start the containers using the handout command:

```bash
bash start-all.sh
```

This builds the images and waits for SSH to start on the three containers. It
works before HDFS and Spark are implemented. To enter the main container:

```bash
docker compose -f cs511p1-compose.yaml exec main bash
```

Run `exit` to return to the host before running more Docker or test commands.
The supplied cluster exposes the Spark master UI on localhost:8080 and the
worker UI on main on localhost:8081; those host ports must be available.

## Implement and test

Use Hadoop 3.3.6 and Spark 3.4.1. Run a DataNode and Spark worker on each of
main, worker1, and worker2. The common image installs Python 3.10 for the heartbeat helper and PySpark.
Keep a Spark-compatible Python version (3.7–3.11) on every container. Make the Hadoop/Spark commands
available to noninteractive commands, for example through Dockerfile ENV
settings. Follow the handout's permitted-file list and preserve protected blocks.

After editing Dockerfiles or setup/startup scripts, run `bash start-all.sh`
again to rebuild. Run the suites in order as you complete each part:

```bash
bash test_1_hadoop.sh
bash test_2_spark.sh
bash test_3_wikiindex.sh
bash test_full.sh
```

The HDFS failure test stops and restarts worker2; the supplied startup helper sets
a 1-second heartbeat and 1,000-ms NameNode recheck interval, giving approximately
12-second dead-node detection (the test allows 60 seconds). The helper updates
`hdfs-site.xml` in `HADOOP_CONF_DIR`, or `HADOOP_HOME/etc/hadoop`, before the
student service-start commands run. Keep these timings for this small cluster. Do not run suites concurrently.
Logs are saved in `out/`.

For Part 3.2, put `wiki_full.jsonl.zst`, `manifest.json`, and `ATTRIBUTION.md`
in `resources/wiki-full/`, as described in the handout. The published release
spells the chunk `wiki-full.jsonl.zst`; the test accepts either spelling and
verifies the same checksum. Missing release files are downloaded automatically.
See [dataset details](resources/wiki-full/README.md).
The supplied Python entry point writes one output partition. The full test
checks execution, record structure, and referenced article IDs; it is not an
exact check of all corpus coverage or frequencies. After grading, it prints a
small search preview for `computer`, `science`, and `data`, showing up to three
article IDs per term ranked by term frequency. This preview does not affect
points or the test exit status; its output is saved in `out/wiki-full/`.

The application runner has the fixed interface:

```bash
bash run-wikiindex.sh <input_uri> <output_uri>
```

Use HDFS URIs beginning with `hdfs://main:9000/`. The runner replaces the output
directory, so keep it separate from input and other files you need to retain.

## Submission and grading

Submit a ZIP on Canvas containing a PDF or plain-text report with the team
name, member names and NetIDs, and Part 4 answers, plus the completed `cs511p1/`
source directory. Exclude `.git/`, `out/`, Python caches, and downloaded full
data files. Preserve all other supplied resources, including the dataset README.

After extracting the ZIP, the grader runs:

```bash
cd cs511p1
bash start-all.sh
bash test-all.sh
```

`test-all.sh` waits for HDFS readiness before grading the completed submission.
Automated tests total 100 points; Part 4 adds 20, for 120 before scaling to a
percentage. The pinned handout governs the deadline and late-submission policy.

Remove the containers when finished:

```bash
bash stop-all.sh
```

With the supplied Compose configuration, this deletes HDFS data stored in the
containers. The tests upload their inputs again on subsequent runs.
