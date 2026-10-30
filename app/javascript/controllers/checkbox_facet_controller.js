import { Controller } from "@hotwired/stimulus";

/**
 * Checkbox Facet Controller
 * 
 * Manages synchronization between sidebar facet checkboxes and modal
 * checkboxes when facets are displayed in a modal dialog.
 * Replaces the inline script from checkbox_facet_component.html.erb.
 */
export default class extends Controller {
  connect() {
    this.form = this.element.classList?.contains("checkbox-facet-form")
      ? this.element
      : this.element.querySelector(".checkbox-facet-form");

    if (!this.form) return;

    this.facetKey = this.getFacetKey(this.form);
    this.setupEventListeners();
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

  setupEventListeners() {
    // Set up checkbox change listeners
    const checkboxes = this.form.querySelectorAll(".checkbox-facet-input");
    checkboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", (e) => this.handleCheckboxChange(e));
    });

    // Handle modal open/load events across Blacklight and Bootstrap
    this.onModalLoaded = () => this.syncModalFromSidebar();
    document.addEventListener("loaded.blacklight.blacklight-modal", this.onModalLoaded);
    document.addEventListener("blacklight:modal:loaded", this.onModalLoaded);
    document.addEventListener("show.bs.modal", this.onModalLoaded);
    document.addEventListener("shown.bs.modal", this.onModalLoaded);
  }

  disconnect() {
    if (this.onModalLoaded) {
      document.removeEventListener("loaded.blacklight.blacklight-modal", this.onModalLoaded);
      document.removeEventListener("blacklight:modal:loaded", this.onModalLoaded);
      document.removeEventListener("show.bs.modal", this.onModalLoaded);
      document.removeEventListener("shown.bs.modal", this.onModalLoaded);
    }
  }

  isInModal() {
    return !!this.form.closest(".modal");
  }

  handleCheckboxChange(event) {
    const checkbox = event.target;
    const value = checkbox.value;
    const isNowChecked = checkbox.checked;

    if (!this.isInModal()) {
      this.syncCheckboxToOpenModal(value, isNowChecked);
    } else {
      this.syncCheckboxToSidebar(value, isNowChecked);
    }
  }

  findSidebarForm(facetKey) {
    if (!facetKey) return null;
    const forms = Array.from(document.querySelectorAll("form.checkbox-facet-form")).filter(
      (f) => !f.closest(".modal")
    );
    return (
      forms.find(
        (f) =>
          this.getFacetKey(f) === facetKey ||
          f.querySelector(`input[name="f_inclusive[${CSS.escape(facetKey)}][]"]`)
      ) || null
    );
  }

  syncCheckboxToOpenModal(value, isChecked) {
    const modalForm = document.querySelector(".modal form.checkbox-facet-form");
    if (!modalForm) return;

    const modalFacetKey = this.getFacetKey(modalForm);
    if (modalFacetKey !== this.facetKey) return;

    const modalCheckbox = modalForm.querySelector(
      `.checkbox-facet-input[value="${CSS.escape(value)}"]`
    );
    if (modalCheckbox && modalCheckbox.checked !== isChecked) {
      modalCheckbox.checked = isChecked;
    }
    this.syncOffpageSelections(modalForm);
  }

  syncCheckboxToSidebar(value, isChecked) {
    const sidebarForm = this.findSidebarForm(this.facetKey);
    if (!sidebarForm) return;

    const sidebarCheckbox = sidebarForm.querySelector(
      `.checkbox-facet-input[value="${CSS.escape(value)}"]`
    );
    if (sidebarCheckbox && sidebarCheckbox.checked !== isChecked) {
      sidebarCheckbox.checked = isChecked;
    }
  }

  syncModalFromSidebar() {
    const modalForm = document.querySelector(".modal form.checkbox-facet-form");
    if (!modalForm) return;

    const facetKey = this.getFacetKey(modalForm);
    if (!facetKey || facetKey !== this.facetKey) return;

    const sidebarForm = this.findSidebarForm(facetKey);
    if (!sidebarForm) return;

    const checkedInSidebar = new Set(
      Array.from(
        sidebarForm.querySelectorAll(
          `input[type="checkbox"][name="f_inclusive[${CSS.escape(facetKey)}][]"]`
        )
      )
        .filter((cb) => cb.checked && !cb.disabled)
        .map((cb) => cb.value)
    );

    Array.from(
      modalForm.querySelectorAll(
        `input[type="checkbox"][name="f_inclusive[${CSS.escape(facetKey)}][]"]`
      )
    ).forEach((mCb) => {
      mCb.checked = checkedInSidebar.has(mCb.value);
    });

    this.syncOffpageSelections(modalForm);
  }

  syncOffpageSelections(modalForm) {
    if (!modalForm || !modalForm.closest(".modal")) return;
    const facetKey = this.getFacetKey(modalForm);
    if (!facetKey) return;

    const sidebarForm = this.findSidebarForm(facetKey);
    if (!sidebarForm) return;

    const sidebarChecked = Array.from(
      sidebarForm.querySelectorAll(
        `input[type="checkbox"][name="f_inclusive[${CSS.escape(facetKey)}][]"]`
      )
    )
      .filter((cb) => cb.checked && !cb.disabled)
      .map((cb) => cb.value);

    const modalRendered = new Set(
      Array.from(
        modalForm.querySelectorAll(
          `input[type="checkbox"][name="f_inclusive[${CSS.escape(facetKey)}][]"]`
        )
      ).map((cb) => cb.value)
    );

    const desiredOffpage = sidebarChecked.filter((val) => !modalRendered.has(val));

    let box = modalForm.querySelector(".js-modal-offpage-selections");
    if (!box) {
      box = document.createElement("div");
      box.className = "js-modal-offpage-selections";
      box.hidden = true;
      modalForm.insertBefore(box, modalForm.firstChild);
    }

    const currentOffpage = Array.from(
      box.querySelectorAll("input.js-modal-offpage-selection")
    ).map((inp) => inp.value);

    if (
      currentOffpage.length === desiredOffpage.length &&
      currentOffpage.every((v, idx) => v === desiredOffpage[idx])
    ) {
      return;
    }

    box.innerHTML = "";
    desiredOffpage.forEach((val) => {
      const hidden = document.createElement("input");
      hidden.type = "hidden";
      hidden.className = "js-modal-offpage-selection";
      hidden.name = `f_inclusive[${facetKey}][]`;
      hidden.value = val;
      box.appendChild(hidden);
    });
  }
}
