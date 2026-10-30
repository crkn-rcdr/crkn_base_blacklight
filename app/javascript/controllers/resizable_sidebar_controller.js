import { Controller } from "@hotwired/stimulus";

const WIDTH_STORAGE_KEY = "crkn_metadata_sidebar_width";
const FULLSCREEN_STORAGE_KEY = "crkn_metadata_fullscreen";

export default class extends Controller {
  connect() {
    this.wrapper = this.element.id === "document-togglable-content"
      ? this.element
      : this.element.querySelector("#document-togglable-content") || this.element;
    this.sidebar = this.wrapper.querySelector("#toggle-menu");
    this.handle = this.wrapper.querySelector(".metadata-resize-handle");
    this.fullscreenBtn = this.wrapper.querySelector("#metadata-fullscreen-toggle");

    this.isResizing = false;

    this.boundOnMouseMove = (e) => this.onMouseMove(e);
    this.boundOnMouseUp = () => this.onMouseUp();
    this.boundOnResize = () => this.restorePersistedMetadataSize();
    this.boundOnKeyDown = (e) => this.onKeyDown(e);

    if (this.handle) {
      this.handle.addEventListener("mousedown", (e) => this.onMouseDown(e));
      this.handle.addEventListener("dblclick", () => this.onDoubleClick());
    }

    if (this.fullscreenBtn) {
      this.fullscreenBtn.addEventListener("click", (e) => this.toggleFullscreen(e));
    }

    this.wrapper.addEventListener("click", (e) => this.handleCollapsibleClick(e));
    window.addEventListener("resize", this.boundOnResize);
    document.addEventListener("keydown", this.boundOnKeyDown);

    this.restorePersistedMetadataSize();
  }

  disconnect() {
    window.removeEventListener("resize", this.boundOnResize);
    document.removeEventListener("keydown", this.boundOnKeyDown);
    document.removeEventListener("mousemove", this.boundOnMouseMove);
    document.removeEventListener("mouseup", this.boundOnMouseUp);
  }

  applySidebarWidthPx(widthPx) {
    if (!this.sidebar || !this.wrapper) return null;
    if (window.innerWidth < 992) {
      this.sidebar.style.width = "";
      this.sidebar.style.maxWidth = "";
      this.sidebar.style.minWidth = "";
      return null;
    }
    const wrapperW = this.wrapper.getBoundingClientRect().width || window.innerWidth;
    const maxW = Math.max(340, Math.min(760, Math.floor(wrapperW * 0.65)));
    const clamped = Math.round(Math.max(240, Math.min(maxW, widthPx)));
    this.sidebar.style.width = clamped + "px";
    this.sidebar.style.maxWidth = clamped + "px";
    this.sidebar.style.minWidth = clamped + "px";
    return clamped;
  }

  setFullscreenState(nextExpanded, persist) {
    if (!this.wrapper || !this.fullscreenBtn) return;

    this.wrapper.classList.toggle("metadata-fullscreen-active", nextExpanded);
    this.fullscreenBtn.setAttribute("aria-expanded", String(nextExpanded));

    const nextLabel = nextExpanded
      ? this.fullscreenBtn.getAttribute("data-collapse-label") || "Exit full screen metadata"
      : this.fullscreenBtn.getAttribute("data-expand-label") || "Expand metadata record";
    this.fullscreenBtn.setAttribute("title", nextLabel);
    this.fullscreenBtn.setAttribute("aria-label", nextLabel);

    const icon = this.fullscreenBtn.querySelector("i.bi");
    if (icon) {
      icon.className = nextExpanded ? "bi bi-fullscreen-exit" : "bi bi-arrows-fullscreen";
    }

    if (persist) {
      try {
        localStorage.setItem(FULLSCREEN_STORAGE_KEY, nextExpanded ? "1" : "0");
      } catch (_e) {}
    }
  }

  toggleFullscreen(e) {
    if (e) e.preventDefault();
    const isExpanded = this.fullscreenBtn?.getAttribute("aria-expanded") === "true";
    this.setFullscreenState(!isExpanded, true);
  }

  restorePersistedMetadataSize() {
    if (!this.sidebar || !this.wrapper) return;

    try {
      const savedW = parseInt(localStorage.getItem(WIDTH_STORAGE_KEY) || "", 10);
      if (Number.isFinite(savedW) && savedW >= 240) {
        this.applySidebarWidthPx(savedW);
      }
      const isFullscreenBtnVisible =
        this.fullscreenBtn && window.getComputedStyle(this.fullscreenBtn).display !== "none";
      const savedFullscreen =
        isFullscreenBtnVisible && localStorage.getItem(FULLSCREEN_STORAGE_KEY) === "1";
      if (savedFullscreen) {
        this.setFullscreenState(true, false);
      }
    } catch (_e) {}
  }

  onMouseDown(e) {
    e.preventDefault();
    this.isResizing = true;
    this.handle?.classList.add("is-dragging");
    document.body.classList.add("metadata-resizing");

    document.addEventListener("mousemove", this.boundOnMouseMove);
    document.addEventListener("mouseup", this.boundOnMouseUp);
  }

  onMouseMove(e) {
    if (!this.isResizing || !this.sidebar || !this.wrapper) return;
    const rect = this.sidebar.getBoundingClientRect();
    const applied = this.applySidebarWidthPx(e.clientX - rect.left);
    if (applied) {
      try {
        localStorage.setItem(WIDTH_STORAGE_KEY, String(applied));
      } catch (_e) {}
    }
  }

  onMouseUp() {
    if (!this.isResizing) return;
    this.isResizing = false;
    document.body.classList.remove("metadata-resizing");
    this.handle?.classList.remove("is-dragging");

    document.removeEventListener("mousemove", this.boundOnMouseMove);
    document.removeEventListener("mouseup", this.boundOnMouseUp);
  }

  onDoubleClick() {
    if (!this.sidebar) return;
    this.sidebar.style.width = "";
    this.sidebar.style.maxWidth = "";
    this.sidebar.style.minWidth = "";
    try {
      localStorage.removeItem(WIDTH_STORAGE_KEY);
    } catch (_e) {}
  }

  onKeyDown(e) {
    if (e.key === "Escape") {
      if (this.wrapper?.classList.contains("metadata-fullscreen-active")) {
        this.setFullscreenState(false, true);
      }
    }

    if (e.target === this.handle && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
      e.preventDefault();
      const currentW = this.sidebar.getBoundingClientRect().width;
      const delta = e.key === "ArrowRight" ? 24 : -24;
      const applied = this.applySidebarWidthPx(currentW + delta);
      if (applied) {
        try {
          localStorage.setItem(WIDTH_STORAGE_KEY, String(applied));
        } catch (_e) {}
      }
    }
  }

  handleCollapsibleClick(e) {
    const toggleBtn = e.target.closest(".metadata-collapsible__toggle");
    if (!toggleBtn) return;
    e.preventDefault();

    const container = toggleBtn.closest(".metadata-collapsible");
    if (!container) return;

    const preview = container.querySelector(".metadata-collapsible__preview");
    const full = container.querySelector(".metadata-collapsible__full");
    const label = toggleBtn.querySelector(".metadata-collapsible__toggle-label");
    const icon = toggleBtn.querySelector("i.bi");
    const isExpanded = toggleBtn.getAttribute("aria-expanded") === "true";
    const nextExpanded = !isExpanded;

    toggleBtn.setAttribute("aria-expanded", String(nextExpanded));
    container.classList.toggle("is-expanded", nextExpanded);
    if (preview) preview.hidden = nextExpanded;
    if (full) full.hidden = !nextExpanded;
    if (label) {
      label.textContent = nextExpanded
        ? toggleBtn.getAttribute("data-show-less-text") || "Show less"
        : toggleBtn.getAttribute("data-show-more-text") || "Show more";
    }
    if (icon) {
      icon.className = nextExpanded ? "bi bi-chevron-up" : "bi bi-chevron-down";
    }
  }
}
