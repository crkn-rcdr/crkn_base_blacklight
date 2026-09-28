# Blacklight Cataloguer Guide

This guide describes the **current** MARC indexing and catalog display rules in this repository.

It is based on the live code in:

- `app/models/marc_indexer.rb`
- `app/controllers/catalog_controller.rb`
- `app/components/blacklight/document_component.html.erb`
- `app/components/collection_items_component.rb`
- `app/components/page_search_component.rb`
- `app/helpers/application_helper.rb`
- `data/data/blacklight_marc/conf/managed-schema.xml`

**Audience:** cataloguers and staff checking display behaviour  
**Goal:** if you change a MARC record, you should be able to predict:

1. which Solr field is created
2. where that field appears in the catalog
3. what happens if the value is missing, malformed, or in the wrong MARC field

---

# Read This First

## 1. The old serial rules were wrong

The current code does **not** use `490$v` to build `serial_key`.

- `serial_key` comes from **`902$b`**
- `is_issue` comes from **`901 = Is issue`**
- `is_serial` comes from **`901 = Is series`**

The code does **not** check `999` to decide whether something is a serial parent.

## 2. Parent/issue grouping works like this

The serial-parent show page fetches issues with this Solr filter:

- `serial_key:"<parent id>"`
- `is_issue:"Yes"`

That means:

- the **parent record id** comes from `001`
- each **issue record** must have `902$b = parent 001`

The parent record does **not** need to share the same `serial_key` value for the issue list to work.

## 3. Some important fields do not come from `MarcIndexer`

These are used by the UI but are not built in `app/models/marc_indexer.rb`:

- `ark`
- `tx_gen`
- `tx_general_lang` and related OCR/full-text fields

Those come from another ingest step or from Solr schema setup.

## 4. Facet `_str` fields are copies, not separate MARC mappings

Examples:

- `language_ssim_str`
- `author_ssm_str`
- `subject_ssim_str`
- `depositor_tsim_str`
- `serial_title_str`
- `is_issue_str`
- `is_serial_str`

These are created by Solr `copyField` rules in `managed-schema.xml`. Cataloguers do **not** edit them directly.

---

# How The Catalog Decides What To Show

## Search results page

The search results page uses these main fields:

- result title: `full_title_tsim`
- result metadata: `format`, `title_ssm`, `author_ssm`, `published_ssm`, `pub_date_ssim`, `subject_ssim`, `depositor_tsim`, `language_ssim`, `notes_tsim`, `original_version_note_tsim`, `access_note_tsim`, `ark`, `date_added`

## Show page for a normal item

If `is_serial = No`, the show page displays:

- record metadata panel
- Mirador IIIF viewer, if `ark` is present
- download tools, if `ark` is present and external services respond
- IIIF toolbox
- page-hit chips for the current query, if `ark` and query text are present

## Show page for a serial parent

If `is_serial = Yes`, the show page displays:

- record metadata panel
- issue list instead of Mirador

That issue list is populated by finding issue records where:

- `serial_key = parent id`
- `is_issue = Yes`

## Issue breadcrumb behaviour

On an issue record show page:

- the link back to the parent uses `serial_key`
- the breadcrumb label uses `serial_title`

So an issue can have:

- a working parent link but a bad label
- a good label but a broken parent link
- both broken

depending on how `902$b` and `245$a` are catalogued.

---

# Field-By-Field Rules

## Fields that control record behaviour

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `id` | `001` | Record URL, Solr lookup, serial-parent issue query target | If wrong, the record URL is wrong. If the parent `001` changes, issue `902$b` values must be updated to match it. |
| `is_issue` | `901` | Issue facet; issue-only breadcrumb logic; issue filtering in serial lists | Anything other than case-insensitive `Is issue` becomes `No`. If a real issue is mistagged, it will not appear in the serial-parent issue list. |
| `is_serial` | `901` | Decides whether the show page renders Mirador/downloads or the serial issue list | Only case-insensitive `Is series` becomes `Yes`. If a serial parent is missing this value, the app treats it like a normal item and shows viewer/download tools instead of issue cards. |
| `serial_key` | `902$b` | Used to find a parent record's issues; used on issue pages for the parent breadcrumb link | If an issue `serial_key` does not equal the parent `001`, the issue will not appear under the parent and the issue breadcrumb link will point to the wrong record or nowhere useful. |
| `serial_title` | `245$a` | Serial title facet label; issue breadcrumb label | The app keeps only the text before the first colon. If `245$a` on an issue is missing or badly structured, the issue breadcrumb label will be blank or misleading. |
| `ark` | External ingest, not `MarcIndexer` | Persistent URL display; Mirador; IIIF toolbox; downloads; citations; page-hit chips; text export | If missing, the persistent URL is absent, Mirador does not load, the IIIF toolbox is disabled, downloads do not work, and page-hit navigation does not appear. |

## Title fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `full_title_tsim` | `245$a$b` | Search-result heading; title search field | If missing, the main result title becomes unreliable or blank. This is the most important search-results title field. |
| `full_title_ssm` | `245$a$b` | Stored only; not directly configured for current metadata display | If wrong, it does not affect the default UI much today, but it may affect downstream exports or future display changes. |
| `full_title_vern_ssm` | `245$a$b` alternate script only | Stored only; not directly configured for current metadata display | If missing, there is no current public UI change. |
| `title_tsim` | `245$a` | Included in `all_fields` query weighting | If missing, title keyword searching is weaker. |
| `title_ssm` | `245$a` roman only | Search-result metadata; semantic title field in `SolrDocument` | If missing, the result metadata panel loses its main title line even if the heading still appears from `full_title_tsim`. |
| `title_vern_ssm` | `245$a` alternate script only | Stored only; not directly configured for current metadata display | No current visible change if absent. |
| `subtitle_tsim` | `245$b` | Indexed for search; issue card heading in the serial-parent issue list | If issue information is left in `245$a` and not `245$b`, serial issue cards may have no heading even though the title search still works. |
| `subtitle_ssm` | `245$b` roman only | Stored only; copied to `_str`, but not directly shown in current default metadata | Little current effect if wrong. |
| `subtitle_vern_ssm` | `245$b` alternate script only | Stored only | No current visible effect. |
| `title_addl_tsim` | `240`, `242`, `243`, `246`, `247`, `730`, `740`, `830` | Search only | If missing, alternate-title searching is weaker, but display usually looks unchanged. |
| `title_si` | Derived | Not exposed in current sort menu | No visible effect in the current UI. |

## Creator and subject fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `author_tsim` | `100`, `110`, `111`, `130`, `700`, `710`, `711`, `720` selected subfields | Creator search field; `all_fields` query weighting | If missing, creator searching is weaker. |
| `author_ssm` | same logical creator set, roman only | Search-result metadata; show-page metadata; creator facet source; semantic author field | If missing, creators disappear from display and from the creator facet. |
| `author_vern_ssm` | alternate script only | Stored only | No current visible effect. |
| `author_si` | Derived | Not exposed in current sort menu | No current visible effect. |
| `subject_tsim` | `600-658`, `662`, `688` | Subject search field; `all_fields` query weighting | If missing, subject searching is weaker. |
| `subject_ssim` | `600-658`, `662`, `688` | Search-result metadata; show-page metadata; subject facet source | If missing, subjects disappear from display and from subject facets. |

## Publication, language, and format fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `published_ssm` | `260abcefg`, `264abc` roman only | Search-result metadata; show-page metadata | If missing, the publication statement line disappears. |
| `published_vern_ssm` | `260abcefg`, `264abc` alternate script only | Stored only | No current visible effect. |
| `pub_date_si` | Derived by `extract_original_publication_year` | Sort helper | If parsing fails, date sorting is unreliable or empty. Prioritizes original publication year over digitization date. |
| `pub_date_ssim` | Derived by `extract_original_publication_year` | Search-result metadata; show-page metadata; date range facet; year sorts | If parsing fails, the year may vanish from display and the record will not behave properly in year facets/sorts. Prioritizes original publication year over digitization date. |
| `material_type_ssm` | `300$a` | Indexed/stored only; not wired into current index/show metadata config | No current visible effect. |

## Collection and local metadata fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `collectionen_path` | ordered `999$e` values | English hierarchical collection facet; collection breadcrumbs on record pages | If missing, the English collection facet path and breadcrumbs disappear. If the order is wrong, the breadcrumb hierarchy is wrong. |
| `collectionfr_path` | ordered `999$f` values | French hierarchical collection facet; collection breadcrumbs on record pages | Same as English path, but for French UI. |
| `depositor_tsim` | `590$a` | Search-result metadata; show-page metadata; depositor facet source | If missing, depositor display and facet values disappear. |
| `rights_stat_tsim` | `540abcdfgqu` | Show-page metadata only | If missing, the rights statement block is absent. |
| `access_note_tsim` | `506abcdefgqu` | Search-result metadata only in current config | If missing, the access note is absent from results. It is not currently shown in show-page metadata. |
| `original_version_note_tsim` | `534abcefklmnoptxz` | Search-result metadata; show-page metadata | If missing, the original-version note disappears from both places. |
| `notes_tsim` | `500`, `515`, `546` | Search-result metadata; show-page metadata | If missing, note text disappears and note searching is weaker. |
| `source_of_description_tsim` | `588` | Indexed, but not currently configured for display | No current visible effect. |
| `doc_source_tsim` | `533abcdu` | Indexed, but not currently configured for public metadata display | No current visible effect in the main catalog UI. |
| `title_series_tsim` | `440anpv`, `490av` | Indexed for search/copy fields, but not directly shown in current metadata | No current visible effect. |

## Date, link, and call-number helper fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `date_added` | `998` first 8 characters | Search-result metadata; show-page metadata; date-added sort | Expected format is `YYYYMMDD...`. If malformed, the UI falls back to showing the raw value, and sorting may not behave as intended. |
| `date_edited` | `005` first 14 characters | Indexed only; not currently displayed | No current visible effect. |
| `permalink_fulltext_ssm` | `856$g` | Indexed only; not used by the current default show page | No current visible effect. |
| `url_fulltext_ssm` | `856$u` with indicator logic | Indexed only in current app code; not the source of the visible download buttons | No current visible effect in the default show page. |
| `url_suppl_ssm` | `856$u` with indicator logic | Indexed only | No current visible effect. |
| `lc_callnum_ssm` | `050ab` | Indexed only in current UI config | No current visible effect. |
| `lc_1letter_ssim` | `050ab` first letter + translation map | Indexed only | No current visible effect. |
| `lc_alpha_ssim` | `050a` alpha prefix | Indexed only | No current visible effect. |
| `lc_b4cutter_ssim` | `050a` first value | Indexed only | No current visible effect. |

## Infrastructure fields

| Solr field | MARC source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `marc_ss` | Entire record as MARC XML | Librarian/MARC-style view through `Blacklight::Marc::DocumentExtension`; also helps the text export build MARC metadata | If missing, the detailed metadata / MARC view may be unavailable or incomplete. |
| `all_text_timv` | Entire record | `all_fields` searching | If missing, broad keyword retrieval is weaker. |

---

# Fields Used By The Catalog But Not Built In `MarcIndexer`

These still matter for display.

| Field | Source | Where used | If missing or wrong |
| --- | --- | --- | --- |
| `ark` | External ingest | Persistent URL display, Mirador, downloads, IIIF tools, citations, page search, text export | Missing `ark` causes the biggest visible failures on item pages. |
| `tx_gen` | External OCR/full-text indexing | Full-text search option in the catalog | If absent, the "Full Text" search option will return poor or no OCR hits. |
| `tx_general_lang`, `tx_fr`, `tx_de`, etc. | External OCR/full-text indexing | Weighted search fields for full-text searching | If absent, full-text relevance ranking is weaker. |
| `language_ssim_str`, `author_ssm_str`, `subject_ssim_str`, `depositor_tsim_str`, `serial_title_str`, `is_issue_str`, `is_serial_str` | Solr `copyField` rules | Facets | These are derived automatically from their base fields. If the base field is wrong, the facet copy is wrong too. |

---

# Serial Parent And Issue Rules

## To make a serial parent display correctly

Required:

- `001` must be stable and unique
- `901` must be `Is series`

Recommended:

- `245$a` should contain the serial title
- `999$e` / `999$f` should contain collection breadcrumb hierarchy

If `901 = Is series` is missing:

- the record will not use the serial-parent issue list layout
- it will be treated like a normal item page

## To make an issue display correctly under a parent

Required:

- `901` must be `Is issue`
- `902$b` must equal the parent record's `001`

Recommended:

- `245$a` should begin with the serial title, because that is what becomes `serial_title`
- `245$b` should hold the issue-specific part, because the issue cards display `subtitle_tsim`

If `902$b` is wrong:

- the issue will not appear under the parent's issue list
- the issue breadcrumb link back to the parent will be wrong

If `245$b` is missing:

- the issue card on the parent page may have no visible heading

If `245$a` is badly structured:

- the issue breadcrumb label may be cut strangely or may show the wrong text

---

# Worked Example

## Serial parent

**MARC**

- `001`: `oocihm.N_00229`
- `901`: `Is series`
- `245$a`: `The Dawn of tomorrow`
- `999$e`: `Serials`
- `999$f`: `Publications en serie`

**Important indexed values**

- `id = oocihm.N_00229`
- `is_serial = Yes`
- `is_issue = No`
- `serial_title = The Dawn of tomorrow`

**What the user sees**

- serial-parent layout
- issue cards instead of Mirador
- collection breadcrumb/facet if `999$e/$f` are present

## Issue

**MARC**

- `001`: `oocihm.N_00229_195503`
- `901`: `Is issue`
- `902$b`: `oocihm.N_00229`
- `245$a`: `The Dawn of tomorrow`
- `245$b`: `Vol. V, no. 31 (March 1955)`
- `264$c`: `[1955]`

**Important indexed values**

- `id = oocihm.N_00229_195503`
- `is_issue = Yes`
- `is_serial = No`
- `serial_key = oocihm.N_00229`
- `serial_title = The Dawn of tomorrow`
- `subtitle_tsim = Vol. V, no. 31 (March 1955)`
- `pub_date_ssim = 1955`

**What the user sees**

- on the parent record page, this issue appears in the issue list
- the issue card title comes from `subtitle_tsim`
- on the issue page, the breadcrumb parent link points to `/catalog/oocihm.N_00229`

---

# Troubleshooting

## The parent record shows Mirador instead of issue cards

Check:

- does `901` equal `Is series` exactly, ignoring case?

## An issue does not appear under the parent

Check:

- does the issue have `901 = Is issue`?
- does the issue have `902$b = parent 001`?

Do **not** troubleshoot this with `490$v`; the current code does not use it for `serial_key`.

## The issue breadcrumb text is wrong

Check:

- `245$a` on the issue record

The app turns `245$a` into `serial_title` and cuts off everything after the first colon.

## The issue card is blank or has no useful heading

Check:

- `245$b`

The serial-parent issue cards use `subtitle_tsim`, which comes from `245$b`.

## Dates do not facet or sort correctly

Check:

- `260/264` for publication date parsing
- `998` for `date_added`

If the parser cannot derive a clean publication year, `pub_date_ssim` will be missing and the record will behave badly in year facets and year sorts.

## The viewer, downloads, or page-hit chips are missing

Check:

- `ark`

This field is required for:

- persistent URL display
- Mirador
- IIIF toolbox links
- download links
- page-level hit navigation
- text export

---

# Quick Reference

- `id` comes from `001`
- `is_issue` comes from `901 = Is issue`
- `is_serial` comes from `901 = Is series`
- `serial_key` comes from `902$b`
- issue grouping works when `issue 902$b = parent 001`
- result title uses `full_title_tsim`
- issue card title uses `subtitle_tsim` from `245$b`
- issue breadcrumb label uses `serial_title` from `245$a`
- Mirador and downloads need `ark`
- year facet/sort need a parsable publication date
