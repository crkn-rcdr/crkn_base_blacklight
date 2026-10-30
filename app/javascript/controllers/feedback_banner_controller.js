import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "feedback_banner_closed";

export default class extends Controller {
  connect() {
    try {
      if (sessionStorage.getItem(STORAGE_KEY) === "1") {
        this.element.remove();
      } else {
        document.body.classList.add("has-feedback-banner");
      }
    } catch (_e) {}
  }

  close() {
    this.element.remove();
    document.body.classList.remove("has-feedback-banner");
    try {
      sessionStorage.setItem(STORAGE_KEY, "1");
    } catch (_e) {}
  }
}
