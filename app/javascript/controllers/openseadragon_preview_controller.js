import { Controller } from "@hotwired/stimulus";

let globalActiveViewerState = null;

export default class extends Controller {
  static targets = ["viewer", "activate"];

  connect() {
    this.deactivateHandler = (e) => {
      if (!globalActiveViewerState) return;
      if (globalActiveViewerState.container.contains(e.target)) return;
      this.deactivateViewer(globalActiveViewerState);
      globalActiveViewerState = null;
    };

    this.keydownHandler = (e) => {
      if (e.key !== "Escape" || !globalActiveViewerState) return;
      const overlay = globalActiveViewerState.overlay;
      this.deactivateViewer(globalActiveViewerState);
      globalActiveViewerState = null;
      if (overlay) overlay.focus();
    };

    document.addEventListener("pointerdown", this.deactivateHandler, true);
    document.addEventListener("keydown", this.keydownHandler);

    this.initViewers();
  }

  disconnect() {
    document.removeEventListener("pointerdown", this.deactivateHandler, true);
    document.removeEventListener("keydown", this.keydownHandler);
    if (globalActiveViewerState && this.element.contains(globalActiveViewerState.container)) {
      this.deactivateViewer(globalActiveViewerState);
      globalActiveViewerState = null;
    }
  }

  deactivateViewer(state) {
    if (!state) return;
    const { viewer, container, overlay } = state;
    try {
      viewer.setMouseNavEnabled(false);
      if (viewer.gestureSettingsMouse) {
        viewer.gestureSettingsMouse.scrollToZoom = false;
      }
    } catch (_error) {}
    container.classList.remove("is-active");
    container.removeAttribute("data-lenis-prevent");
    const card = container.closest(".card, .home-featured-card");
    if (card) {
      card.classList.remove("is-active");
      card.removeAttribute("data-lenis-prevent");
    }
    if (overlay) {
      overlay.hidden = false;
      overlay.setAttribute("aria-pressed", "false");
    }
  }

  activateViewer(viewer, container, overlay) {
    if (globalActiveViewerState && globalActiveViewerState.viewer !== viewer) {
      this.deactivateViewer(globalActiveViewerState);
    }

    try {
      viewer.setMouseNavEnabled(true);
      if (viewer.gestureSettingsMouse) {
        viewer.gestureSettingsMouse.scrollToZoom = true;
      }
    } catch (_error) {}
    container.classList.add("is-active");
    container.setAttribute("data-lenis-prevent", "true");
    const card = container.closest(".card, .home-featured-card");
    if (card) {
      card.classList.add("is-active");
      card.setAttribute("data-lenis-prevent", "true");
    }
    if (overlay) {
      overlay.hidden = true;
      overlay.setAttribute("aria-pressed", "true");
    }
    globalActiveViewerState = { viewer, container, overlay };
  }

  manifestCanvases(manifest) {
    if (Array.isArray(manifest?.items) && manifest.items.length) return manifest.items;
    const v2 = manifest?.sequences?.[0]?.canvases;
    return Array.isArray(v2) ? v2 : [];
  }

  canvasSize(canvas) {
    const directWidth = Number(canvas?.width || canvas?.["@width"]);
    const directHeight = Number(canvas?.height || canvas?.["@height"]);
    if (directWidth > 0 && directHeight > 0) return { width: directWidth, height: directHeight };

    const body = canvas?.items?.[0]?.items?.[0]?.body || canvas?.images?.[0]?.resource;
    const bodyWidth = Number(body?.width || body?.["@width"]);
    const bodyHeight = Number(body?.height || body?.["@height"]);
    if (bodyWidth > 0 && bodyHeight > 0) return { width: bodyWidth, height: bodyHeight };

    return null;
  }

  initViewers() {
    const viewerContainers = this.element.matches?.(".featured-item__viewer[data-ark-id], .collection-item__viewer[data-ark-id]")
      ? [this.element]
      : Array.from(this.element.querySelectorAll(".featured-item__viewer[data-ark-id], .collection-item__viewer[data-ark-id]"));

    viewerContainers.forEach((container) => {
      const arkId = (container.dataset.arkId || "").trim();
      if (!arkId || container.dataset.osdReady === "1") return;
      container.dataset.osdReady = "1";

      const overlay = container.querySelector(".featured-item__activate, .collection-item__activate");

      (async () => {
        const manifestBase =
          document.querySelector('meta[name="iiif-manifest-base"]')?.getAttribute("content")?.replace(/\/+$/, "") ||
          "https://www-iiif-pres.canadiana.ca/manifest";
        const imageBase =
          document.querySelector('meta[name="iiif-image-base"]')?.getAttribute("content")?.replace(/\/+$/, "") ||
          "https://image-tor.canadiana.ca/iiif/2";
        const manifestUrl = `${manifestBase}/${arkId}`;

        try {
          const response = await fetch(manifestUrl);
          const manifest = await response.json();
          const canvases = this.manifestCanvases(manifest);
          const requestedStartPage = Number(container.dataset.startPage || "1");
          const startPageIndex = Number.isFinite(requestedStartPage)
            ? Math.max(Math.floor(requestedStartPage), 1) - 1
            : 0;
          const boundedCanvasIndex = Math.min(startPageIndex, Math.max(canvases.length - 1, 0));
          const ratioCanvas = canvases[boundedCanvasIndex] || canvases[0];
          const size = this.canvasSize(ratioCanvas);
          if (size && container.classList.contains("featured-item__viewer")) {
            const ratio = size.width / size.height;
            container.dataset.ratio = String(ratio);
            container.style.aspectRatio = `${size.width} / ${size.height}`;
          }

          const tileSources = canvases
            .map((canvas) => {
              const service =
                canvas?.items?.[0]?.items?.[0]?.body?.service ||
                canvas?.images?.[0]?.resource?.service;
              const serviceItem = Array.isArray(service) ? service[0] : service;
              const serviceId = serviceItem?.["@id"] || serviceItem?.id;
              if (serviceId) {
                return `${serviceId.replace(/\/+$/, "")}/info.json`;
              }
              const canvasId = String(canvas.id || canvas["@id"] || "");
              const parts = canvasId.split("/");
              const lastTwoParts = parts.slice(-2).join("/");
              return `${imageBase}/${encodeURIComponent(lastTwoParts)}/info.json`;
            })
            .filter(Boolean);

          const boundedStartPage = Math.min(startPageIndex, Math.max(tileSources.length - 1, 0));

          let osd = typeof OpenSeadragon !== "undefined" ? OpenSeadragon : window.OpenSeadragon;
          if (!osd) {
            for (let i = 0; i < 30; i++) {
              await new Promise((r) => setTimeout(r, 100));
              osd = typeof OpenSeadragon !== "undefined" ? OpenSeadragon : window.OpenSeadragon;
              if (osd) break;
            }
          }

          if (!tileSources.length || !osd) {
            if (overlay) overlay.hidden = true;
            return;
          }

          const viewer = osd({
            element: container,
            prefixUrl: "/assets/",
            sequenceMode: true,
            tileSources: tileSources,
            immediateRender: true,
            showReferenceStrip: false,
            showHomeControl: false,
            showZoomControl: false,
            showFullPageControl: false,
            initialPage: boundedStartPage,
            defaultZoomLevel: 1.1,
            gestureSettingsMouse: {
              scrollToZoom: false,
            },
          });

          if (!viewer) return;
          if (boundedStartPage > 0) {
            viewer.addOnceHandler("open", () => viewer.goToPage(boundedStartPage));
          }

          viewer.addHandler("canvas-scroll", (event) => {
            if (!container.classList.contains("is-active")) return;
            if (event.originalEvent) {
              if (typeof event.originalEvent.stopPropagation === "function") {
                event.originalEvent.stopPropagation();
              }
              if (typeof event.originalEvent.preventDefault === "function") {
                event.originalEvent.preventDefault();
              }
            }
            event.preventDefault = true;
          });

          container.addEventListener(
            "wheel",
            (event) => {
              if (container.classList.contains("is-active")) {
                event.stopPropagation();
                event.preventDefault();
              }
            },
            { passive: false }
          );

          viewer.setMouseNavEnabled(false);
          container.classList.remove("is-active");
          container.removeAttribute("data-lenis-prevent");

          if (overlay) {
            overlay.hidden = false;
            overlay.setAttribute("aria-pressed", "false");
            overlay.addEventListener("click", (event) => {
              event.preventDefault();
              event.stopPropagation();
              this.activateViewer(viewer, container, overlay);
            });
          }

          container.addEventListener("pointerdown", (event) => {
            if (container.classList.contains("is-active")) return;
            if (overlay && overlay.contains(event.target)) return;
            this.activateViewer(viewer, container, overlay);
          });

          container.addEventListener("keydown", (event) => {
            if (container.classList.contains("is-active")) return;
            if (event.key === "Enter" || event.key === " ") {
              event.preventDefault();
              this.activateViewer(viewer, container, overlay);
            }
          });
        } catch (error) {
          console.error("Failed to load manifest or initialize OpenSeadragon for", container.id, error);
          if (overlay) overlay.hidden = true;
        }
      })();
    });
  }
}
