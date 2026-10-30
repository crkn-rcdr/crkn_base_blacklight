import { Controller } from "@hotwired/stimulus";

/**
 * Download Status Controller
 * 
 * Manages download availability polling and button state updates.
 * Replaces the inline script from document_component.html.erb.
 */
export default class extends Controller {
  connect() {
    this.toolbar = this.element.id === "download-toolbar" 
      ? this.element 
      : this.element.querySelector("#download-toolbar") || this.element;

    if (!this.toolbar) return;

    this.docId = this.toolbar.dataset.docid;
    this.arkPath = this.toolbar.dataset.arkpath;

    this.fullBtn = this.element.querySelector("#btn-download-full");
    this.pageBtn = this.element.querySelector("#btn-download-page");
    this.pageImgBtn = this.element.querySelector("#btn-download-img");

    this.statusDisplay = this.element.querySelector("#download-status");
    this.statusText = this.statusDisplay?.querySelector(".download-status-text");
    this.statusSpinner = this.statusDisplay?.querySelector(".spinner-border");

    this.checkingText = "Checking download availability...";
    this.unavailableText = "Not available for this page.";
    this.pdfDisabledTooltip = "Searchable PDFs and text search are unavailable when no OCR (machine-readable text) exists.";
    this.imgDisabledTooltip = "Image download is unavailable for this page.";

    this.availabilityRun = 0;
    this.abortController = null;

    // Prevent click on disabled buttons
    this.preventDisabledClick = (e) => {
      const el = e.currentTarget;
      if (!el || el.classList.contains("disabled") || el.getAttribute("aria-disabled") === "true") {
        e.preventDefault();
      }
    };

    [this.fullBtn, this.pageBtn, this.pageImgBtn].forEach((btn) => {
      if (btn) btn.addEventListener("click", this.preventDisabledClick);
    });

    // Start initial availability check
    this.updateForCurrentPage();

    // Listen for navigation events that may change the query string (e.g. Mirador page change)
    this.onLocationChange = () => this.updateForCurrentPage();
    window.addEventListener("popstate", this.onLocationChange);
    window.addEventListener("hashchange", this.onLocationChange);

    // Poll for pageNum changes (viewer navigation using pushState/replaceState)
    this.lastSearch = window.location.search;
    this.searchPollInterval = setInterval(() => {
      if (window.location.search !== this.lastSearch) {
        this.lastSearch = window.location.search;
        this.onLocationChange();
      }
    }, 750);
  }

  disconnect() {
    if (this.searchPollInterval) {
      clearInterval(this.searchPollInterval);
      this.searchPollInterval = null;
    }
    if (this.onLocationChange) {
      window.removeEventListener("popstate", this.onLocationChange);
      window.removeEventListener("hashchange", this.onLocationChange);
    }
    if (this.abortController) {
      this.abortController.abort();
    }
    [this.fullBtn, this.pageBtn, this.pageImgBtn].forEach((btn) => {
      if (btn && this.preventDisabledClick) {
        btn.removeEventListener("click", this.preventDisabledClick);
      }
    });
  }

  currentPageNum() {
    const p = parseInt(new URLSearchParams(window.location.search).get("pageNum") || "1", 10);
    return Number.isFinite(p) && p > 0 ? p : 1;
  }

  encodedArkPath() {
    return String(this.arkPath || "")
      .split("/")
      .map(encodeURIComponent)
      .join("/");
  }

  downloadDataUrl() {
    const params = new URLSearchParams({
      pageNum: String(this.currentPageNum()),
      _: String(Date.now()),
    });
    return `/dl/${encodeURIComponent(this.docId)}/${this.encodedArkPath()}?${params.toString()}`;
  }

  disableLink(el, tooltip) {
    if (!el) return;
    el.classList.add("disabled");
    el.setAttribute("aria-disabled", "true");
    el.removeAttribute("href");
    el.removeAttribute("download");
    if (tooltip) {
      el.setAttribute("title", tooltip);
      const label = el.querySelector(".download-label")?.textContent || "";
      el.setAttribute("aria-label", `${label}: ${tooltip}`.trim());
      el.querySelectorAll("*").forEach((child) => child.setAttribute("title", tooltip));
    }
  }

  enableLink(el, href) {
    if (!el || !href) return;
    el.href = href;
    el.classList.remove("disabled");
    el.removeAttribute("aria-disabled");
    el.removeAttribute("title");
    el.removeAttribute("aria-label");
    el.querySelectorAll("*").forEach((child) => child.removeAttribute("title"));
  }

  setLinkState(el, href, tooltip) {
    if (!el || !href) return this.disableLink(el, tooltip);
    this.enableLink(el, href);
  }

  setStatus(message, loading) {
    if (this.statusText) this.statusText.textContent = message || "";
    if (this.statusSpinner) this.statusSpinner.hidden = !loading;
  }

  showFinalStatus() {
    const anyEnabled = [this.fullBtn, this.pageBtn, this.pageImgBtn].some(
      (el) => el && el.getAttribute("href") && !el.classList.contains("disabled")
    );
    this.setStatus(anyEnabled ? "" : this.unavailableText, false);
  }

  async updateForCurrentPage() {
    if (!this.docId || !this.arkPath) return;

    const run = ++this.availabilityRun;

    this.setStatus(this.checkingText, true);
    this.disableLink(this.fullBtn, this.pdfDisabledTooltip);
    this.disableLink(this.pageBtn, this.pdfDisabledTooltip);
    this.disableLink(this.pageImgBtn, this.imgDisabledTooltip);

    if (this.abortController) {
      this.abortController.abort();
    }
    this.abortController = new AbortController();

    try {
      const response = await fetch(this.downloadDataUrl(), {
        credentials: "same-origin",
        cache: "no-store",
        signal: this.abortController.signal,
      });

      if (!response.ok) throw new Error(`Download metadata failed: ${response.status}`);
      const data = await response.json();

      if (run !== this.availabilityRun) return;

      this.setLinkState(this.fullBtn, data?.docPdfUri, this.pdfDisabledTooltip);
      this.setLinkState(this.pageBtn, data?.pagePdfUri, this.pdfDisabledTooltip);
      this.setLinkState(this.pageImgBtn, data?.pageImgUri, this.imgDisabledTooltip);
      this.showFinalStatus();
    } catch (_error) {
      if (run !== this.availabilityRun) return;
      this.disableLink(this.fullBtn, this.pdfDisabledTooltip);
      this.disableLink(this.pageBtn, this.pdfDisabledTooltip);
      this.disableLink(this.pageImgBtn, this.imgDisabledTooltip);
      this.showFinalStatus();
    }
  }
}
