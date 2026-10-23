---
status: accepted
---

# Rank search results, and reject weak semantic matches

Search reused the journal timeline: retrieval produced a ranked list, the store
turned it into a set of IDs, and the timeline sorted by entry date again. On a
query like "quando me senti sozinho" the most useful note could sit below newer,
barely related entries, so the mechanism looked worse than it is. Search now
owns its ordering. While a query is active the timeline keeps retrieval rank
across dates, shows each result's own date instead of day headers, and restores
the dated timeline when the query is cleared. Journal entries resolve the rank
list so edits and deletions stay current, and a result that no longer exists
simply disappears.

Semantic retrieval returned the nearest neighbours unconditionally: an absolute
KNN query always answers, even when nothing in the journal is about the query.
A weak neighbour is not a match, and showing one costs more trust than showing
fewer results. Embeddings now drop chunks beyond `EmbeddingPipeline.maxDistance`
before a note is selected, so a query can legitimately return nothing. The
cutoff is retrieval policy, not representation: it never invalidates the index,
and it is absolute rather than relative to the best hit, so journal size and
note count do not change what "related" means.

The value came from measurement, not intuition. `search_relevance_test.dart`
holds a synthetic bilingual journal, labelled queries, and an untouched holdout;
it runs the real weights and prints every distance. Relevant matches landed
between 0.27 and 0.60 cosine distance, while ten clearly unrelated topics all
started at 0.626. The cutoff sits at 0.61, deliberately favouring recall: a vague
query keeps a weak-but-real entry rather than reporting nothing. That gap is
narrow, and the model still retrieves topically adjacent notes that a person
would not call a match; the cutoff limits the noise instead of eliminating it.
Recalibrate only with new evidence, and re-run the holdout when adjusting it.

Interface states follow the same rule. Text search answers as the journaler
types, so previous results stay readable while a refresh runs. Search by meaning
waits for explicit submission, which means "typed but not submitted" is not "no
matches": the screen says the query is ready to submit, shows progress while the
model runs, and only reports no results after a completed request. The
incomplete-index notice keeps explaining that pending notes are missing from
meaning-based results.

Keeping rank across dates removed the day grouping that the search view had
borrowed from the timeline, so each result carries its date in the secondary
line. Empty results name the query once, after the attempt, never before it.
