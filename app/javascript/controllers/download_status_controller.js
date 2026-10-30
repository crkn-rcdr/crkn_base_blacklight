import { Controller } from "@hotwired/stimulus";

/**
 * Download Status Controller
 * 
 * Polls the download API endpoint to check if files are ready for download
 * and updates the UI with the current status.
 * 
 * Replaces inline script functions:
 *   - updateForCurrentPage()
 *   - handleVisibilityChange()
 *   - isArkPathReady()
 *   - Download polling interval (500ms)
 * 
 * Data attributes:
 *   - [data-controller="download-status"]
 *   - Toolbar: #download-toolbar[data-docid][data-arkpath]
 *   - Buttons: #btn-download-img, #btn-download-page, #btn-download-full
 *   - Status display: #download-status
 * 
 * Note: Actual download functionality is handled by the buttons' href
 * and the backend API. This controller only manages polling and UI state.
 */
export default class extends Controller {
  static values = {
    docId: String,
    arkPath: String,
    pollInterval: { type: Number, default: 500 },
    maxRetries: { type: Number, default: 60 }, // ~30 seconds at 500ms interval
  };

  connect() {
    this.toolbar = this.element.querySelector("#download-toolbar");
    if (!this.toolbar) return;

    this.docId = this.toolbar.dataset.docid;
    this.arkPath = this.toolbar.dataset.arkpath;

    this.statusDisplay = this.element.querySelector("#download-status");
    this.downloadButtons = this.element.querySelectorAll(
      "#btn-download-img, #btn-download-page, #btn-download-full"
    );

    this.pollRetryCount = 0;
    this.abortController = new AbortController();

    // Start polling
    this.startPolling();

    // Handle visibility changes - pause polling when tab not visible
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        this.stopPolling();
      } else {
        this.startPolling();
      }
    });

    // Clean up on disconnect
    this.cleanup = () => this.stopPolling();
  }

  disconnect() {
    this.stopPolling();
  }

  startPolling() {
    if (this.pollTimeout) return; // Already polling

    this.poll();
  }

  stopPolling() {
    if (this.pollTimeout) {
      clearTimeout(this.pollTimeout);
      this.pollTimeout = null;
    }
  }

  async poll() {
    if (!this.docId || !this.arkPath) {
      this.updateStatus("error", "Missing document or ark path");
      return;
    }

    try {
      // Check if files are ready
      const isReady = await this.checkDownloadStatus();

      if (isReady) {
        this.updateStatus("ready");
        this.enableDownloadButtons();
        this.stopPolling();
        return;
      }

      this.pollRetryCount++;

      if (this.pollRetryCount >= this.maxRetriesValue) {
        // Timeout reached - still show as checking but allow manual retry
        this.updateStatus(
          "timeout",
          "File generation taking longer than expected. Please try again."
        );
        this.disableDownloadButtons();
        return;
      }

      // Schedule next poll
      this.pollTimeout = setTimeout(() => this.poll(), this.pollIntervalValue);
    } catch (error) {
      console.error("Download status check failed:", error);
      this.updateStatus("error", "Failed to check download status");

      // Retry even on error
      this.pollRetryCount++;
      if (this.pollRetryCount < this.maxRetriesValue) {
        this.pollTimeout = setTimeout(() => this.poll(), this.pollIntervalValue);
      } else {
        this.stopPolling();
      }
    }
  }

  async checkDownloadStatus() {
    const endpoint = `/dl/${this.docId}/${this.arkPath}`;

    const response = await fetch(endpoint, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
      signal: this.abortController.signal,
      timeout: 7000,
    });

    if (!response.ok) {
      throw new Error(`Download check failed: ${response.statusText}`);
    }

    const data = await response.json();

    // Response format: { ready: boolean, message?: string }
    return data.ready === true;
  }

  updateStatus(state, message = null) {
    if (!this.statusDisplay) return;

    // Map states to user-friendly messages
    const messages = {
      ready: "✓ Files are ready for download",
      checking: "Checking file availability...",
      timeout: message || "File generation taking longer than expected",
      error: message || "Error checking file availability",
    };

    const msg = messages[state] || state;
    const spinnerHTML =
      state === "checking"
        ? '<span class="spinner-border spinner-border-sm me-1" role="status" aria-hidden="true"></span>'
        : state === "ready"
          ? '<i class="bi bi-check-circle me-1"></i>'
          : '<i class="bi bi-exclamation-circle me-1"></i>';

    this.statusDisplay.innerHTML = `${spinnerHTML}<span class="download-status-text">${msg}</span>`;
    this.statusDisplay.className = `text-muted small d-inline-flex align-items-center gap-1 status-${state}`;
  }

  enableDownloadButtons() {
    this.downloadButtons.forEach((button) => {
      button.classList.remove("disabled");
      button.removeAttribute("aria-disabled");
      button.removeAttribute("disabled");

      // Update title/tooltip
      const kind = button
        .querySelector(".download-kind")
        ?.textContent.toUpperCase();
      if (kind) {
        const tooltips = {
          IMG: "Download image",
          PAGE: "Download page as PDF",
          FULL: "Download full document as PDF",
        };
        button.title = tooltips[kind] || "Download";
      }
    });
  }

  disableDownloadButtons() {
    this.downloadButtons.forEach((button) => {
      button.classList.add("disabled");
      button.setAttribute("aria-disabled", "true");
      button.disabled = true;
      button.title = "Files not yet ready for download";
    });
  }
}
