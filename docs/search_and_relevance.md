# Search Architecture, Relevance Scoring, and Identifier Priority

This document details how search queries are processed, scored, and sorted across the Canadiana and Héritage portals, addressing **Issue #95 (Natural priority in search results)**, **Issue #96 (Bare identifier lookups)**, and the user-facing search features described in **Navigating Collections**.

---

## 1. Architecture Overview

Both Canadiana and Héritage use **Apache Solr (v9.x)** as the underlying search engine, communicating via the **Ruby on Rails Blacklight (v8.x)** front-end application.

- **Solr Cores**: 
  - `blacklight_marc`: Catalog metadata, facet fields, and document identifiers.
  - `content_search`: Canvas-level OCR text (`ocrtext`, `ocrtext_*`) and word coordinates (`ocrbbox`).
- **Query Handler**: `/select`
- **Query Parsers**: `edismax` (Extended DisMax) for metadata searches; cross-core Solr join (`{!join}`) for full-text searches and availability faceting.
- **Request Pipeline**: Built dynamically through Blacklight's `SearchBuilder` (`app/models/search_builder.rb`) and `CatalogController` (`app/controllers/catalog_controller.rb`).

---

## 2. Relevance Scoring & Sort Order

### 2.1 Default Sort: Relevance (`score desc`)
When a user submits a search query without selecting a specific sort order, results are sorted by `score desc`.

Solr calculates the relevance score for each document using the Lucene **BM25 similarity model**, which weighs:
1. **Term Frequency (TF)**: How frequently the search term appears in a given field.
2. **Inverse Document Frequency (IDF)**: How rare or common the term is across the entire corpus.
3. **Field Length Normalization**: Matches in shorter fields (such as titles or IDs) contribute more weight than matches in long text fields.
4. **Query Field Weights (`qf`)**: Explicit multiplier boosts applied to specific metadata fields.
5. **Phrase Boosting (`pf`)**: Bonus score awarded when terms appear adjacent to each other in sequence.
6. **Boost Queries (`bq`)**: Dynamic boost factors applied to specific document criteria (e.g., exact ID matches).

### 2.2 User-Selectable Sort Options
In addition to the default relevance sort, users can select alternative sort orders from the sort dropdown:
- **Relevance** (`score desc`)
- **Year (newest first)** (`pub_date_ssim desc`)
- **Year (oldest first)** (`pub_date_ssim asc`)
- **Date added (newest first)** (`date_added desc`)
- **Date added (oldest first)** (`date_added asc`)

---

## 3. Query Field Weights (`qf`) and Phrase Boosting (`pf`)

When a user searches **All Fields** (the default search field), the query is evaluated across multiple indexed fields with individual weight boosts defined in `CatalogController::ALL_FIELDS_QF`:

| Field | Description | Boost Weight |
|---|---|---|
| `id` | Exact document identifier (e.g. `oocihm.8_06911_57.1`, `oocihm.lac_mikan_117878`) | **^5000** |
| `id_t` | Tokenized identifier (allowing partial matches with punctuation stripped) | **^2500** |
| `title_tsim` | Primary record title | **^3** |
| `title_addl_tsim` | Additional / alternate title entries | **^2** |
| `author_tsim` | Author / Creator name | **^2** |
| `subject_tsim` | Subject headings and keywords | **^2** |
| `archival_ref_ssm` | Archival reference / standard identifier (MARC 024) | **^2** |
| `summary_tsim` | Summary note (MARC 520) | **^1** (default) |
| `finding_aid_ssm` | Finding aid note (MARC 555) | **^1** (default) |
| `all_text_timv` | Aggregated OCR and transcript text across all pages | **^1** |
| `tx_gen` | General full text (OCR / ICR text) | **^2** |
| `tx_*` | Language-specific full text fields (e.g. `tx_fr`, `tx_en`, `tx_cjk`, `tx_indigenous`) | **^1** |

### Phrase Proximity Boosting (`pf`)
When multiple search words are typed together (e.g. `canadian history`), Solr awards extra boost points when the terms appear adjacent as an exact phrase:
- `all_text_timv^10`
- `tx_gen^8`
- `tx_*^8` (for each language-specific text field)

---

## 4. Priority for Identifiers (CIHM, MIKAN, Reel Numbers)

### 4.1 The Problem (Issue #95 & Issue #96)
1. **MIKAN Search in Héritage (Issue #95)**:
   - When searching for a MIKAN number (e.g. `117878`), child microfilm reel records often ranked above the parent collection record.
   - *Why this occurred*: Microfilm reels contain MARC notes (e.g., finding aid notes or general notes) that explicitly quote the parent collection's MIKAN number. The parent collection's Solr `id` is prefixed (`oocihm.lac_mikan_117878`). When users searched the bare number `117878`, the parent record only matched on partial text, while reels with repeated notes received higher BM25 term frequency scores.
2. **CIHM / Newspaper IDs in Canadiana (Issue #96)**:
   - When searching for bare identifiers such as `N_00005`, zero results appeared, whereas `oocihm.n_00005` returned the newspaper title.
   - *Why this occurred*: Identifiers in Canadiana are stored with the `oocihm.` prefix. The bare token `N_00005` did not match the strict `id` field and was not indexed in the title or creator fields.

### 4.2 The Solution (`SearchBuilder#boost_and_expand_id_queries`)
To enforce natural ID priority without breaking general text search, Blacklight's `SearchBuilder` intercepts search queries and performs two enhancements:

#### 1. Candidate ID Generation
The search builder analyzes the search query and extracts candidate identifiers, generating variants across all known CRKN ID naming conventions:
- Bare term (e.g., `117878`, `N_00005`, `H2971`)
- Lowercase and uppercase variants (`n_00005`, `h2971`)
- Canadiana prefix: `oocihm.<term>`
- Héritage MIKAN prefix: `oocihm.lac_mikan_<term>`
- Héritage Reel prefix: `oocihm.lac_reel_<term>`

#### 2. Overwhelming Boost Query (`bq`)
For every candidate ID, a Boost Query clause is injected:
```solr
bq=id:"<candidate_id>"^50000
```
Because the boost value (`^50000`) massively exceeds standard metadata weights (which range between `1` and `10`), **any record whose Solr `id` matches the searched number is guaranteed to score highest and appear in the #1 position**, cleanly beating reels or items that merely mention the number in notes.

#### 3. Query Expansion (`q`) for Bare IDs
When the user submits a single bare token without the `oocihm.` prefix, `solr_parameters[:q]` is expanded with `OR` clauses matching candidate Solr `id` fields:
```solr
q=(N_00005) OR id:"N_00005" OR id:"n_00005" OR id:"oocihm.n_00005" ...
```
with minimum match requirement `mm=1`. This guarantees that searches for bare IDs like `N_00005`, `72118`, or `h2971` retrieve the record even when the `oocihm.` prefix is omitted.

---

## 5. Supported Search Syntax & Features

The following syntax features are supported in both portals, as outlined in the *Navigating Collections* guide:

| Feature | Syntax Example | Behavior |
|---|---|---|
| **Single-character Wildcard** | `defen?e` | Matches any single character (e.g. `defence` or `defense`). |
| **Multi-character Wildcard** | `labo*r` | Matches zero or more characters (e.g. `labor` or `labour`). |
| **Exact Phrase** | `"quebec city"` | Matches the exact words in that specific order. |
| **Negation / Exclusion** | `paris -france` | Excludes documents containing `france`. |
| **Alternate Terms (OR)** | `ontario york \| toronto` | Matches `ontario` and either `york` or `toronto`. |
| **Field Dropdown: Title** | Select *Title* | Targets `full_title_tsim`. |
| **Field Dropdown: Creator** | Select *Author/Creator* | Targets `author_tsim`. |
| **Field Dropdown: Subject** | Select *Subject* | Targets `subject_tsim`. |
| **Field Dropdown: Full Text** | Select *Full Text* | Queries OCR canvas transcripts in `content_search` dynamically via cross-core join (`{!join from=manifestid to=manifestid_s fromIndex=content_search}`). |
| **Date Range Limiting** | From `YYYY` To `YYYY` | Filters results via `pub_date_ssim:[FROM TO TO]`. |
| **Has Full Text Filter** | Check *Full text available* | Filters results via dynamic cross-core join (`{!join from=manifestid to=manifestid_s fromIndex=content_search}*:*`). |

---


### 5.1 Full-Text Search via Cross-Core Solr Join (`content_search`)

Full-text search queries execute against the dedicated `content_search` Solr core, which indexes OCR text and word bounding boxes at the individual canvas level. 

Instead of duplicating full-text inside `blacklight_marc`, Blacklight links the catalog record to its OCR transcripts using Solr's native cross-core join parser:

- **Linking Key**: `manifestid_s` in `blacklight_marc` (derived from the record's ARK) joins to `manifestid` in `content_search`.
- **Fielded Full-Text Search**: When a user selects **Full Text** from the search dropdown (`search_field=tx_gen`), `SearchBuilder#apply_fulltext_join` constructs a cross-core join query:
  ```solr
  q={!join from=manifestid to=manifestid_s fromIndex=content_search v='{!edismax qf="ocrtext ocrtext_general ocrtext_en ocrtext_fr" v=$fulltext_q}'}
  ```
- **Full-Text Availability Faceting**: In the facet sidebar, the **Full Text Search** facet dynamically counts records matching:
  - *Available*: `_query_:"{!join from=manifestid to=manifestid_s fromIndex=content_search}*:*" OR _query_:"{!join from=serial_key_s to=id v='{!join from=manifestid to=manifestid_s fromIndex=content_search}*:*'}"`
  - *Not Available*: `(*:* -(_query_:"{!join from=manifestid to=manifestid_s fromIndex=content_search}*:*" OR _query_:"{!join from=serial_key_s to=id v='{!join from=manifestid to=manifestid_s fromIndex=content_search}*:*'}"))`
  - *Decoupled Architecture*: Eliminates any dependency on `tx_gen` in `blacklight_marc`. Full-text availability is resolved purely via cross-core join against `content_search`, with nested intra-core join on `serial_key_s` -> `id` ensuring parent series, newspapers, and collections are marked Available whenever any child issue contains full text.

---

## 6. Verification and Automated Testing

Search behavior is regression-tested using Playwright automated test suites in `test-playwright/test_search_behavior.js`:
- `testIdPriority`: Confirms MIKAN searches place parent collections at rank 1 ahead of child reels.
- `testBareIdExpansion`: Confirms searches for `N_00005` or bare numbers return the expected document.
- `testExactPhrase`: Confirms quoted phrases match exact sequences.
- `testWildcards`: Confirms `?` and `*` wildcard matching.
- `testNegation`: Confirms `-` exclusion logic.
- `testAlternateTerms`: Confirms `|` / `OR` boolean logic.
- `testSortOptions`: Confirms relevance, date ascending, and date descending sorts.
- `testFullTextJoin`: Confirms full-text searches and availability facet queries match records with OCR in `content_search`.
