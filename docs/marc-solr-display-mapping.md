# MARC -> Solr -> Catalog Mapping

This document describes the active MARC-to-Solr mappings in `app/models/marc_indexer.rb`, plus how those fields are used by the current catalog UI in `app/controllers/catalog_controller.rb`, `app/models/solr_document.rb`, and a few show-page components.

It reflects the code currently in the repository, not older comments or prior indexer behavior.

## Field suffix conventions

- `_tsim`: searchable text field used for query-time matching.
- `_ssm`: stored string/multivalue field mainly used for display.
- `_ssim`: stored multivalue string field, commonly used for facets and display.
- `_si`: sortable scalar value.
- `_timv`: catch-all text/multivalue field.
- `_path`: hierarchical path field used by `blacklight-hierarchy`.
- `_str`: docValues/copy-style facet fields used in the controller, but not produced directly in `MarcIndexer`.

## Active mappings in `MarcIndexer`

| Solr field | Purpose in catalog | MARC source(s) | Processing / notes |
| --- | --- | --- | --- |
| `id` | Primary record identifier; drives record URLs and Solr lookups | `001` | `trim` + `first_only`. |
| `is_issue` | Flags issue records; used by facet config and issue-specific UI logic | `901` | Exact case-insensitive compare to `Is issue`; stores `Yes` or `No`. |
| `serial_key` | Parent/child serial linkage; used to fetch issue lists and build serial links | `902$b` | Current code only indexes `902$b`. The inline comment mentions a fallback to the left side of `001`, but that fallback is not implemented. |
| `serial_title` | Canonical serial title; used for serial facet labels and breadcrumb serial label | `245$a` | First value only. Strips everything after the first colon (`:` or ` : `). |
| `is_serial` | Flags parent serial records; controls whether show page renders Mirador/downloads or issue list | `901` | Exact case-insensitive compare to `Is series`; stores `Yes` or `No`. Current code does not inspect `999`. |
| `marc_ss` | Full MARC XML payload; used by `Blacklight::Marc::DocumentExtension` for MARC/librarian-style views | Entire record | Stored via `get_xml`. |
| `all_text_timv` | Catch-all indexed text for broad search / retrieval support | Entire record | Joins all extracted MARC values into one string. |
| `language_ssim` | Language display + facet source + semantic field | `008[35-37]`, `041$a`, `041$d` | Uses Traject `marc_languages(...)` normalization. |
| `format` | Format icon / semantic format field | Derived by `Blacklight::Marc::Indexer::Formats#get_format` | Not mapped from explicit tags in this file; delegated to Blacklight MARC format logic. |
| `material_type_ssm` | Stored physical/material statement | `300$a` | Punctuation trimmed. Not currently wired into index/show field config. |
| `full_title_tsim` | Main title search field and configured Blacklight result title field | `245$a$b` | Used by `config.index.title_field` and search field `full_title_tsim`. |
| `full_title_ssm` | Stored full title (roman) | `245$a$b` | Roman script only; punctuation trimmed. |
| `full_title_vern_ssm` | Stored full title (vernacular) | `245$a$b` | Vernacular only; punctuation trimmed. |
| `title_tsim` | Searchable main title | `245$a` | Indexed only; not directly exposed as a search-field option. |
| `title_ssm` | Main title display/semantic title field; shown in index metadata | `245$a` | Roman script only; punctuation trimmed. Also mapped as `SolrDocument` semantic title. |
| `title_vern_ssm` | Main title display (vernacular) | `245$a` | Vernacular only; punctuation trimmed. |
| `subtitle_tsim` | Searchable subtitle | `245$b` | Indexed only. |
| `subtitle_ssm` | Stored subtitle (roman) | `245$b` | Roman script only; punctuation trimmed. |
| `subtitle_vern_ssm` | Stored subtitle (vernacular) | `245$b` | Vernacular only; punctuation trimmed. |
| `title_addl_tsim` | Searchable alternate/uniform/series-related titles | `246abcdefgnp`, `240abcdefgklmnopqrs`, `242abnp`, `243abcdefgklmnopqrs`, `247abcdefgnp`, `730abcdefgklmnopqrst`, `740anp`, `830adfghklmnoprstvwxy` | Consolidated additional-title search field. |
| `title_si` | Sortable title key | Derived | Uses Traject `marc_sortable_title`. Not currently exposed in the sort menu. |
| `author_tsim` | Searchable creator/contributor field; exposed as search-field option | `100abcegqu`, `110abcdegnu`, `111acdegjnqu`, `130#{ATOZ}`, `700abcegqu`, `710abcdegnu`, `711acdegjnqu`, `720#{ATOZ}` | Broad contributor search field. |
| `author_ssm` | Display creator/contributor field; index/show metadata; semantic author field | `100abcdq`, `110#{ATOZ}`, `111#{ATOZ}`, `130#{ATOZ}`, `700abcegqu`, `710abcdegnu`, `711acdegjnqu`, `720#{ATOZ}` | Roman script only. Used in result metadata, show metadata, and facet copy field source. |
| `author_vern_ssm` | Display creator/contributor field (vernacular) | Same logical tag set as `author_ssm` | Vernacular only. |
| `author_si` | Sortable author key | Derived | Uses Traject `marc_sortable_author`. Not currently exposed in the sort menu. |
| `subject_tsim` | Searchable subject field; exposed as search-field option | `600-658`, `662`, `688` across all subfields (`#{ATOZ}`) | Broad subject search field. |
| `subject_ssim` | Subject display/facet source | `600-658`, `662`, `688` across all subfields (`#{ATOZ}`) | Punctuation trimmed. Used in index/show metadata and facet copy field source. |
| `published_ssm` | Publication statement display (roman); index/show metadata | `260abcefg`, `264abc` | Roman script only; punctuation trimmed. |
| `published_vern_ssm` | Publication statement display (vernacular) | `260abcefg`, `264abc` | Vernacular only; punctuation trimmed. |
| `pub_date_si` | Sortable publication date key | Derived | Uses `marc_publication_date`. |
| `pub_date_ssim` | Publication year facet/display/sort source | Derived | Uses `marc_publication_date`. Used in index/show metadata, year range facet, and year sorts. |
| `collectionen_path` | English hierarchical collection facet + breadcrumb input | `999$e` | Built from ordered English `999$e` segments. Stores cumulative prefixes like `Serials` and `Serials/Newspapers`, not just the leaf path. |
| `collectionfr_path` | French hierarchical collection facet + breadcrumb input | `999$f` | Built from ordered French `999$f` segments. Stores cumulative prefixes like `Publications en serie` and `Publications en serie/Journaux`. |
| `depositor_tsim` | Depositor metadata and facet source | `590$a` | Used in index/show metadata and facet copy field source. |
| `doc_source_tsim` | Reproduction/source note | `533abcdu` | Indexed only in current catalog config. |
| `rights_stat_tsim` | Rights statement display | `540abcdfgqu` | Used on the show page metadata panel. |
| `access_note_tsim` | Access restrictions note | `506abcdefgqu` | Used in index metadata; currently commented out in show metadata config. |
| `original_version_note_tsim` | Original-version / physical-item note | `534abcefklmnoptxz` | Used in both index and show metadata. |
| `notes_tsim` | General notes display/search support | `500#{ATOZ}`, `515#{ATOZ}`, `546#{ATOZ}` | Used in both index and show metadata. |
| `source_of_description_tsim` | Source-of-description note | `588#{ATOZ}` | Indexed, but currently commented out in show metadata config. |
| `title_series_tsim` | Searchable/stored series statements | `440anpv`, `490av` | Useful serial context; not currently wired into index/show metadata config. |
| `permalink_fulltext_ssm` | Stored permalink/fulltext helper field | `856$g` | Indexed only in current app code. |
| `date_added` | Ingest/addition date; shown in metadata and used for sorting | `998` | Reads first 8 chars as `YYYYMMDD`, outputs `YYYY-MM-DD`. |
| `date_edited` | Last-edit timestamp | `005` | Reads first 14 chars as `YYYYMMDDHHMMSS`, outputs UTC ISO8601. Indexed only in current UI config. |
| `url_fulltext_ssm` | Fulltext URLs | `856$u` with indicator logic | Includes `856` URLs when ind2=`0`; skips ind2=`2`; otherwise includes non-supplemental links unless `$z`/`$3` matches `abstract|description|sample text|table of contents`. |
| `url_suppl_ssm` | Supplemental URLs | `856$u` with indicator logic | Includes ind2=`2`; for other non-`0` values, includes links only when `$z`/`$3` matches the supplemental-text regex. |
| `lc_callnum_ssm` | Full LC call number | `050ab` | First value only. Indexed only in current UI config. |
| `lc_1letter_ssim` | Top-level LC class facet helper | `050ab` | First value only, first character only, then translated through `callnumber_map`. Indexed only in current UI config. |
| `lc_alpha_ssim` | Alphabetic LC class prefix | `050a` | Extracts leading 1-3 alpha chars before digits. First value only. Indexed only in current UI config. |
| `lc_b4cutter_ssim` | LC class before cutter | `050a` | First value only. Indexed only in current UI config. |

## Catalog-configured fields not produced directly in `MarcIndexer`

These fields are referenced by the current catalog configuration, but they are not created anywhere in `app/models/marc_indexer.rb`.

| Field | Where it is used | Notes |
| --- | --- | --- |
| `ark` | Index metadata, show metadata, IIIF viewer, downloads, citations, page search | Not indexed in this class. It appears to come from another ingest step, external index source, or Solr-side pipeline. |
| `language_ssim_str` | Facet field | Controller comment suggests `_str` fields are docValues-backed copies. Not produced here. |
| `depositor_tsim_str` | Facet field | Same pattern as above. |
| `subject_ssim_str` | Facet field | Same pattern as above. |
| `author_ssm_str` | Facet field | Same pattern as above. |
| `serial_title_str` | Facet field | Same pattern as above. |
| `is_issue_str` | Facet field | Same pattern as above. |
| `is_serial_str` | Facet field | Same pattern as above. |
| `tx_gen` | Search field option in controller | Not indexed in this class. The app also defines a `CatalogController#tx_gen` export endpoint, so the name is overloaded. |

## Commented-out / dormant mappings in `MarcIndexer`

These appear in the file but are currently disabled:

| Field | MARC source(s) | Status / notes |
| --- | --- | --- |
| `isbn_tsim` | `020$a` | Commented out in the current indexer. The older `MarcIndexerOriginal` normalized ISBNs, but that logic is not active now. |
| `materials_ssim_en` | Derived from `999$e` | Commented out. |
| `materials_ssm_en` | Derived from `999$e` | Commented out. |
| `materials_ssim_fr` | Derived from `999$f` | Commented out. |
| `materials_ssm_fr` | Derived from `999$f` | Commented out. |

## Code observations worth keeping in mind

- `serial_key` comment drift: the comment says it should prefer `902$b` and fall back to the left side of `001`, but the code only implements `902$b`.
- `is_serial` comment drift: the current code checks only whether `901` equals `Is series`; it does not combine `999` plus `901`.
- `collectionen_path` / `collectionfr_path` are built from literal `999$e` / `999$f` sequences and expanded into prefix paths with `/` separators for `blacklight-hierarchy`.
- `materials_by_language`, `detect_language_code`, `opposite_language_code`, and `HIER_DELIM` are present but currently unused by the active mappings.
- `marc_ss` is the field used by `app/models/solr_document.rb` for MARC document extension behavior.
