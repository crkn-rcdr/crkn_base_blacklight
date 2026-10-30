import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["data", "primarySlide", "secondarySlide", "featureLink", "featureLinkText"];
  static values = {
    exploreLabel: { type: String, default: "Explore" }
  };

  connect() {
    this.boundVisibilityChange = this.handleVisibilityChange.bind(this);
    document.addEventListener("visibilitychange", this.boundVisibilityChange);

    this.reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    this.slides = this.loadSlides();
    if (!this.slides.length) return;

    this.activeSlideEl = this.hasPrimarySlideTarget
      ? this.primarySlideTarget
      : this.element.querySelector('[data-canadiana-feature-slide="primary"]');
    this.inactiveSlideEl = this.hasSecondarySlideTarget
      ? this.secondarySlideTarget
      : this.element.querySelector('[data-canadiana-feature-slide="secondary"]');
    this.linkEl = this.hasFeatureLinkTarget
      ? this.featureLinkTarget
      : this.element.querySelector("[data-canadiana-feature-link]");
    this.linkTextEl = this.hasFeatureLinkTextTarget
      ? this.featureLinkTextTarget
      : this.element.querySelector("[data-canadiana-feature-link-text]");

    this.currentIndex = 0;
    this.intervalId = null;

    this.showSlide(0, true);
    this.start();
  }

  disconnect() {
    this.stop();
    document.removeEventListener("visibilitychange", this.boundVisibilityChange);
  }

  loadSlides() {
    const dataEl = this.hasDataTarget
      ? this.dataTarget
      : this.element.querySelector("[data-canadiana-feature-data]");
    if (!dataEl) return [];

    try {
      const parsed = JSON.parse(dataEl.textContent || "[]");
      return Array.isArray(parsed)
        ? parsed.filter(
            (slide) =>
              slide &&
              typeof slide.image_url === "string" &&
              slide.image_url.length > 0 &&
              typeof slide.url === "string" &&
              slide.url.length > 0
          )
        : [];
    } catch (_error) {
      return [];
    }
  }

  applySlide(slideEl, slide) {
    if (slideEl && slide && slide.image_url) {
      slideEl.style.backgroundImage = `url("${slide.image_url}")`;
    }
  }

  updateLink(slide) {
    if (!this.linkEl) return;
    const exploreLabel = this.exploreLabelValue || this.element.dataset.exploreLabel || "Explore";
    const buttonText = slide.label || exploreLabel;
    const ariaLabel = slide.label ? `${exploreLabel}: ${slide.label}` : exploreLabel;

    this.linkEl.href = slide.url;
    this.linkEl.title = buttonText;
    this.linkEl.setAttribute("aria-label", ariaLabel);
    if (this.linkTextEl) {
      this.linkTextEl.textContent = buttonText;
    }
  }

  showSlide(nextIndex, immediate = false) {
    const slide = this.slides[nextIndex];
    if (!slide) return;

    this.currentIndex = nextIndex;
    this.updateLink(slide);

    if (immediate) {
      this.applySlide(this.activeSlideEl, slide);
      if (this.activeSlideEl) this.activeSlideEl.classList.add("is-active");
      if (this.inactiveSlideEl) this.inactiveSlideEl.classList.remove("is-active");
      return;
    }

    this.applySlide(this.inactiveSlideEl, slide);
    if (this.inactiveSlideEl) this.inactiveSlideEl.classList.add("is-active");
    if (this.activeSlideEl) this.activeSlideEl.classList.remove("is-active");
    [this.activeSlideEl, this.inactiveSlideEl] = [this.inactiveSlideEl, this.activeSlideEl];
  }

  start() {
    if (this.intervalId !== null || this.slides.length < 2 || this.reduceMotion) return;
    this.intervalId = window.setInterval(() => {
      if (document.hidden) return;
      const nextIndex = (this.currentIndex + 1) % this.slides.length;
      this.showSlide(nextIndex);
    }, 6500);
  }

  stop() {
    if (this.intervalId === null) return;
    window.clearInterval(this.intervalId);
    this.intervalId = null;
  }

  handleVisibilityChange() {
    if (document.hidden) {
      this.stop();
    } else {
      this.start();
    }
  }
}
