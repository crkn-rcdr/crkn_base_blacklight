import { Controller } from "@hotwired/stimulus";

/**
 * Copy Link Controller
 * 
 * Handles copying the IIIF manifest URL to clipboard when the copy button
 * is clicked.
 * 
 * Replaces inline script function:
 *   - copyManifestUrl() (180+ LOC including fallback logic)
 * 
 * Data attributes:
 *   - [data-controller="copy-link"]
 *   - Button: .copy-link-btn
 *   - Manifest URL link: #iiif-manifest-url
 *   - Feedback display: #iiif-copy-feedback
 */
export default class extends Controller {
  static targets = ["button", "feedback"];

  connect() {
    this.button = this.element.querySelector(".copy-link-btn");
    this.manifestLink = this.element.querySelector("#iiif-manifest-url");
    this.feedback = this.element.querySelector("#iiif-copy-feedback");

    if (this.button && this.manifestLink) {
      this.button.addEventListener("click", (e) => this.handleCopyClick(e));
    }
  }

  async handleCopyClick(event) {
    event.preventDefault();

    if (!this.manifestLink) {
      this.showFeedback("error", "Manifest URL not found");
      return;
    }

    const url = this.manifestLink.href;
    if (!url) {
      this.showFeedback("error", "Manifest URL is empty");
      return;
    }

    try {
      // Try modern navigator.clipboard API first
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(url);
        this.showFeedback("success", "Copied to clipboard!");
      } else {
        // Fallback for older browsers or non-secure contexts
        this.copyTextFallback(url);
        this.showFeedback("success", "Copied to clipboard!");
      }
    } catch (err) {
      console.error("Failed to copy:", err);
      // Try fallback even if navigator.clipboard failed
      try {
        this.copyTextFallback(url);
        this.showFeedback("success", "Copied to clipboard!");
      } catch (fallbackErr) {
        console.error("Fallback copy also failed:", fallbackErr);
        this.showFeedback("error", "Failed to copy to clipboard");
      }
    }
  }

  copyTextFallback(text) {
    // Create a temporary textarea element
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    textarea.style.pointerEvents = "none";

    document.body.appendChild(textarea);

    try {
      textarea.select();
      textarea.setSelectionRange(0, 99999); // For mobile devices
      const success = document.execCommand("copy");

      if (!success) {
        throw new Error("execCommand copy returned false");
      }
    } finally {
      document.body.removeChild(textarea);
    }
  }

  showFeedback(type, message) {
    if (!this.feedback) return;

    // Clear existing feedback
    this.feedback.innerHTML = "";
    this.feedback.className =
      "visually-hidden text-muted small d-inline-flex align-items-center gap-1";

    // Add type-specific class and content
    const prefix =
      type === "success"
        ? "✓"
        : type === "error"
          ? "✗"
          : "ℹ";

    this.feedback.innerHTML = `<span class="copy-feedback-${type}">${prefix} ${message}</span>`;
    this.feedback.style.display = "inline-flex";
    this.feedback.classList.remove("visually-hidden");

    // Auto-hide after 3 seconds
    setTimeout(() => {
      this.feedback.classList.add("visually-hidden");
      this.feedback.innerHTML = "";
    }, 3000);
  }
}
