import { Controller } from "@hotwired/stimulus";

function getFacetCardId(card) {
  const collapseEl = card.querySelector(".facet-content.collapse");
  if (collapseEl && collapseEl.id) return collapseEl.id;
  const match = card.className.split(/\s+/).find((c) => c.startsWith("blacklight-"));
  return match || "";
}

function setFacetCardExpanded(card, expand) {
  const collapseEl = card.querySelector(".facet-content.collapse");
  const btn = card.querySelector(
    ".card-header button.collapse-toggle, button[data-bs-toggle='collapse'], button[data-toggle='collapse']"
  );
  if (!collapseEl) return;

  if (expand) {
    collapseEl.classList.add("show");
    if (btn) {
      btn.classList.remove("collapsed");
      btn.setAttribute("aria-expanded", "true");
    }
  } else {
    collapseEl.classList.remove("show");
    if (btn) {
      btn.classList.add("collapsed");
      btn.setAttribute("aria-expanded", "false");
    }
  }
}

export default class extends Controller {
  connect() {
    this.boundCollapseChange = this.handleCollapseChange.bind(this);
    this.boundHandleClick = this.handleClick.bind(this);

    this.element.addEventListener("shown.bs.collapse", this.boundCollapseChange);
    this.element.addEventListener("hidden.bs.collapse", this.boundCollapseChange);
    this.element.addEventListener("click", this.boundHandleClick);

    this.restoreState();
  }

  disconnect() {
    this.element.removeEventListener("shown.bs.collapse", this.boundCollapseChange);
    this.element.removeEventListener("hidden.bs.collapse", this.boundCollapseChange);
    this.element.removeEventListener("click", this.boundHandleClick);
  }

  handleCollapseChange(event) {
    if (event.target.closest(".facet-limit")) {
      this.saveState();
    }
  }

  handleClick(event) {
    if (
      event.target.closest(
        ".facet-limit .collapse-toggle, .facet-limit button[data-bs-toggle='collapse'], .facet-limit button[data-toggle='collapse']"
      )
    ) {
      setTimeout(() => this.saveState(), 350);
    }
  }

  expandAll(event) {
    if (event) event.preventDefault();
    const cards = this.element.querySelectorAll(".facet-limit");
    cards.forEach((card) => setFacetCardExpanded(card, true));

    try {
      localStorage.setItem("canadiana_facet_expand_state", "expand_all");
      const allIds = Array.from(cards).map(getFacetCardId).filter(Boolean);
      localStorage.setItem("canadiana_open_facet_ids", JSON.stringify(allIds));
    } catch (_e) {}
  }

  collapseAll(event) {
    if (event) event.preventDefault();
    const cards = this.element.querySelectorAll(".facet-limit");
    cards.forEach((card) => setFacetCardExpanded(card, false));

    try {
      localStorage.setItem("canadiana_facet_expand_state", "collapse_all");
      localStorage.setItem("canadiana_open_facet_ids", JSON.stringify([]));
    } catch (_e) {}
  }

  saveState() {
    const cards = Array.from(this.element.querySelectorAll(".facet-limit"));
    if (cards.length === 0) return;

    const openIds = [];
    cards.forEach((card) => {
      const collapseEl = card.querySelector(".facet-content.collapse");
      if (collapseEl && collapseEl.classList.contains("show")) {
        const id = getFacetCardId(card);
        if (id) openIds.push(id);
      }
    });

    try {
      localStorage.setItem("canadiana_open_facet_ids", JSON.stringify(openIds));
      if (openIds.length === cards.length) {
        localStorage.setItem("canadiana_facet_expand_state", "expand_all");
      } else if (openIds.length === 0) {
        localStorage.setItem("canadiana_facet_expand_state", "collapse_all");
      } else {
        localStorage.setItem("canadiana_facet_expand_state", "custom");
      }
    } catch (_e) {}
  }

  restoreState() {
    const cards = this.element.querySelectorAll(".facet-limit");
    if (cards.length === 0) return;

    let state = null;
    let openIds = null;
    try {
      state = localStorage.getItem("canadiana_facet_expand_state");
      const rawIds = localStorage.getItem("canadiana_open_facet_ids");
      if (rawIds) openIds = JSON.parse(rawIds);
    } catch (_e) {}

    if (state === "expand_all") {
      cards.forEach((card) => setFacetCardExpanded(card, true));
    } else if (state === "collapse_all") {
      cards.forEach((card) => setFacetCardExpanded(card, false));
    } else if (Array.isArray(openIds)) {
      cards.forEach((card) => {
        const id = getFacetCardId(card);
        const shouldOpen = openIds.includes(id);
        setFacetCardExpanded(card, shouldOpen);
      });
    }
  }
}
