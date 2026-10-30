import { Controller } from "@hotwired/stimulus";

function normalizeMemberFilterValue(value = "") {
  return String(value)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim();
}

export default class extends Controller {
  static targets = ["tab", "group", "chip", "input", "clearBtn", "emptyState"];

  connect() {
    this.activeGroup = this.element.querySelector("[data-members-tab].active")?.dataset.membersTab || "institutional";
    this.activeProvince = this.element.querySelector(".chip-filter.active")?.dataset.province || "all";
    this.filterText = "";

    this.groups = Array.from(this.element.querySelectorAll("[data-members-group]"));
    this.tabs = Array.from(this.element.querySelectorAll("[data-members-tab]"));
    this.chips = Array.from(this.element.querySelectorAll(".chip-filter"));
    this.inputEl = this.hasInputTarget ? this.inputTarget : this.element.querySelector("#members-filter-input");
    this.clearBtnEl = this.hasClearBtnTarget ? this.clearBtnTarget : this.element.querySelector(".btn-clear-members");
    this.emptyStateEl = this.hasEmptyStateTarget ? this.emptyStateTarget : this.element.querySelector("[data-members-empty]");

    // Initialize initial state
    const selectedTab = this.element.querySelector("[data-members-tab].active") || this.tabs[0];
    if (selectedTab) this.activateTabElement(selectedTab);

    const selectedProvince = this.element.querySelector(".chip-filter.active") || this.chips[0];
    if (selectedProvince) this.activateProvinceElement(selectedProvince);
    else this.applyFilters();
  }

  activateTab(event) {
    const btn = event.currentTarget;
    this.activateTabElement(btn);
  }

  activateTabElement(btn) {
    this.tabs.forEach((item) => {
      const selected = item === btn;
      item.classList.toggle("active", selected);
      item.setAttribute("aria-selected", selected ? "true" : "false");
      item.setAttribute("tabindex", selected ? "0" : "-1");
    });
    this.activeGroup = btn.dataset.membersTab || "institutional";
    this.applyFilters();
  }

  navigateTabs(event) {
    const keys = ["ArrowRight", "ArrowLeft", "Home", "End"];
    if (!keys.includes(event.key)) return;
    event.preventDefault();

    const currentIndex = this.tabs.indexOf(event.currentTarget);
    let nextIndex = currentIndex;
    if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % this.tabs.length;
    if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + this.tabs.length) % this.tabs.length;
    if (event.key === "Home") nextIndex = 0;
    if (event.key === "End") nextIndex = this.tabs.length - 1;

    const nextTab = this.tabs[nextIndex];
    if (nextTab) {
      this.activateTabElement(nextTab);
      nextTab.focus();
    }
  }

  activateProvince(event) {
    const chip = event.currentTarget;
    this.activateProvinceElement(chip);
  }

  activateProvinceElement(chip) {
    this.chips.forEach((item) => {
      const selected = item === chip;
      item.classList.toggle("active", selected);
      item.setAttribute("aria-pressed", selected ? "true" : "false");
    });
    this.activeProvince = chip.dataset.province || "all";
    this.applyFilters();
  }

  onInput(event) {
    const val = event.target.value;
    this.filterText = normalizeMemberFilterValue(val);
    if (this.clearBtnEl) this.clearBtnEl.hidden = val.length === 0;
    this.applyFilters();
  }

  clearSearch() {
    if (this.inputEl) {
      this.inputEl.value = "";
      this.inputEl.focus();
    }
    this.filterText = "";
    if (this.clearBtnEl) this.clearBtnEl.hidden = true;
    this.applyFilters();
  }

  applyFilters() {
    let hasVisibleItems = false;
    const activeChip = this.element.querySelector(".chip-filter.active");
    this.activeProvince = activeChip?.dataset?.province || this.activeProvince || "all";
    const hasActiveFilter = this.activeProvince !== "all" || this.filterText !== "";

    this.groups.forEach((group) => {
      const isActiveGroup = group.dataset.membersGroup === this.activeGroup;
      group.classList.toggle("d-none", !isActiveGroup);
      group.setAttribute("aria-hidden", isActiveGroup ? "false" : "true");
      group.classList.toggle("is-filtered-view", isActiveGroup && hasActiveFilter);
      if (!isActiveGroup) return;

      const seenMemberNames = new Set();

      group.querySelectorAll(".members-marquee-row").forEach((row) => {
        let rowHasVisibleItem = false;

        row.querySelectorAll(".member-logo").forEach((logo) => {
          const prov = logo.dataset.province || "";
          const name = logo.dataset.memberName || "";
          const isClone = logo.dataset.memberClone === "true" || logo.getAttribute("tabindex") === "-1";
          const provinceMatch = this.activeProvince === "all" || prov === this.activeProvince;
          const textMatch = this.filterText === "" || name.includes(this.filterText);
          const isVisible = provinceMatch && textMatch;
          const isDuplicateName = hasActiveFilter && seenMemberNames.has(name);
          const shouldShowLogo = isVisible && (!hasActiveFilter || (!isClone && !isDuplicateName));

          logo.classList.toggle("is-filtered-out", !shouldShowLogo);
          if (shouldShowLogo && !isClone) {
            seenMemberNames.add(name);
            rowHasVisibleItem = true;
          }
        });

        row.classList.toggle("d-none", !rowHasVisibleItem);
        if (rowHasVisibleItem) hasVisibleItems = true;
      });
    });

    if (this.emptyStateEl) {
      this.emptyStateEl.classList.toggle("d-none", hasVisibleItems);
    }
  }
}
