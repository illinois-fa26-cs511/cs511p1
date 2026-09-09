# CS 511: Project 1 WikiIndex on Hadoop

Follow the [course handout](https://docs.google.com/document/d/1OmlxwPLIj356uQ2wwOao0IGoDLguB0HFcey_WbaN1m8) for instructions and submission requirements.

Run commands from the repository root in a host Bash terminal. You need Docker
with Compose, Python 3, curl, zstd, and GNU command-line utilities.

Start or rebuild the cluster:

```bash
bash start-all.sh
```

Complete the starter code, then run the tests:

```bash
bash test-all.sh
```

To test individual parts:

```bash
bash test_1_hadoop.sh
bash test_2_spark.sh
bash test_3_wikiindex.sh
bash test_full.sh
```

Logs are saved in `out/`. The full test downloads missing dataset files automatically.

Stop and remove the cluster (including its HDFS data):

```bash
bash stop-all.sh
```
