import { Controller } from "@hotwired/stimulus";

/**
 * Copy Link Controller
 * 
 * Handles copying the IIIF manifest URL to clipboard when the copy button
 * is clicked, displaying confirmation feedback directly inside the button
 * for an extended duration (6 seconds).
 * 
 * Data attributes:
 *   - [data-controller="copy-link"]
 *   - Button: .copy-link-btn
 *   - Manifest URL link: #iiif-manifest-url
 *   - Feedback element: #iiif-copy-feedback
 */
export default class extends Controller {
  static targets = ["button", "feedback"];

  connect() {
    this.button = this.element.querySelector(".copy-link-btn");
    this.manifestLink = this.element.querySelector("#iiif-manifest-url");

    if (this.button) {
      this.originalButtonHtml = this.button.innerHTML;
      this.boundCopyClick = (e) => this.handleCopyClick(e);
      this.button.addEventListener("click", this.boundCopyClick);
    }
  }

  disconnect() {
    if (this.resetTimeout) {
      clearTimeout(this.resetTimeout);
      this.resetTimeout = null;
    }
    if (this.button && this.boundCopyClick) {
      this.button.removeEventListener("click", this.boundCopyClick);
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

    const successMessage =
      this.button?.dataset?.copiedText || "Copied to clipboard!";

    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(url);
        this.showFeedback("success", successMessage);
      } else {
        this.copyTextFallback(url);
        this.showFeedback("success", successMessage);
      }
    } catch (err) {
      console.error("Failed to copy:", err);
      try {
        this.copyTextFallback(url);
        this.showFeedback("success", successMessage);
      } catch (fallbackErr) {
        console.error("Fallback copy also failed:", fallbackErr);
        this.showFeedback("error", "Failed to copy to clipboard");
      }
    }
  }

  copyTextFallback(text) {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    textarea.style.pointerEvents = "none";

    document.body.appendChild(textarea);

    try {
      textarea.select();
      textarea.setSelectionRange(0, 99999);
      const success = document.execCommand("copy");

      if (!success) {
        throw new Error("execCommand copy returned false");
      }
    } finally {
      document.body.removeChild(textarea);
    }
  }

  showFeedback(type, message) {
    if (!this.button) return;

    if (this.resetTimeout) {
      clearTimeout(this.resetTimeout);
    }

    const iconClass = type === "success" ? "bi-check2" : "bi-exclamation-circle";
    const textClass = type === "success" ? "text-success fw-semibold" : "text-danger";

    this.button.innerHTML = `
      <i class="bi ${iconClass} ${textClass}" aria-hidden="true"></i>
      <span id="iiif-copy-feedback" class="copy-feedback-${type} ${textClass}" aria-live="polite">${message}</span>
    `;

    if (type === "success") {
      this.button.classList.add("is-copied", "border-success");
      this.button.classList.remove("is-error", "border-danger");
    } else {
      this.button.classList.add("is-error", "border-danger");
      this.button.classList.remove("is-copied", "border-success");
    }

    // Auto-restore button after 6 seconds (show longer as requested)
    this.resetTimeout = setTimeout(() => {
      if (this.button && this.originalButtonHtml) {
        this.button.innerHTML = this.originalButtonHtml;
        this.button.classList.remove("is-copied", "is-error", "border-success", "border-danger");
      }
      this.resetTimeout = null;
    }, 6000);
  }
}
