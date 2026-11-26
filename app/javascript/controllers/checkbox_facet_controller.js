import { Controller } from "@hotwired/stimulus";

/**
 * Checkbox Facet Controller
 *
 * Keeps sidebar facet checkboxes and the "more »" modal in sync.
 *
 * The modal never shows every value at once: patrons page through it
 * (facet.page), search inside it (facet_suggest swaps the list via innerHTML) and
 * clear that search again. Each of those replaces the rendered checkboxes, so the
 * DOM alone cannot remember what was ticked. Instead, one module-level store holds the
 * patron's selections for the facet while the modal is open:
 *
 *   - seeded on first load from the sidebar (or the server-rendered modal),
 *   - updated on every checkbox change,
 *   - re-applied to every freshly rendered modal list, and
 *   - written into hidden `f_inclusive[...]` inputs for values that are not on screen,
 *     so "Apply" submits every selection.
 *
 * The store is dropped when the modal closes or a sidebar "more »" link is clicked.
 */
const modalSelection = { facetKey: null, values: null };

function resetModalSelection() {
  modalSelection.facetKey = null;
  modalSelection.values = null;
}

if (typeof document !== "undefined" && !window.__checkboxFacetStoreBound) {
  window.__checkboxFacetStoreBound = true;
  document.addEventListener("hidden.bs.modal", resetModalSelection);
  document.addEventListener(
    "click",
    (e) => {
      if (e.target && e.target.closest && e.target.closest("[data-checkbox-facet-more]")) {
        resetModalSelection();
      }
    },
    true
  );
}

export default class extends Controller {
  connect() {
    this.form = this.element.classList?.contains("checkbox-facet-form")
      ? this.element
      : this.element.querySelector(".checkbox-facet-form");

    if (!this.form) return;

    this.facetKey = this.getFacetKey(this.form);
    this.onChange = (e) => {
      if (e.target && e.target.matches && e.target.matches(".checkbox-facet-input")) {
        this.handleCheckboxChange(e);
      }
    };
    this.form.addEventListener("change", this.onChange);

    if (this.isInModal()) this.initModalSelection();
  }

  disconnect() {
    if (this.form && this.onChange) {
      this.form.removeEventListener("change", this.onChange);
    }
  }

  isInModal() {
    return !!this.form.closest(".modal");
  }

  getFacetKey(form) {
    if (!form) return null;
    if (form.dataset && form.dataset.facetKey) return form.dataset.facetKey;
    if (form.getAttribute("data-facet-key")) return form.getAttribute("data-facet-key");
    if (form.getAttribute("data-facet_key")) return form.getAttribute("data-facet_key");
    const cb = form.querySelector('input[type="checkbox"][name^="f_inclusive["]');
    if (cb) {
      const m = cb.name.match(/^f_inclusive\[([^\]]+)\]\[\]$/);
      if (m && m[1]) return m[1];
    }
    return null;
  }

  inputName(facetKey = this.facetKey) {
    return `f_inclusive[${facetKey}][]`;
  }

  checkboxesIn(form, facetKey = this.facetKey) {
    return Array.from(
      form.querySelectorAll(`input[type="checkbox"][name="${CSS.escape(this.inputName(facetKey))}"]`)
    );
  }

  findSidebarForm(facetKey) {
    if (!facetKey) return null;
    const forms = Array.from(document.querySelectorAll("form.checkbox-facet-form")).filter(
      (f) => !f.closest(".modal")
    );
    return forms.find((f) => this.getFacetKey(f) === facetKey) || null;
  }

  // ---------------------------------------------------------------- modal side

  initModalSelection() {
    if (!this.facetKey) return;

    if (modalSelection.facetKey !== this.facetKey || !modalSelection.values) {
      modalSelection.facetKey = this.facetKey;
      modalSelection.values = this.seedSelection();
    }
    this.applyStoreToModal();
  }

  // Sidebar state wins (it holds applied filters plus any not-yet-applied toggles);
  // otherwise fall back to whatever the server rendered inside the modal.
  seedSelection() {
    const sidebarForm = this.findSidebarForm(this.facetKey);
    if (sidebarForm) {
      return new Set(
        this.checkboxesIn(sidebarForm)
          .filter((cb) => cb.checked && !cb.disabled)
          .map((cb) => cb.value)
      );
    }

    const values = new Set(
      this.checkboxesIn(this.form)
        .filter((cb) => cb.checked)
        .map((cb) => cb.value)
    );
    this.form.querySelectorAll("input.js-modal-offpage-selection").forEach((inp) => values.add(inp.value));
    return values;
  }

  applyStoreToModal() {
    const store = modalSelection.values;
    if (!store) return;

    const rendered = new Set();
    this.checkboxesIn(this.form).forEach((cb) => {
      rendered.add(cb.value);
      cb.checked = store.has(cb.value);
    });

    this.writeOffpageInputs(Array.from(store).filter((v) => !rendered.has(v)));
  }

  writeOffpageInputs(values) {
    let box = this.form.querySelector(".js-modal-offpage-selections");
    if (!box) {
      box = document.createElement("div");
      box.className = "js-modal-offpage-selections";
      box.hidden = true;
      this.form.insertBefore(box, this.form.firstChild);
    }

    box.innerHTML = "";
    values.forEach((val) => {
      const hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.className = "js-modal-offpage-selection";
      hidden.name = this.inputName();
      hidden.value = val;
      box.appendChild(hidden);
    });
  }

  // --------------------------------------------------------------- change sync

  handleCheckboxChange(event) {
    const { value, checked } = event.target;

    if (this.isInModal()) {
      this.initStoreIfMissing();
      if (checked) modalSelection.values.add(value);
      else modalSelection.values.delete(value);
      this.applyStoreToModal();
      this.setCheckbox(this.findSidebarForm(this.facetKey), value, checked);
    } else if (modalSelection.facetKey === this.facetKey && modalSelection.values) {
      // Sidebar toggled while the modal for the same facet is open.
      if (checked) modalSelection.values.add(value);
      else modalSelection.values.delete(value);
      const modalForm = document.querySelector(".modal form.checkbox-facet-form");
      if (modalForm && this.getFacetKey(modalForm) === this.facetKey) {
        this.setCheckbox(modalForm, value, checked);
      }
    }
  }

  initStoreIfMissing() {
    if (modalSelection.facetKey !== this.facetKey || !modalSelection.values) {
      modalSelection.facetKey = this.facetKey;
      modalSelection.values = this.seedSelection();
    }
  }

  setCheckbox(form, value, checked) {
    if (!form) return;
    const cb = this.checkboxesIn(form, this.getFacetKey(form)).find((c) => c.value === value);
    if (cb && cb.checked !== checked) cb.checked = checked;
  }
}
