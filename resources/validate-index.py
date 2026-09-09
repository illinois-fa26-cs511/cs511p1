#!/usr/bin/env python3
"""Validate a WikiIndexing output directory with Spark (Part 3.2).

    spark-submit --master spark://main:7077 \
        /validate-index.py <index_uri> [input_uri]

Checks every record of the index against the rules of Part 3:

  * the line has exactly 4 tab-separated fields,
  * the term is lowercase, matches [a-z]+('[a-z]+)?, is at least 2 characters
    long and is not a stopword,
  * the postings parse as id:tf, have distinct ids in ascending order and
    positive tf values,
  * df equals the number of postings and cf equals the sum of the tf values,
  * a term appears in at most one record of the whole index.

When <input_uri> is given, it also checks that every referenced article ID exists in the input.
This is a structural check, not an exact check of all token counts or coverage.

Prints "WIKIINDEX VALIDATION: PASS" (exit code 0) or "... FAIL" (exit code 1).
This script only inspects the output; it is not a solution to Part 3.
"""
import json
import re
import sys

from pyspark.sql import SparkSession

TERM_PATTERN = re.compile(r"^[a-z]+(?:'[a-z]+)?$")
MIN_TERM_LENGTH = 2
STOPWORDS = frozenset(
    "a an and are as at be by for from in is it of on or that the to was with".split()
)


def record_problems(line):
    """Return a list of (problem, example) pairs for one index record."""
    problems = []
    fields = line.split("\t")
    if len(fields) != 4:
        return [("field_count", line[:120])]
    term, df, cf, postings = fields

    if not TERM_PATTERN.fullmatch(term):
        problems.append(("bad_term", term))
    if len(term) < MIN_TERM_LENGTH:
        problems.append(("short_term", term))
    if term in STOPWORDS:
        problems.append(("stopword_term", term))

    try:
        df, cf = int(df), int(cf)
    except ValueError:
        return problems + [("df_cf_not_integers", line[:120])]

    ids, tfs = [], []
    for posting in postings.split(","):
        id_tf = posting.split(":")
        if len(id_tf) != 2:
            return problems + [("bad_posting", line[:120])]
        try:
            ids.append(int(id_tf[0]))
            tfs.append(int(id_tf[1]))
        except ValueError:
            return problems + [("bad_posting", line[:120])]

    if any(tf < 1 for tf in tfs):
        problems.append(("nonpositive_tf", line[:120]))
    if ids != sorted(ids):
        problems.append(("postings_not_sorted", line[:120]))
    if len(set(ids)) != len(ids):
        problems.append(("duplicate_article_id", line[:120]))
    if df != len(ids):
        problems.append(("df_mismatch", line[:120]))
    if cf != sum(tfs):
        problems.append(("cf_mismatch", line[:120]))
    return problems


def article_ids(line):
    fields = line.split("\t")
    if len(fields) != 4:
        return []
    ids = []
    for posting in fields[3].split(","):
        id_tf = posting.split(":")
        if len(id_tf) == 2 and id_tf[0].lstrip("-").isdigit():
            ids.append(int(id_tf[0]))
    return ids


def term_and_cf(line):
    """Return (term, cf) for a line the statistics can be computed from."""
    fields = line.split("\t")
    if len(fields) != 4 or not fields[2].isdigit():
        return None
    return (fields[0], int(fields[2]))


def valid_article(line):
    try:
        article = json.loads(line)
        return isinstance(article, dict) and "id" in article and "text" in article
    except ValueError:
        return False


def main(argv):
    if len(argv) not in (2, 3):
        print(__doc__, file=sys.stderr)
        return 2
    index_uri = argv[1]
    input_uri = argv[2] if len(argv) == 3 else None

    spark = SparkSession.builder.appName("WikiIndexValidation").getOrCreate()
    sc = spark.sparkContext
    failures = []
    try:
        records = sc.textFile(index_uri).filter(lambda line: line.strip() != "").cache()
        num_records = records.count()
        if num_records == 0:
            print("ERROR: the index is empty")
            return 1

        problems = records.flatMap(record_problems) \
            .map(lambda p: (p[0], [p[1]])) \
            .reduceByKey(lambda a, b: (a + b)[:3]) \
            .collect()
        for problem, examples in sorted(problems):
            failures.append("%s (e.g. %s)" % (problem, "; ".join(examples)))

        duplicates = records.map(lambda line: (line.split("\t")[0], 1)) \
            .reduceByKey(lambda a, b: a + b) \
            .filter(lambda kv: kv[1] > 1) \
            .keys().take(3)
        if duplicates:
            failures.append("terms appearing in more than one record (e.g. %s)"
                            % ", ".join(duplicates))

        # The statistics below skip malformed lines, which are already reported.
        stats = records.map(term_and_cf).filter(lambda tc: tc is not None).cache()
        referenced_ids = records.flatMap(article_ids).distinct().cache()
        indexed_articles = referenced_ids.count()
        total_cf = stats.values().sum()

        print("index records (terms) : %d" % num_records)
        print("articles referenced   : %d" % indexed_articles)
        print("total collection freq : %d" % total_cf)
        print("top terms by cf       :")
        for cf, term in stats.map(lambda tc: (tc[1], tc[0])).top(10):
            print("    %-24s %d" % (term, cf))

        if input_uri is not None:
            input_articles = sc.textFile(input_uri).filter(valid_article).cache()
            num_articles = input_articles.count()
            input_ids = input_articles.map(lambda line: json.loads(line)["id"]).distinct()
            unknown_ids = referenced_ids.subtract(input_ids).take(3)
            if unknown_ids:
                failures.append("unknown article IDs (e.g. %s)" % unknown_ids)
            print("valid input articles  : %d" % num_articles)
            if indexed_articles > num_articles:
                failures.append("the index references %d articles but the input "
                                "only has %d" % (indexed_articles, num_articles))
    finally:
        spark.stop()

    if failures:
        print("WIKIINDEX VALIDATION: FAIL")
        for failure in failures:
            print("  - %s" % failure)
        return 1
    print("WIKIINDEX VALIDATION: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
