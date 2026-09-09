# resources/wiki-full/

`bash test_full.sh` downloads the dataset into this directory the first time it
runs, so a fresh clone needs no manual step. Everything here except this README
is ignored by git: the release is far larger than GitHub accepts, do not commit
it.

To use a copy you already have, put it here before running the test and the
download is skipped:

```
resources/wiki-full/
├── ATTRIBUTION.md
├── manifest.json
└── wiki_full.jsonl.zst
```

The handout uses `wiki_full.jsonl.zst`; the published manifest names the same
chunk `wiki-full.jsonl.zst`. Both filenames are accepted without renaming or
editing the manifest, and the content must match the pinned checksum. If both
copies exist, both must match that checksum; the test uploads the chunk once.

The release may also arrive split into several `*.jsonl.zst` chunks; the test
handles either layout, as long as every chunk listed in `manifest.json` is
present.

`manifest.json` records the snapshot it was built from and one entry per chunk:

```json
{
  "schema_version": 2,
  "snapshot": "2026-09-01",
  "source_url": "https://dumps.wikimedia.org/simplewiki/...",
  "source_sha256": "<64 hex characters>",
  "pages": 284748,
  "chunks": [
    {"file": "wiki-full.jsonl.zst", "sha256": "<64 hex characters>", "records": 284748}
  ]
}
```

`test_full.sh` checks the manifest against a digest pinned in the script, then
reads `chunks[].file` (or `name`) and `chunks[].sha256`, and requires the number
of `*.jsonl.zst` files present to match the number of entries (counting the two accepted
spellings of the single release chunk only once). Each chunk
decompresses to JSONL with one article per line, in the same format as
`resources/wiki-sample.jsonl`.
