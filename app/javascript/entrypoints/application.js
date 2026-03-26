import Lenis from 'lenis'

// To see this message, add the following to the `<head>` section in your
// views/layouts/application.html.erb
//
//    <%= vite_client_tag %>
//    <%= vite_javascript_tag 'application' %>
console.log('Vite ⚡️ Rails')

// If using a TypeScript entrypoint file:
//     <%= vite_typescript_tag 'application' %>
//
// If you want to use .jsx or .tsx, add the extension:
//     <%= vite_javascript_tag 'application.jsx' %>

console.log('Visit the guide for more information: ', 'https://vite-ruby.netlify.app/guide/rails')

// Example: Load Rails libraries in Vite.
//
// import * as Turbo from '@hotwired/turbo'
// Turbo.start()
//
// import ActiveStorage from '@rails/activestorage'
// ActiveStorage.start()
//
// // Import all channels.
// const channels = import.meta.globEager('./**/*_channel.js')

// Example: Import a stylesheet in app/frontend/index.css
// import '~/index.css'
//import "../javascript/application"
console.log("mirador", Mirador)

let lenisInstance = null
let lenisRafStarted = false
let homeExhibitionLenisUnsubscribe = null
let homeExhibitionResizeBound = false

const rafLenis = (time) => {
  if (lenisInstance) {
    lenisInstance.raf(time)
  }
  window.requestAnimationFrame(rafLenis)
}

const initLenis = () => {
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    if (lenisInstance) {
      lenisInstance.destroy()
      lenisInstance = null
    }
    return
  }

  if (!lenisInstance) {
    lenisInstance = new Lenis({
      duration: 1.05,
      smoothWheel: true,
      smoothTouch: false
    })
  }

  if (!lenisRafStarted) {
    lenisRafStarted = true
    window.requestAnimationFrame(rafLenis)
  }
}

document.addEventListener('DOMContentLoaded', initLenis)
document.addEventListener('turbo:load', initLenis)

let activeHomeExhibitionCard = null
let homeExhibitionPreviewBehaviorInstalled = false

const setHomeExhibitionCardState = (card, isActive) => {
  if (!card) return

  const frame = card.querySelector('.home-exhibition-preview__frame')
  if (!frame) return

  card.classList.toggle('is-active', isActive)
  frame.classList.toggle('is-interactive', isActive)
  frame.dataset.exhibitionInteractive = isActive ? 'true' : 'false'
  frame.tabIndex = isActive ? 0 : -1
}

const deactivateHomeExhibitionCard = (card) => {
  if (!card) return
  setHomeExhibitionCardState(card, false)
  if (activeHomeExhibitionCard === card) activeHomeExhibitionCard = null
}

const activateHomeExhibitionCard = (card) => {
  if (!card) return
  if (activeHomeExhibitionCard && activeHomeExhibitionCard !== card) {
    deactivateHomeExhibitionCard(activeHomeExhibitionCard)
  }

  setHomeExhibitionCardState(card, true)
  activeHomeExhibitionCard = card
}

const scrollToHomeExhibitionCard = (card) => {
  if (!card) return
  card.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'start' })
}

const isDesktopHomeExhibitionLayout = () => window.matchMedia('(min-width: 993px)').matches

const getHomeExhibitionStageMetrics = (section) => {
  if (!section?.isConnected) return null

  const stage = section.querySelector('.home-exhibition-preview__stage')
  const pin = section.querySelector('.home-exhibition-preview__pin')
  const grid = section.querySelector('.home-exhibition-preview__grid')
  if (!stage || !pin || !grid) return null

  const maxScrollLeft = Math.max(0, grid.scrollWidth - grid.clientWidth)
  const pinTop = Number.parseFloat(window.getComputedStyle(pin).top) || 0
  const scrollSpan = Math.max(1, maxScrollLeft)

  return { stage, pin, grid, maxScrollLeft, pinTop, scrollSpan }
}

const layoutHomeExhibitionStage = (section) => {
  const metrics = getHomeExhibitionStageMetrics(section)
  if (!metrics) return null

  const { stage, pin, maxScrollLeft, pinTop, scrollSpan } = metrics

  if (!isDesktopHomeExhibitionLayout() || maxScrollLeft <= 0) {
    stage.style.removeProperty('height')
    pin.classList.remove('is-pinned')
    metrics.grid.scrollLeft = 0
    section.classList.remove('is-pinned')
    return metrics
  }

  stage.style.height = `${pin.offsetHeight + scrollSpan + pinTop}px`
  return metrics
}

const syncHomeExhibitionStage = (section, scrollY = window.scrollY) => {
  const metrics = layoutHomeExhibitionStage(section)
  if (!metrics) return

  const { stage, pin, grid, maxScrollLeft, pinTop, scrollSpan } = metrics
  if (!isDesktopHomeExhibitionLayout() || maxScrollLeft <= 0) return

  const stageTop = scrollY + stage.getBoundingClientRect().top
  const progressStart = stageTop - pinTop
  const rawProgress = scrollY - progressStart
  const clampedProgress = Math.max(0, Math.min(scrollSpan, rawProgress))
  const scrollProgress = clampedProgress / scrollSpan

  grid.scrollLeft = maxScrollLeft * scrollProgress

  const isPinned = clampedProgress > 0 && clampedProgress < scrollSpan
  pin.classList.toggle('is-pinned', isPinned)
  section.classList.toggle('is-pinned', isPinned)
}

const bindHomeExhibitionPreviewToLenis = (section, grid) => {
  if (homeExhibitionLenisUnsubscribe) {
    homeExhibitionLenisUnsubscribe()
    homeExhibitionLenisUnsubscribe = null
  }

  if (!section || !grid) return

  const sync = (scrollY = lenisInstance?.scroll ?? window.scrollY) => {
    syncHomeExhibitionStage(section, scrollY)
  }

  sync()

  if (lenisInstance) {
    homeExhibitionLenisUnsubscribe = lenisInstance.on('scroll', ({ scroll }) => {
      sync(scroll)
    })
  }

  if (!homeExhibitionResizeBound) {
    window.addEventListener('resize', () => {
      const previewSection = document.querySelector('.home-exhibition-preview')
      if (!previewSection) return

      layoutHomeExhibitionStage(previewSection)
      syncHomeExhibitionStage(previewSection, lenisInstance?.scroll ?? window.scrollY)
    })
    homeExhibitionResizeBound = true
  }
}

const resetHomeExhibitionPreview = () => {
  document
    .querySelectorAll('.home-exhibition-preview__card')
    .forEach((card) => deactivateHomeExhibitionCard(card))
}

const installHomeExhibitionPreviewBehavior = () => {
  const section = document.querySelector('.home-exhibition-preview')
  if (!section) return
  const grid = section.querySelector('.home-exhibition-preview__grid')

  section.querySelectorAll('.home-exhibition-preview__card').forEach((card) => {
    setHomeExhibitionCardState(card, false)
  })
  activeHomeExhibitionCard = null

  bindHomeExhibitionPreviewToLenis(section, grid)

  if (homeExhibitionPreviewBehaviorInstalled) return

  document.addEventListener('click', (event) => {
    const navButton = event.target.closest('.home-exhibition-preview__nav-button')
    if (navButton) {
      const currentCard = navButton.closest('.home-exhibition-preview__card')
      if (!currentCard) return

      const direction = navButton.dataset.exhibitNav
      const targetCard = direction === 'prev'
        ? currentCard.previousElementSibling
        : currentCard.nextElementSibling

      if (activeHomeExhibitionCard) {
        deactivateHomeExhibitionCard(activeHomeExhibitionCard)
      }

      if (targetCard?.classList.contains('home-exhibition-preview__card')) {
        const previewSection = document.querySelector('.home-exhibition-preview')
        const metrics = getHomeExhibitionStageMetrics(previewSection)

        if (previewSection && metrics && isDesktopHomeExhibitionLayout() && metrics.maxScrollLeft > 0) {
          const targetScrollLeft = targetCard.offsetLeft
          const clampedScrollLeft = Math.max(0, Math.min(metrics.maxScrollLeft, targetScrollLeft))
          const currentScrollY = lenisInstance?.scroll ?? window.scrollY
          const stageTop = currentScrollY + metrics.stage.getBoundingClientRect().top
          const progressStart = stageTop - metrics.pinTop
          const targetScrollY = progressStart + clampedScrollLeft

          if (lenisInstance) {
            lenisInstance.scrollTo(targetScrollY)
          } else {
            window.scrollTo({ top: targetScrollY, behavior: 'smooth' })
          }
        } else {
          scrollToHomeExhibitionCard(targetCard)
        }
      }
      return
    }

    const activateButton = event.target.closest('.home-exhibition-preview__activate')
    if (activateButton) {
      const card = activateButton.closest('.home-exhibition-preview__card')
      activateHomeExhibitionCard(card)
      return
    }

    if (activeHomeExhibitionCard && !event.target.closest('.home-exhibition-preview__card')) {
      deactivateHomeExhibitionCard(activeHomeExhibitionCard)
    }
  })

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && activeHomeExhibitionCard) {
      deactivateHomeExhibitionCard(activeHomeExhibitionCard)
    }
  })

  document.addEventListener('turbo:before-cache', () => {
    resetHomeExhibitionPreview()
    if (homeExhibitionLenisUnsubscribe) {
      homeExhibitionLenisUnsubscribe()
      homeExhibitionLenisUnsubscribe = null
    }

    const previewSection = document.querySelector('.home-exhibition-preview')
    if (previewSection) {
      const metrics = getHomeExhibitionStageMetrics(previewSection)
      metrics?.stage.style.removeProperty('height')
      metrics?.pin.classList.remove('is-pinned')
      previewSection.classList.remove('is-pinned')
    }
  })
  homeExhibitionPreviewBehaviorInstalled = true
}

document.addEventListener('DOMContentLoaded', installHomeExhibitionPreviewBehavior)
document.addEventListener('turbo:load', installHomeExhibitionPreviewBehavior)

if (document.readyState !== 'loading') {
  installHomeExhibitionPreviewBehavior()
}

let pageViewer = document.getElementById("my-mirador")
if(pageViewer) {
    let language = document.documentElement.lang || "en";
    const workspaceLabel = language.startsWith('fr') ? 'Espace de travail' : 'Workspace';

    const demoteMiradorMainLandmark = () => {
      const nestedMain = pageViewer.querySelector('main.mirador-viewer');
      if (!nestedMain) return;

      const replacement = document.createElement('div');
      Array.from(nestedMain.attributes).forEach(({ name, value }) => {
        replacement.setAttribute(name, value);
      });

      replacement.removeAttribute('role');
      replacement.setAttribute('role', 'region');
      if (!replacement.hasAttribute('aria-label') && !replacement.hasAttribute('aria-labelledby')) {
        replacement.setAttribute('aria-label', workspaceLabel);
      }

      while (nestedMain.firstChild) {
        replacement.appendChild(nestedMain.firstChild);
      }
      nestedMain.replaceWith(replacement);
    };

    const documentId = pageViewer.getAttribute("data-docid")
    let contentSearch = {}
    //let canvasIndex = 0
    const params = new URLSearchParams(window.location.search)
    //if(params.has("pageNum")) canvasIndex = parseInt(params.get("pageNum")-1)
    if(params.has("q")) contentSearch = {  query: params.get("q") }
    const manifestBase = document.querySelector('meta[name="iiif-manifest-base"]')?.content || "https://crkn-iiif-api.azurewebsites.net/manifest";
    let normalizedBase = manifestBase.endsWith('/') ? manifestBase : manifestBase + '/';
    let manifest = documentId.replace("https://n2t.net/ark:/", normalizedBase)
    const manifestList = {} 
    manifestList[manifest] = { "provider": "Canadian Research Knowledge Network" }
    console.log("Mirador", Mirador)
    let mconfig = {
        id: "my-mirador",
        manifests: manifestList,
        windows: [
        {
            manifestId: manifest,
            //view: 'single',
            //canvasIndex,
            contentSearch
        }],
        view: "catalogueView",
        selectedTheme: 'light', // light | dark
        language,
        window: {

            imageToolsOpen: false,
    
            //global window defaults
    
            allowClose: false, // Configure if windows can be closed or not
    
            allowFullscreen: true, // Configure to show a "fullscreen" button in the WindowTopBar
    
            allowMaximize: false, // Configure if windows can be maximized or not
    
            allowTopMenuButton: true, // Configure if window view and thumbnail display menu are visible or not
    
            allowWindowSideBar: false, // Configure if side bar menu is visible or not
    
            authNewWindowCenter: "parent", // Configure how to center a new window created by the authentication flow. Options: parent, screen
    
            sideBarPanel: "info", // Configure which sidebar is selected by default. Options: info, attribution, canvas, annotations, search
    
            defaultSidebarPanelHeight: 201, // Configure default sidebar height in pixels
    
            defaultSidebarPanelWidth: 235, // Configure default sidebar width in pixels
    
            defaultView: "single", // Configure which viewing mode (e.g. single, book, gallery) for windows to be opened in
    
            forceDrawAnnotations: true,
    
            hideWindowTitle: true, // Configure if the window title is shown in the window title bar or not
    
            highlightAllAnnotations: false, // Configure whether to display annotations on the canvas by default
    
            showLocalePicker: false, // Configure locale picker for multi-lingual metadata
    
            sideBarOpen:  false, // Configure if the sidebar (and its content panel) is open by default
    
            switchCanvasOnSearch: true, // Configure if Mirador should automatically switch to the canvas of the first search result
    
            panels: {
    
              // Configure which panels are visible in WindowSideBarButtons
    
              info: true,
    
              attribution: false,
    
              canvas: true, // table of contents
    
              annotations: false,
    
              search: false,
    
              layers: false
    
            },
    
            views: [
    
              { key: "single", behaviors: ["individuals"] },
    
              { key: "book", behaviors: ["paged"] },
    
              { key: "scroll", behaviors: ["continuous"] }
    
            ],
    
            elastic: {
    
              height: 400,
    
              width: 480
    
            }
    
          },
          osdConfig: {
            prefixUrl: "/assets/",
            // Default config used for OpenSeadragon
            showNavigationControl: 1,
            /**
             * fullpage_rest.png:1   GET http://localhost:3000/images/fullpage_rest.png 404 (Not Found)
                fullpage_pressed.png:1   GET http://localhost:3000/images/fullpage_pressed.png 404 (Not Found)
                fullpage_grouphover.png:1   GET http://localhost:3000/images/fullpage_grouphover.png 404 (Not Found)
            zoomin
            zoomout
            home
                */
          },
          workspace: {
    
            draggingEnabled: false,
    
            allowNewWindows: true,
    
            isWorkspaceAddVisible: false, // Catalog/Workspace add window feature visible by default
    
            exposeModeOn: false, // unused?
    
            height: 5000, // height of the elastic mode's virtual canvas
    
            showZoomControls: false, // Configure if zoom controls should be displayed by default
    
            type: "mosaic", // Which workspace type to load by default. Other possible values are "elastic". If "mosaic" or "elastic" are not selected no worksapce type will be used.
    
            viewportPosition: {
    
              // center coordinates for the elastic mode workspace
    
              x: 0,
    
              y: 0
    
            },
    
            width: 5000 // width of the elastic mode's virtual canvas
    
          },
    
          workspaceControlPanel: {
    
            enabled: false // Configure if the control panel should be rendered.  Useful if you want to lock the viewer down to only the configured manifests
    
          },
    }
    let miradorViewer = Mirador.viewer(mconfig);
    console.log("miradorViewer", miradorViewer)

    demoteMiradorMainLandmark();
    const miradorLandmarkObserver = new MutationObserver(() => {
      demoteMiradorMainLandmark();
    });
    miradorLandmarkObserver.observe(pageViewer, { childList: true, subtree: true });
    window.addEventListener('beforeunload', () => miradorLandmarkObserver.disconnect(), { once: true });

    miradorViewer.store.subscribe((e) => {
      console.log("m?", e)
    })
}
import "bootstrap-icons/font/bootstrap-icons.css";
import BlacklightRangeLimit from 'blacklight-range-limit';
//Blacklight.onLoad(() => {});
BlacklightRangeLimit.init({ onLoadHandler: Blacklight.onLoad });
console.log("here???")

// Enhance search bars (navbar + home hero) consistently
function enhanceSearchBar(rootSelector) {
  const root = document.querySelector(rootSelector);
  if (!root) return;
  const form = root.querySelector('form.search-query-form');
  const input = root.querySelector('input#q');
  const submit = root.querySelector('#search');
  if (!form || !input || !submit) return;

  // Prevent duplicate clear button
  if (submit.previousElementSibling && submit.previousElementSibling.classList?.contains('btn-clear-search')) return;

  const clearBtn = document.createElement('button');
  clearBtn.type = 'button';
  clearBtn.className = 'btn btn-outline-secondary btn-clear-search';
  const lang = document.documentElement.lang || 'en';
  const clearLabel = lang.startsWith('fr') ? 'Effacer la recherche' : 'Clear search';
  const clearText = lang.startsWith('fr') ? 'Effacer' : 'Clear';
  clearBtn.innerHTML = `<i class="bi bi-x-lg" aria-hidden="true"></i><span class="visually-hidden">${clearText}</span>`;
  clearBtn.setAttribute('aria-label', clearLabel);
  clearBtn.hidden = !input.value;

  clearBtn.addEventListener('click', () => {
    input.value = '';
    input.focus();
    clearBtn.hidden = true;
  });

  input.addEventListener('input', () => {
    clearBtn.hidden = input.value.length === 0;
  });

  submit.parentElement.insertBefore(clearBtn, submit);

  // Keyboard shortcuts
  window.addEventListener('keydown', (e) => {
    const isTypingInInput = document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA');
    if (!isTypingInInput && (e.key === '/' || (e.key.toLowerCase() === 'k' && (e.ctrlKey || e.metaKey)))) {
      e.preventDefault();
      input.focus();
      input.select();
    }
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && input.value) {
      input.value = '';
      clearBtn.hidden = true;
      e.stopPropagation();
    }
  });

  // Accessibility hint
  const helpId = `${rootSelector.replace(/[^a-z]/gi,'')}-search-help`;
  let help = document.getElementById(helpId);
  if (!help) {
    help = document.createElement('div');
    help.id = helpId;
    help.className = 'visually-hidden';
    const lng = document.documentElement.lang || 'en';
    help.textContent = lng.startsWith('fr')
      ? 'Utilisez la barre oblique (/) ou Ctrl+K pour activer la recherche. Appuyez sur Échap pour effacer.'
      : 'Use slash (/) or Ctrl+K to focus search. Press Escape to clear.';
    form.appendChild(help);
  }
  input.setAttribute('aria-describedby', [input.getAttribute('aria-describedby'), helpId].filter(Boolean).join(' '));
}

function parseTypedPlaceholderPhrases(input) {
  const raw = input?.dataset?.typedPlaceholderPhrases;
  if (!raw) return [];
  return raw.split('|').map((phrase) => phrase.trim()).filter(Boolean);
}

function attachTypedPlaceholder(input) {
  if (!input || input.dataset.typedPlaceholderReady === 'true') return;
  const phrases = parseTypedPlaceholderPhrases(input);
  if (!phrases.length) return;

  input.dataset.typedPlaceholderReady = 'true';

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    input.setAttribute('placeholder', phrases[0]);
    return;
  }

  let phraseIndex = 0;
  let charIndex = 0;
  let isDeleting = false;
  let timerId = null;

  const typeSpeed = 85;
  const deleteSpeed = 42;
  const holdDelay = 1250;
  const betweenDelay = 280;
  const idleDelay = 260;

  const step = () => {
    if (!document.body.contains(input)) return;

    if (input === document.activeElement || input.value.length > 0) {
      timerId = window.setTimeout(step, idleDelay);
      return;
    }

    const phrase = phrases[phraseIndex];

    if (!isDeleting) {
      charIndex += 1;
      input.setAttribute('placeholder', phrase.slice(0, charIndex));
      if (charIndex >= phrase.length) {
        isDeleting = true;
        timerId = window.setTimeout(step, holdDelay);
        return;
      }
      timerId = window.setTimeout(step, typeSpeed);
      return;
    }

    charIndex -= 1;
    input.setAttribute('placeholder', phrase.slice(0, charIndex));
    if (charIndex <= 0) {
      isDeleting = false;
      phraseIndex = (phraseIndex + 1) % phrases.length;
      timerId = window.setTimeout(step, betweenDelay);
      return;
    }
    timerId = window.setTimeout(step, deleteSpeed);
  };

  timerId = window.setTimeout(step, 450);

  input.addEventListener('blur', () => {
    if (!timerId) timerId = window.setTimeout(step, idleDelay);
  });
}

function initTypedPlaceholders() {
  document.querySelectorAll('input.js-typed-placeholder').forEach((input) => {
    attachTypedPlaceholder(input);
  });
}

document.addEventListener('DOMContentLoaded', () => {
  enhanceSearchBar('.navbar-search');
  enhanceSearchBar('.home-search');
  initTypedPlaceholders();
});
document.addEventListener('turbo:load', initTypedPlaceholders);

// Page search: fetch IIIF search + manifest on the client so the Rails render doesn't block
function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content?.trim();
}

function trimTrailingSlash(str = '') {
  if (!str) return '';
  return str.endsWith('/') ? str.slice(0, -1) : str;
}

function escapeHtml(str) {
  return String(str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function fetchJsonWithTimeout(url, timeoutMs = 7000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { headers: { Accept: 'application/json' }, signal: controller.signal })
    .finally(() => clearTimeout(timer))
    .then((res) => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json();
    });
}

function parseSearchItems(json) {
  if (Array.isArray(json?.items) && json.items.length) return json.items;
  if (Array.isArray(json?.resources) && json.resources.length) return json.resources;
  return [];
}

function buildCanvasIndexMap(manifestJson) {
  const canvases = Array.isArray(manifestJson?.items)
    ? manifestJson.items
    : manifestJson?.sequences?.[0]?.canvases || [];
  const map = {};
  canvases.forEach((canvas, idx) => {
    const id = canvas.id || canvas['@id'];
    if (id) map[id] = idx + 1;
  });
  return map;
}

function collectPageNumbers(items, canvasMap) {
  const pages = [];
  items.forEach((item) => {
    const target = item.target || item.on;
    if (!target) return;
    const canvasUrl = String(target).split('#')[0];
    let index = canvasMap[canvasUrl];
    if (index == null) {
      const trailing = canvasUrl.split('/').pop();
      const match = Object.keys(canvasMap).find((key) => key.endsWith(`/${trailing}`));
      if (match) index = canvasMap[match];
    }
    if (index) pages.push(index);
  });
  return Array.from(new Set(pages)).sort((a, b) => a - b);
}

function renderPageSearchEmpty(container) {
  const body = container.querySelector('[data-page-search-body]');
  const badge = container.querySelector('.page-search-count');
  const status = container.querySelector('.page-search-status');
  if (badge) badge.textContent = '0';
  if (status) status.textContent = '';
  const emptyMsg = container.dataset.noResultsHtml || 'No page matches found.';
  if (body) body.innerHTML = `<div class="page-search-header"><span>${emptyMsg}</span></div>`;
}

function renderPageSearchResults(container, pages, term, docId) {
  const body = container.querySelector('[data-page-search-body]');
  const badge = container.querySelector('.page-search-count');
  const status = container.querySelector('.page-search-status');
  if (badge) badge.textContent = pages.length;
  if (status) status.textContent = '';
  const params = new URLSearchParams(window.location.search);
  const currentPage = parseInt(params.get('pageNum'), 10) || 0;
  const ariaTemplate = container.dataset.goToPageAriaTemplate || 'Go to page __PAGE__';
  const showMoreLabel = container.dataset.showMoreLabel || 'Show more';
  const lang = document.documentElement.lang || 'en';
  const showLessLabel =
    container.dataset.showLessLabel ||
    (lang.startsWith('fr') ? 'Afficher moins' : 'Show less');
  const prevHitLabel = escapeHtml(container.dataset.prevHitLabel || '');
  const prevHitAria = escapeHtml(container.dataset.prevHitAria || '');
  const nextHitLabel = escapeHtml(container.dataset.nextHitLabel || '');
  const nextHitAria = escapeHtml(container.dataset.nextHitAria || '');

  const hrefFor = (pageNum) =>
    `/catalog/${encodeURIComponent(docId)}?pageNum=${pageNum}&q=${encodeURIComponent(term)}`;

  const chips = pages.map((page) => {
    const isCurrent = currentPage === page;
    const aria = escapeHtml(ariaTemplate.replace('__PAGE__', page));
    return `<a role="listitem"
               class="chip page-chip ${isCurrent ? 'is-current' : ''}"
               ${isCurrent ? 'aria-current="page"' : ''}
               aria-label="${aria}"
               href="${hrefFor(page)}">
              ${page}
            </a>`;
  });

  const visibleChips = chips.slice(0, 24).join('');
  const restChips = chips.slice(24).join('');
  const moreWrapper = restChips ? `<span class="page-search-more" hidden>${restChips}</span>` : '';

  const prevHit = currentPage > 0 ? pages.filter((p) => p < currentPage).pop() : null;
  const nextHit = currentPage > 0 ? pages.find((p) => p > currentPage) : null;

  const prevBtn = prevHit
    ? `<a class="btn btn-outline-secondary btn-sm chip-nav"
           href="${hrefFor(prevHit)}"
           aria-label="${prevHitAria}">
        <i class="bi bi-arrow-left" aria-hidden="true"></i>
        <span class="d-none d-sm-inline">${prevHitLabel}</span>
      </a>`
    : '';

  const nextBtn = nextHit
    ? `<a class="btn btn-outline-secondary btn-sm chip-nav"
           href="${hrefFor(nextHit)}"
           aria-label="${nextHitAria}">
        <span class="d-none d-sm-inline">${nextHitLabel}</span>
        <i class="bi bi-arrow-right ms-sm-1" aria-hidden="true"></i>
      </a>`
    : '';

  const toolbar = prevBtn || nextBtn
    ? `<div class="page-search-toolbar d-flex align-items-center gap-2 mb-2">${prevBtn}${nextBtn}</div>`
    : '';

  const toggle = restChips
    ? `<div class="page-search-togglebar mt-2">
         <button type="button"
                 class="btn btn-link btn-sm page-search-toggle p-0"
                 data-label-more="${escapeHtml(showMoreLabel)}"
                 data-label-less="${escapeHtml(showLessLabel)}">
           <i class="bi bi-chevron-down" aria-hidden="true"></i>
           <span>${escapeHtml(showMoreLabel)}</span>
         </button>
       </div>`
    : '';

  if (body) {
    body.innerHTML = `${toolbar}
      <div class="page-chip-list" role="list">
        ${visibleChips}
        ${moreWrapper}
      </div>
      ${toggle}`;
  }
}

async function hydratePageSearch(container) {
  const term = (container.dataset.term || '').trim();
  const arkUrl = container.dataset.arkUrl || '';
  const arkPath = container.dataset.arkPath || arkUrl.replace(/^https?:\/\/n2t.net\/ark:\//i, '');
  if (/^69429\/s/i.test(arkPath)) {
    renderPageSearchEmpty(container);
    return;
  }
  if (!term || term === '*:*' || !arkUrl) {
    renderPageSearchEmpty(container);
    return;
  }

  const contentBase =
    trimTrailingSlash(getMetaContent('iiif-content-search-base')) ||
    'https://crkn-iiif-content-search.azurewebsites.net/search';
  const manifestBase =
    trimTrailingSlash(getMetaContent('iiif-manifest-base')) ||
    'https://crkn-iiif-api.azurewebsites.net/manifest';

  const searchUrl = `${contentBase}/${encodeURIComponent(arkPath)}?q=${encodeURIComponent(term)}`;
  const manifestUrl = `${manifestBase}/${arkPath}`;

  try {
    const [searchJson, manifestJson] = await Promise.all([
      fetchJsonWithTimeout(searchUrl, 6000),
      fetchJsonWithTimeout(manifestUrl, 6000),
    ]);
    const items = parseSearchItems(searchJson);
    const canvasMap = buildCanvasIndexMap(manifestJson);
    const pages = collectPageNumbers(items, canvasMap);
    if (!pages.length) {
      renderPageSearchEmpty(container);
      return;
    }
    renderPageSearchResults(container, pages, term, container.dataset.docId);
  } catch (err) {
    console.warn('Page search fetch failed', err, searchUrl, manifestUrl);
    const status = container.querySelector('.page-search-status');
    if (status) status.textContent = '';
    const body = container.querySelector('[data-page-search-body]');
    if (body) {
      body.innerHTML = '<div class="text-muted small">Unable to load page matches right now.</div>';
    }
  }
}

function initPageSearch() {
  const containers = document.querySelectorAll('[data-page-search="true"]');
  containers.forEach((container) => {
    if (container.dataset.pageSearchHydrated === '1') return;
    container.dataset.pageSearchHydrated = '1';
    hydratePageSearch(container);
  });
}

document.addEventListener('DOMContentLoaded', initPageSearch);

// Page search chips: toggle show more/less
document.addEventListener('click', (e) => {
  const btn = e.target.closest('.page-search-toggle');
  if (!btn) return;
  const container = btn.closest('.page-search-res-wrap');
  if (!container) return;
  const more = container.querySelector('.page-search-more');
  if (!more) return;
  const span = btn.querySelector('span');
  const icon = btn.querySelector('i');
  const lang = document.documentElement.lang || 'en';
  const labelMore = btn.dataset.labelMore || (lang.startsWith('fr') ? 'Afficher plus' : 'Show more');
  const labelLess = btn.dataset.labelLess || (lang.startsWith('fr') ? 'Afficher moins' : 'Show less');

  const hidden = more.hasAttribute('hidden');
  if (hidden) {
    more.removeAttribute('hidden');
    if (span) span.textContent = labelLess;
    if (icon) icon.classList.remove('bi-chevron-down'), icon.classList.add('bi-chevron-up');
  } else {
    more.setAttribute('hidden', '');
    if (span) span.textContent = labelMore;
    if (icon) icon.classList.remove('bi-chevron-up'), icon.classList.add('bi-chevron-down');
  }
});

// Members section interactions: tabs, province chips, name filter
function normalizeMemberFilterValue(value = '') {
  return String(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function initMembersSection() {
  const sections = document.querySelectorAll('.members-section');
  sections.forEach((section) => {
    if (section.dataset.membersInit === '1') return;
    section.dataset.membersInit = '1';

    const tabs = section.querySelectorAll('[data-members-tab]');
    const groups = section.querySelectorAll('[data-members-group]');
    const filterChips = section.querySelectorAll('.chip-filter');
    const input = section.querySelector('#members-filter-input');
    const clearBtn = section.querySelector('.btn-clear-members');
    const emptyState = section.querySelector('[data-members-empty]');

    let activeGroup = section.querySelector('[data-members-tab].active')?.dataset.membersTab || 'institutional';
    let activeProvince = section.querySelector('.chip-filter.active')?.dataset.province || 'all';
    let text = '';

    const applyFilters = () => {
      let hasVisibleItems = false;
      const activeChip = section.querySelector('.chip-filter.active');
      activeProvince = activeChip?.dataset?.province || activeProvince || 'all';
      const hasActiveFilter = activeProvince !== 'all' || text !== '';

      groups.forEach((group) => {
        const isActiveGroup = group.dataset.membersGroup === activeGroup;
        group.classList.toggle('d-none', !isActiveGroup);
        group.setAttribute('aria-hidden', isActiveGroup ? 'false' : 'true');
        group.classList.toggle('is-filtered-view', isActiveGroup && hasActiveFilter);
        if (!isActiveGroup) return;

        const seenMemberNames = new Set();

        group.querySelectorAll('.members-marquee-row').forEach((row) => {
          let rowHasVisibleItem = false;

          row.querySelectorAll('.member-logo').forEach((logo) => {
            const prov = logo.dataset.province || '';
            const name = logo.dataset.memberName || '';
            const isClone = logo.dataset.memberClone === 'true' || logo.getAttribute('tabindex') === '-1';
            const provinceMatch = activeProvince === 'all' || prov === activeProvince;
            const textMatch = text === '' || name.includes(text);
            const isVisible = provinceMatch && textMatch;
            const isDuplicateName = hasActiveFilter && seenMemberNames.has(name);
            const shouldShowLogo = isVisible && (!hasActiveFilter || (!isClone && !isDuplicateName));

            logo.classList.toggle('is-filtered-out', !shouldShowLogo);
            if (shouldShowLogo && !isClone) {
              seenMemberNames.add(name);
              rowHasVisibleItem = true;
            }
          });

          row.classList.toggle('d-none', !rowHasVisibleItem);
          if (rowHasVisibleItem) hasVisibleItems = true;
        });
      });

      if (emptyState) emptyState.classList.toggle('d-none', hasVisibleItems);
    };

    const activateTab = (btn) => {
      tabs.forEach((item) => {
        const selected = item === btn;
        item.classList.toggle('active', selected);
        item.setAttribute('aria-selected', selected ? 'true' : 'false');
        item.setAttribute('tabindex', selected ? '0' : '-1');
      });
      activeGroup = btn.dataset.membersTab || 'institutional';
      applyFilters();
    };

    tabs.forEach((btn) => {
      btn.addEventListener('click', () => {
        activateTab(btn);
      });
      btn.addEventListener('keydown', (event) => {
        const keys = ['ArrowRight', 'ArrowLeft', 'Home', 'End'];
        if (!keys.includes(event.key)) return;
        event.preventDefault();
        const tabArray = Array.from(tabs);
        const currentIndex = tabArray.indexOf(btn);
        let nextIndex = currentIndex;
        if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % tabArray.length;
        if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + tabArray.length) % tabArray.length;
        if (event.key === 'Home') nextIndex = 0;
        if (event.key === 'End') nextIndex = tabArray.length - 1;
        const nextTab = tabArray[nextIndex];
        if (!nextTab) return;
        activateTab(nextTab);
        nextTab.focus();
      });
    });

    const activateProvince = (chip) => {
      filterChips.forEach((item) => {
        const selected = item === chip;
        item.classList.toggle('active', selected);
        item.setAttribute('aria-pressed', selected ? 'true' : 'false');
      });
      activeProvince = chip.dataset.province || 'all';
      applyFilters();
    };

    filterChips.forEach((chip) => {
      chip.addEventListener('click', () => {
        activateProvince(chip);
      });
    });

    if (input) {
      if (clearBtn) clearBtn.hidden = input.value.length === 0;
      input.addEventListener('input', () => {
        text = normalizeMemberFilterValue(input.value);
        if (clearBtn) clearBtn.hidden = input.value.length === 0;
        applyFilters();
      });
    }

    if (clearBtn && input) {
      clearBtn.addEventListener('click', () => {
        input.value = '';
        text = '';
        clearBtn.hidden = true;
        input.focus();
        applyFilters();
      });
    }

    const selectedTab = section.querySelector('[data-members-tab].active') || tabs[0];
    if (selectedTab) activateTab(selectedTab);
    const selectedProvince = section.querySelector('.chip-filter.active') || filterChips[0];
    if (selectedProvince) activateProvince(selectedProvince);
    else applyFilters();
  });
}

document.addEventListener('DOMContentLoaded', initMembersSection);

// Home explore sliders: horizontal scroll with prev/next controls
function initExploreSliders() {
  const sliders = document.querySelectorAll('[data-slider="explore"]');
  sliders.forEach((slider) => {
    if (slider.dataset.sliderInit === '1') return;

    const viewport = slider.querySelector('[data-slider-viewport]');
    const track = slider.querySelector('[data-slider-track]');
    const prev = slider.querySelector('[data-slider-prev]');
    const next = slider.querySelector('[data-slider-next]');
    if (!viewport || !track || !prev || !next) return;

    slider.dataset.sliderInit = '1';

    const maxScroll = () => Math.max(0, viewport.scrollWidth - viewport.clientWidth);
    const snapPoints = () => {
      const cards = Array.from(track.querySelectorAll('.home-split-card'));
      const max = maxScroll();
      if (!cards.length) return [0, max];

      const viewportRect = viewport.getBoundingClientRect();
      const points = cards.map((card) => {
        const rect = card.getBoundingClientRect();
        const left = rect.left - viewportRect.left + viewport.scrollLeft;
        return Math.max(0, Math.min(max, left));
      });

      points.push(0, max);

      return Array.from(new Set(points.map((point) => Math.round(point))))
        .sort((a, b) => a - b);
    };

    const updateControls = () => {
      const max = maxScroll();
      const left = viewport.scrollLeft;
      const canScroll = max > 4;
      slider.classList.toggle('is-static', !canScroll);
      prev.disabled = !canScroll || left <= 4;
      next.disabled = !canScroll || left >= (max - 4);
    };

    const scrollByStep = (dir) => {
      const points = snapPoints();
      const left = viewport.scrollLeft;
      const epsilon = 6;
      let target = left;

      if (dir > 0) {
        target = points.find((point) => point > left + epsilon);
        if (target === undefined) target = maxScroll();
      } else {
        const previousPoints = points.filter((point) => point < left - epsilon);
        target = previousPoints.length ? previousPoints[previousPoints.length - 1] : 0;
      }

      viewport.scrollTo({ left: target, behavior: 'smooth' });
      window.setTimeout(updateControls, 320);
    };

    prev.addEventListener('click', () => scrollByStep(-1));
    next.addEventListener('click', () => scrollByStep(1));
    viewport.addEventListener('scroll', updateControls, { passive: true });
    window.addEventListener('resize', updateControls);

    updateControls();
  });
}

document.addEventListener('DOMContentLoaded', initExploreSliders);

let scrollRevealObserver = null;

function shouldInitScrollRevealText() {
  const body = document.body;
  if (!body) return false;
  return (
    body.classList.contains('blacklight-pages-home') ||
    body.classList.contains('blacklight-pages-about_canadiana') ||
    body.classList.contains('blacklight-pages-about_heritage')
  );
}

function collectScrollRevealTargets(root) {
  const selector = [
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'p',
    'li',
    'summary',
    'blockquote',
    'figcaption',
    'a.home-inline-link',
    'a.hero-secondary-link',
    'a.hero-primary-btn',
    'a.about-modern-cta',
    'a.home-statement-cta'
  ].join(', ');

  return Array.from(root.querySelectorAll(selector)).filter((element) => {
    if (element.dataset.scrollRevealBound === '1') return false;
    if (element.classList.contains('visually-hidden') || element.closest('.visually-hidden')) return false;
    return (element.textContent || '').trim().length > 0;
  });
}

function initScrollRevealText() {
  if (!shouldInitScrollRevealText()) return;

  const body = document.body;
  const isHome = body.classList.contains('blacklight-pages-home');
  const isAbout =
    body.classList.contains('blacklight-pages-about_canadiana') ||
    body.classList.contains('blacklight-pages-about_heritage');

  let roots = [];
  if (isHome) {
    roots = Array.from(document.querySelectorAll('.home-page'));
  } else if (isAbout) {
    roots = Array.from(document.querySelectorAll('#main-container'));
  }

  if (!roots.length) return;

  const targets = [];
  roots.forEach((root) => {
    targets.push(...collectScrollRevealTargets(root));
  });
  if (!targets.length) return;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (prefersReducedMotion || !('IntersectionObserver' in window)) {
    targets.forEach((element) => {
      element.dataset.scrollRevealBound = '1';
      element.classList.add('scroll-reveal-text', 'is-visible');
    });
    return;
  }

  if (!scrollRevealObserver) {
    scrollRevealObserver = new IntersectionObserver(
      (entries, observer) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.16, rootMargin: '0px 0px -8% 0px' }
    );
  }

  targets.forEach((element, index) => {
    element.dataset.scrollRevealBound = '1';
    element.classList.add('scroll-reveal-text');
    element.style.setProperty('--scroll-reveal-delay', `${(index % 8) * 30}ms`);
    scrollRevealObserver.observe(element);
  });
}

document.addEventListener('DOMContentLoaded', initScrollRevealText);
document.addEventListener('turbo:load', initScrollRevealText);

let aboutFeaturePanTargets = [];
let aboutFeaturePanRafId = null;
let aboutFeaturePanListenersBound = false;

function shouldInitAboutFeaturePan() {
  const body = document.body;
  if (!body) return false;
  return (
    body.classList.contains('blacklight-pages-about_canadiana') ||
    body.classList.contains('blacklight-pages-about_heritage')
  );
}

function queueAboutFeaturePanUpdate() {
  if (aboutFeaturePanRafId !== null) return;
  aboutFeaturePanRafId = window.requestAnimationFrame(() => {
    aboutFeaturePanRafId = null;
    if (!aboutFeaturePanTargets.length) return;

    const viewportHeight = Math.max(window.innerHeight || 0, 1);
    aboutFeaturePanTargets.forEach((img) => {
      const mediaCard = img.closest('.about-modern-card--media');
      if (!mediaCard) return;

      const rect = mediaCard.getBoundingClientRect();
      const progress = (viewportHeight - rect.top) / (viewportHeight + rect.height);
      const clamped = Math.max(0, Math.min(1, progress));
      img.style.setProperty('--about-scroll-pan-y', `${(clamped * 100).toFixed(2)}%`);
    });
  });
}

function initAboutFeaturePan() {
  if (!shouldInitAboutFeaturePan()) {
    aboutFeaturePanTargets = [];
    return;
  }

  aboutFeaturePanTargets = Array.from(
    document.querySelectorAll(
      '.about-modern-feature-grid .about-modern-card--media img, .about-modern-work-grid .about-modern-card--media img'
    )
  );
  if (!aboutFeaturePanTargets.length) return;

  const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  aboutFeaturePanTargets.forEach((img) => {
    img.dataset.scrollPan = '1';
    img.style.setProperty('--about-scroll-pan-y', prefersReducedMotion ? '50%' : '0%');
  });

  if (prefersReducedMotion) return;

  queueAboutFeaturePanUpdate();

  if (aboutFeaturePanListenersBound) return;

  window.addEventListener('scroll', queueAboutFeaturePanUpdate, { passive: true });
  window.addEventListener('resize', queueAboutFeaturePanUpdate);
  aboutFeaturePanListenersBound = true;
}

document.addEventListener('DOMContentLoaded', initAboutFeaturePan);
document.addEventListener('turbo:load', initAboutFeaturePan);

function syncCanadianaWorkGridHeights() {
  const body = document.body;
  if (!body || !body.classList.contains('blacklight-pages-about_canadiana')) return;

  const workGrid = document.querySelector('.about-modern-work-grid');
  if (!workGrid) return;

  const mediaCard = workGrid.querySelector('.about-modern-card--media');
  const stepsCard = workGrid.querySelector('.about-modern-card--steps');
  if (!mediaCard || !stepsCard) return;

  mediaCard.style.removeProperty('--canadiana-work-card-height');

  if (window.innerWidth < 993) return;

  const stepsHeight = stepsCard.getBoundingClientRect().height;
  if (stepsHeight > 0) {
    mediaCard.style.setProperty('--canadiana-work-card-height', `${stepsHeight}px`);
  }
}

document.addEventListener('DOMContentLoaded', syncCanadianaWorkGridHeights);
document.addEventListener('turbo:load', syncCanadianaWorkGridHeights);
window.addEventListener('resize', syncCanadianaWorkGridHeights);

function moveCatalogAppliedParams() {
  const target = document.querySelector('[data-catalog-applied-params-target]');
  const appliedParams = document.querySelector('.blacklight-catalog-index #appliedParams');

  if (!target || !appliedParams) return;
  if (target.contains(appliedParams)) return;

  target.appendChild(appliedParams);
}

document.addEventListener('DOMContentLoaded', moveCatalogAppliedParams);
document.addEventListener('turbo:load', moveCatalogAppliedParams);

let heritageFloatingCardsState = null;
let heritageFloatingCardsRefreshTimer = null;
let heritageFloatingCardsViewportListenersBound = false;

function queueHeritageFloatingCardsRefresh() {
  if (heritageFloatingCardsRefreshTimer !== null) {
    window.clearTimeout(heritageFloatingCardsRefreshTimer);
  }

  heritageFloatingCardsRefreshTimer = window.setTimeout(() => {
    heritageFloatingCardsRefreshTimer = null;

    if (!shouldInitHeritageFloatingCards()) {
      destroyHeritageFloatingCards();
      return;
    }

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || window.innerWidth < 1100) {
      destroyHeritageFloatingCards();
      return;
    }

    if (!heritageFloatingCardsState) {
      initHeritageFloatingCards();
      return;
    }

    if (typeof heritageFloatingCardsState.rebuildLayout === 'function') {
      window.requestAnimationFrame(heritageFloatingCardsState.rebuildLayout);
    }
  }, 120);
}

function bindHeritageFloatingCardsViewportListeners() {
  if (heritageFloatingCardsViewportListenersBound) return;

  window.addEventListener('resize', queueHeritageFloatingCardsRefresh, { passive: true });
  window.addEventListener('orientationchange', queueHeritageFloatingCardsRefresh);

  heritageFloatingCardsViewportListenersBound = true;
}

function shouldInitHeritageFloatingCards() {
  const body = document.body;
  if (!body) return false;
  return body.classList.contains('blacklight-pages-about_heritage');
}

function destroyHeritageFloatingCards() {
  if (heritageFloatingCardsRefreshTimer !== null) {
    window.clearTimeout(heritageFloatingCardsRefreshTimer);
    heritageFloatingCardsRefreshTimer = null;
  }

  if (!heritageFloatingCardsState) return;

  const state = heritageFloatingCardsState;
  if (state.rafId !== null) window.cancelAnimationFrame(state.rafId);
  if (state.resizeHandler) window.removeEventListener('resize', state.resizeHandler);
  if (state.visibilityHandler) document.removeEventListener('visibilitychange', state.visibilityHandler);

  state.cards.forEach((card) => {
    card.style.removeProperty('transform');
    card.classList.remove('is-floating');
  });

  heritageFloatingCardsState = null;
}

function initHeritageFloatingCards() {
  destroyHeritageFloatingCards();
  if (!shouldInitHeritageFloatingCards()) return;
  bindHeritageFloatingCardsViewportListeners();
  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  if (window.innerWidth < 1100) return;

  const grid = document.querySelector('.about-modern-collection-grid--five');
  if (!grid) return;

  const cards = Array.from(grid.querySelectorAll('.about-modern-card--collection'));
  if (cards.length < 2) return;

  const randomBetween = (min, max) => min + Math.random() * (max - min);
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

  const state = {
    grid,
    cards,
    items: [],
    containerPadding: 14,
    rafId: null,
    lastTimestamp: null,
    resizeHandler: null,
    visibilityHandler: null,
    rebuildLayout: null
  };

  const rebuildLayout = () => {
    const gridRect = grid.getBoundingClientRect();
    const padding = state.containerPadding;

    const previous = new Map(state.items.map((item) => [item.card, item]));
    state.items = cards.map((card) => {
      const width = card.offsetWidth;
      const height = card.offsetHeight;
      const prior = previous.get(card);
      const angle = randomBetween(0, Math.PI * 2);
      const speed = randomBetween(0.009, 0.022);

      const cardRect = card.getBoundingClientRect();
      const baseX = card.offsetParent === grid ? card.offsetLeft : (cardRect.left - gridRect.left);
      const baseY = card.offsetParent === grid ? card.offsetTop : (cardRect.top - gridRect.top);
      let minX = padding - baseX;
      let maxX = gridRect.width - padding - baseX - width;
      let minY = padding - baseY;
      let maxY = gridRect.height - padding - baseY - height;

      if (minX > maxX) {
        minX = 0;
        maxX = 0;
      }
      if (minY > maxY) {
        minY = 0;
        maxY = 0;
      }

      card.classList.add('is-floating');

      return {
        card,
        baseX,
        baseY,
        width,
        height,
        minX,
        maxX,
        minY,
        maxY,
        x: clamp(prior?.x ?? 0, minX, maxX),
        y: clamp(prior?.y ?? 0, minY, maxY),
        vx: prior?.vx ?? Math.cos(angle) * speed,
        vy: prior?.vy ?? Math.sin(angle) * speed,
        bobAmp: prior?.bobAmp ?? randomBetween(0.9, 2.6),
        bobRate: prior?.bobRate ?? randomBetween(0.00032, 0.00062),
        bobPhase: prior?.bobPhase ?? randomBetween(0, Math.PI * 2)
      };
    });
  };
  state.rebuildLayout = rebuildLayout;

  const resolveCollisions = () => {
    const items = state.items;
    for (let i = 0; i < items.length; i += 1) {
      for (let j = i + 1; j < items.length; j += 1) {
        const a = items[i];
        const b = items[j];

        const aLeft = a.baseX + a.x;
        const aTop = a.baseY + a.y;
        const bLeft = b.baseX + b.x;
        const bTop = b.baseY + b.y;

        const overlapX = Math.min(aLeft + a.width, bLeft + b.width) - Math.max(aLeft, bLeft);
        const overlapY = Math.min(aTop + a.height, bTop + b.height) - Math.max(aTop, bTop);
        if (overlapX <= 0 || overlapY <= 0) continue;

        if (overlapX < overlapY) {
          const direction = (aLeft + a.width * 0.5) < (bLeft + b.width * 0.5) ? -1 : 1;
          const push = overlapX * 0.52;
          a.x += direction * push;
          b.x -= direction * push;
          const avx = a.vx;
          a.vx = -b.vx * 0.92;
          b.vx = -avx * 0.92;
        } else {
          const direction = (aTop + a.height * 0.5) < (bTop + b.height * 0.5) ? -1 : 1;
          const push = overlapY * 0.52;
          a.y += direction * push;
          b.y -= direction * push;
          const avy = a.vy;
          a.vy = -b.vy * 0.92;
          b.vy = -avy * 0.92;
        }
      }
    }
  };

  const tick = (timestamp) => {
    state.rafId = window.requestAnimationFrame(tick);
    if (document.visibilityState === 'hidden') {
      state.lastTimestamp = timestamp;
      return;
    }

    const dt = Math.min(34, state.lastTimestamp ? (timestamp - state.lastTimestamp) : 16);
    state.lastTimestamp = timestamp;

    state.items.forEach((item) => {
      item.x += item.vx * dt;
      item.y += item.vy * dt;

      if (item.x <= item.minX || item.x >= item.maxX) {
        item.x = clamp(item.x, item.minX, item.maxX);
        item.vx *= -1;
      }
      if (item.y <= item.minY || item.y >= item.maxY) {
        item.y = clamp(item.y, item.minY, item.maxY);
        item.vy *= -1;
      }

      const speed = Math.hypot(item.vx, item.vy);
      if (speed < 0.0062) {
        const resetAngle = randomBetween(0, Math.PI * 2);
        item.vx = Math.cos(resetAngle) * 0.011;
        item.vy = Math.sin(resetAngle) * 0.011;
      }
    });

    resolveCollisions();

    state.items.forEach((item) => {
      item.x = clamp(item.x, item.minX, item.maxX);
      item.y = clamp(item.y, item.minY, item.maxY);
      const bob = Math.sin(timestamp * item.bobRate + item.bobPhase) * item.bobAmp;
      item.card.style.transform = `translate3d(${item.x.toFixed(2)}px, ${(item.y + bob).toFixed(2)}px, 0)`;
    });
  };

  state.resizeHandler = () => {
    if (window.innerWidth < 1100) {
      destroyHeritageFloatingCards();
      return;
    }
    window.requestAnimationFrame(rebuildLayout);
  };

  state.visibilityHandler = () => {
    if (document.visibilityState === 'visible') {
      rebuildLayout();
    }
  };

  rebuildLayout();
  state.rafId = window.requestAnimationFrame(tick);
  window.addEventListener('resize', state.resizeHandler);
  document.addEventListener('visibilitychange', state.visibilityHandler);
  heritageFloatingCardsState = state;
}

document.addEventListener('DOMContentLoaded', initHeritageFloatingCards);
document.addEventListener('turbo:load', initHeritageFloatingCards);
document.addEventListener('turbo:before-cache', destroyHeritageFloatingCards);
