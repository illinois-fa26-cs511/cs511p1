#!/usr/bin/env python3
"""Read index records from stdin and show a tiny, ungraded term search."""
import heapq
import sys

TERMS = ('computer', 'science', 'data')


def main():
    found = {}
    for line in sys.stdin:
        term, sep, rest = line.rstrip('\n').partition('\t')
        if term not in TERMS or not sep:
            continue
        df, cf, postings = rest.split('\t')
        pairs = (tuple(map(int, posting.split(':'))) for posting in postings.split(','))
        # Highest within-article frequency first; numeric ID breaks ties.
        top = heapq.nsmallest(3, pairs, key=lambda pair: (-pair[1], pair[0]))
        found[term] = (int(df), int(cf), top)
    print('Search preview (ungraded; top 3 by term frequency):')
    for term in TERMS:
        if term not in found:
            print('  %s: no matches' % term)
            continue
        df, cf, top = found[term]
        hits = ', '.join('article %d (tf=%d)' % pair for pair in top)
        print('  %s: df=%d, cf=%d; %s' % (term, df, cf, hits))


if __name__ == '__main__':
    main()
