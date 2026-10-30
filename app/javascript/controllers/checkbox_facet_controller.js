import { Controller } from "@hotwired/stimulus";

/**
 * Checkbox Facet Controller
 * 
 * Manages synchronization between sidebar facet checkboxes and modal
 * checkboxes when facets are displayed in a modal dialog.
 * 
 * Replaces inline script functions:
 *   - syncCheckboxFacetMoreLink()
 *   - syncSingleCheckboxToSidebar()
 *   - syncSingleCheckboxToModal()
 *   - syncOffpageSelectionsInModalForm()
 *   - syncModalPaginationLink()
 * 
 * Data attributes:
 *   - [data-controller="checkbox-facet"]
 *   - Form structure: .checkbox-facet-form[data-facet_key="..."]
 *   - Checkboxes: .checkbox-facet-input
 */
export default class extends Controller {
  connect() {
    this.form = this.element.querySelector(".checkbox-facet-form");
    if (!this.form) return;

    this.facetKey = this.form.dataset.facetKey;
    this.setupEventListeners();
  }

  setupEventListeners() {
    // Set up checkbox change listeners
    const checkboxes = this.form.querySelectorAll(".checkbox-facet-input");
    checkboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", (e) =>
        this.handleCheckboxChange(e)
      );
    });

    // Monitor for modal open/close and sync checkboxes
    document.addEventListener(
      "blacklight:modal:open",
      (e) => this.handleModalOpen(e),
      true
    );
  }

  handleCheckboxChange(event) {
    const checkbox = event.target;
    const value = checkbox.value;
    const isNowChecked = checkbox.checked;

    // If this change is in the sidebar, sync to modal if open
    if (!this.isInModal()) {
      this.syncCheckboxToOpenModal(value, isNowChecked);
    }
  }

  syncCheckboxToOpenModal(value, isChecked) {
    // Find open modal for this facet
    const modalContent = document.querySelector(
      `.modal-body .checkbox-facet-form[data-facet_key="${this.facetKey}"]`
    );

    if (modalContent) {
      const modalCheckbox = modalContent.querySelector(
        `.checkbox-facet-input[value="${CSS.escape(value)}"]`
      );

      if (modalCheckbox && modalCheckbox.checked !== isChecked) {
        modalCheckbox.checked = isChecked;
      }
    }
  }

  handleModalOpen(event) {
    // When modal opens, sync sidebar selections to modal checkboxes
    const modalContent = event.detail?.content;
    if (!modalContent) return;

    const modalForm = modalContent.querySelector(
      `.checkbox-facet-form[data-facet_key="${this.facetKey}"]`
    );
    if (!modalForm) return;

    // Sync sidebar checked values to modal
    this.syncModalFromSidebar(modalContent);
  }

  syncModalFromSidebar(modalContainer) {
    // Get all checked values from sidebar
    const sidebarCheckboxes = this.form.querySelectorAll(
      ".checkbox-facet-input:checked"
    );
    const checkedValues = Array.from(sidebarCheckboxes).map(
      (cb) => cb.value
    );

    // Check corresponding checkboxes in modal
    const modalCheckboxes = modalContainer.querySelectorAll(
      ".checkbox-facet-form[data-facet_key='" + this.facetKey + "'] .checkbox-facet-input"
    );

    modalCheckboxes.forEach((checkbox) => {
      checkbox.checked = checkedValues.includes(checkbox.value);
    });

    // Sync offpage selections
    const offpageContainer = this.form.querySelector(
      ".js-modal-offpage-selections"
    );
    if (offpageContainer) {
      const offpageInputs = offpageContainer.querySelectorAll(
        ".js-modal-offpage-selection"
      );
      offpageInputs.forEach((input) => {
        const checkbox = modalContainer.querySelector(
          `.checkbox-facet-input[value="${CSS.escape(input.value)}"]`
        );
        if (checkbox) {
          checkbox.checked = true;
        }
      });
    }
  }

  isInModal() {
    return this.form.closest(".modal");
  }
}
