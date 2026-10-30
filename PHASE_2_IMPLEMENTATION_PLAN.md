# Phase 2: Stimulus Controller Implementation Plan

**Status:** ⏳ IN PROGRESS  
**Date:** 2026-10-30  
**Phase Duration:** Estimated 4-6 hours

---

## Overview

Phase 2 restores the functionality removed in Phase 1.2 using Stimulus controllers instead of inline scripts.

**Goal:** Convert removed inline JavaScript into three atomic Stimulus controllers with no CSP violations.

### Phase 1 Recap
- 412 LOC of inline scripts removed
- All component structure and data attributes preserved
- Identified 5+ removed functions to re-implement as controllers

### Phase 2 Scope
- Create 3 Stimulus controllers (checkbox-facet, copy-link, download-status)
- Integrate controllers with ViewComponents using data-controller attributes
- Add @hotwired/stimulus to package dependencies
- Create controller bindings and event handlers
- Document and test controllers
- **No regressions expected:** Pure functionality restoration

---

## Work Breakdown

### Step 1: Add @hotwired/stimulus to Dependencies ✅
**Status:** PENDING
**Effort:** 5 min

- [ ] Add `@hotwired/stimulus` to package.json dependencies
- [ ] Run `yarn install` to update lock file
- [ ] Commit changes with message: "chore: add @hotwired/stimulus dependency for Phase 2 controllers"

### Step 2: Create Stimulus Controller Files ✅
**Status:** DONE
**Effort:** 30 min

Created 3 Stimulus controllers with full documentation:

#### 2a: checkbox-facet-controller.js ✅
- **File:** `app/javascript/controllers/checkbox_facet_controller.js`
- **Lines:** ~140
- **Functionality:**
  - Listen for checkbox changes in facet forms
  - Sync changes between sidebar and modal checkboxes
  - Handle facet "More" link clicks
  - Sync offpage selections
  - Handle modal form submission
- **Removed Functions Restored:**
  - `syncCheckboxFacetMoreLink()`
  - `syncSingleCheckboxToSidebar()`
  - `syncSingleCheckboxToModal()`
  - `syncOffpageSelectionsInModalForm()`
  - `syncModalPaginationLink()`

#### 2b: copy-link-controller.js ✅
- **File:** `app/javascript/controllers/copy_link_controller.js`
- **Lines:** ~130
- **Functionality:**
  - Handle copy button clicks
  - Copy manifest URL to clipboard (navigator.clipboard API)
  - Fallback for older browsers (execCommand)
  - Display success/error feedback in ARIA live region
  - Auto-hide feedback after 3 seconds
- **Removed Functions Restored:**
  - `copyManifestUrl()` (56 LOC with fallback logic)

#### 2c: download-status-controller.js ✅
- **File:** `app/javascript/controllers/download_status_controller.js`
- **Lines:** ~210
- **Functionality:**
  - Poll `/dl/{docid}/{ark}` endpoint every 500ms
  - Update UI with file availability status
  - Enable/disable download buttons based on status
  - Handle visibility changes (pause when tab hidden)
  - Max polling duration ~30 seconds
  - Graceful error handling with retry logic
- **Removed Functions Restored:**
  - `updateForCurrentPage()`
  - `handleVisibilityChange()`
  - `isArkPathReady()`
  - Download polling interval logic

### Step 3: Register Controllers with Rails ⏳
**Status:** PENDING
**Effort:** 5 min

- [ ] Create `app/javascript/controllers/index.js` with controller registration
- [ ] Import all 3 controllers
- [ ] Register with Stimulus application
- [ ] Verify controllers are loaded in browser DevTools

### Step 4: Wire Controllers to ViewComponents ⏳
**Status:** PENDING
**Effort:** 20 min

#### 4a: checkbox_facet_component.html.erb
- Add `data-controller="checkbox-facet"` to component root
- Verify form structure (`data-facet_key` attribute)
- Test checkbox sync behavior

#### 4b: iiif_component.html.erb
- Add `data-controller="copy-link"` to component root
- Verify copy button has `.copy-link-btn` class
- Verify manifest link has `#iiif-manifest-url` ID
- Verify feedback span has `#iiif-copy-feedback` ID

#### 4c: document_component.html.erb (download toolbar)
- Add `data-controller="download-status"` to `#download-toolbar`
- Verify toolbar has `data-docid` and `data-arkpath` attributes
- Verify download buttons have correct IDs
- Verify status display has `#download-status` ID and ARIA attributes

### Step 5: Import Controllers in Application ⏳
**Status:** PENDING
**Effort:** 10 min

- [ ] Add Stimulus import to `app/javascript/entrypoints/application.js`
- [ ] Import controller index from `controllers/index.js`
- [ ] Verify no console errors related to Stimulus
- [ ] Test that controllers are connecting to elements

### Step 6: Test Controllers ⏳
**Status:** PENDING
**Effort:** 60 min

#### Manual Testing
- [ ] Copy manifest link button works
- [ ] Checkbox facet sync works (sidebar ↔ modal)
- [ ] Download buttons enable/disable based on file availability
- [ ] Feedback messages display correctly
- [ ] No CSP violations in console
- [ ] No regression in other functionality

#### Automated Testing
- [ ] Update Capybara/Selenium tests to verify controller behavior
- [ ] Run full test suite
- [ ] Document any test updates

### Step 7: Create Atomic Commits ⏳
**Status:** PENDING
**Effort:** 15 min

Create 4 atomic commits:

1. **Commit 1:** Add @hotwired/stimulus dependency
   ```
   chore: add @hotwired/stimulus dependency for Phase 2 controllers
   ```

2. **Commit 2:** Create Stimulus controllers
   ```
   feat: add Stimulus controllers for Phase 2 implementation
   
   Implements three controllers to restore functionality removed in Phase 1.2:
   - checkbox-facet-controller: Facet modal sync
   - copy-link-controller: IIIF manifest copy button
   - download-status-controller: Download polling
   
   All controllers use preserved data attributes and ARIA elements.
   No inline scripts or onclick attributes.
   CSP compliant.
   
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```

3. **Commit 3:** Wire controllers to components
   ```
   feat: integrate Stimulus controllers with ViewComponents
   
   Adds data-controller attributes to:
   - checkbox_facet_component.html.erb
   - iiif_component.html.erb
   - document_component.html.erb
   
   Functionality restored:
   - Facet modal checkbox synchronization
   - Copy manifest link to clipboard
   - Download file availability polling
   
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```

4. **Commit 4:** Update tests and documentation
   ```
   docs: update tests and documentation for Phase 2
   
   - Update Capybara/Selenium tests for controller behavior
   - Create Phase 2 completion report
   - Document expected behavior and workarounds
   
   Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
   ```

### Step 8: Document Phase 2 Completion ⏳
**Status:** PENDING
**Effort:** 30 min

- [ ] Create `PHASE_2_COMPLETION.md` with full report
- [ ] Document expected behavior changes
- [ ] List all controllers and their functions
- [ ] Update `REFACTORING_CONTINUATION_PLAN.md` with progress
- [ ] Create checkpoint in session

---

## Expected Outcomes

### ✅ Functionality Restored
After Phase 2 completion, all features removed in Phase 1.2 will be functional:

| Feature | Status | Controller |
|---------|--------|-----------|
| Facet modal checkbox sync | ✅ Restored | checkbox-facet-controller |
| Copy manifest link | ✅ Restored | copy-link-controller |
| Download polling | ✅ Restored | download-status-controller |

### ✅ Code Quality
- **0 inline scripts** (all moved to controllers)
- **0 onclick attributes** (all moved to event listeners)
- **100% CSP compliant** (no unsafe-inline)
- **Well-documented** (inline comments and JSDOC)
- **Testable** (clear separation of concerns)

### ✅ No Regressions
- Same HTML structure (preserved data attributes)
- Same ARIA attributes (a11y intact)
- Same event behavior (just different implementation)
- Same user experience

---

## Timeline

| Step | Task | Effort | Status |
|------|------|--------|--------|
| 1 | Add Stimulus dependency | 5 min | ⏳ Pending |
| 2 | Create controllers | 30 min | ✅ Done |
| 3 | Register controllers | 5 min | ⏳ Pending |
| 4 | Wire to components | 20 min | ⏳ Pending |
| 5 | Import in application | 10 min | ⏳ Pending |
| 6 | Test controllers | 60 min | ⏳ Pending |
| 7 | Create commits | 15 min | ⏳ Pending |
| 8 | Document | 30 min | ⏳ Pending |
| **TOTAL** | **Phase 2** | **~2-3 hours** | **⏳ In Progress** |

---

## Success Criteria

Phase 2 is COMPLETE when:

- [x] 3 Stimulus controllers created and documented
- [ ] @hotwired/stimulus added to package.json
- [ ] Controllers registered with Stimulus app
- [ ] Controllers wired to ViewComponents with data-controller attributes
- [ ] All functionality from Phase 1.2 removed code restored
- [ ] All manual tests pass (copy, facet sync, download polling)
- [ ] Automated tests pass (Capybara/Selenium suite)
- [ ] 4 atomic commits created with proper messages
- [ ] Phase 2 completion report created
- [ ] 0 CSP violations
- [ ] 0 console errors

---

## Risks & Mitigation

### Risk: Stimulus not compatible with current Rails version
**Mitigation:** @hotwired/stimulus is standard in Rails 7+. Check Rails version first.

### Risk: Controllers don't activate because data-controller not set
**Mitigation:** Verify data-controller attributes added to component templates. Check browser DevTools for connected elements.

### Risk: Download polling doesn't work (API endpoint issues)
**Mitigation:** This is Phase 2 only - actual backend is Phase 3. Use mock endpoint for testing.

### Risk: Modal sync doesn't work (Blacklight modal system incompatibility)
**Mitigation:** Review Blacklight's modal triggering mechanism. May need to hook into different events.

---

## Next Phase: Phase 3

Once Phase 2 is complete:

1. **Phase 3:** Server-Side Integration
   - Implement Redis caching for download status
   - Implement Solr integration for advanced search
   - Server-side API endpoints
   - Backend file generation and polling

2. **Phase 4:** Comprehensive Refactoring
   - Performance optimization
   - Additional dead code removal
   - Architecture modernization

---

## Current Status

**Controllers Created:** ✅ 3 files
- `app/javascript/controllers/checkbox_facet_controller.js`
- `app/javascript/controllers/copy_link_controller.js`
- `app/javascript/controllers/download_status_controller.js`

**Next Action:** Add Stimulus to package.json and integrate with components

**Estimated Completion:** ~2-3 hours from now

---

**Status:** Phase 2 ⏳ IN PROGRESS  
**Controllers Ready:** ✅ YES (3 files created)  
**Ready for Integration:** ⏳ WAITING (need Stimulus dependency first)
