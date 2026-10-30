import Lenis from 'lenis'
import { application } from '../controllers/index.js'

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
function initMiradorViewer() {
  const pageViewer = document.getElementById("my-mirador");
  if (!pageViewer) return;
  pageViewer.setAttribute('data-lenis-prevent', '');
  if (typeof Mirador === 'undefined') {
    if (!window.__miradorRetryCount || window.__miradorRetryCount < 20) {
      window.__miradorRetryCount = (window.__miradorRetryCount || 0) + 1;
      setTimeout(initMiradorViewer, 50);
    }
    return;
  }
  window.__miradorRetryCount = 0;

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

  const documentId = pageViewer.getAttribute("data-docid");
  if (!documentId) return;

  let contentSearch = {};
  const params = new URLSearchParams(window.location.search);
  if (params.has("q")) contentSearch = { query: params.get("q") };
  const manifestBase = document.querySelector('meta[name="iiif-manifest-base"]')?.content || "https://www-iiif-pres.canadiana.ca/manifest";
  let normalizedBase = manifestBase.endsWith('/') ? manifestBase : manifestBase + '/';
  let cleanDocId = documentId.replace(/^https?:\/\/[^/]+\//, '').replace(/^ark:?\/?/, '').replace(/^\/+/, '');
  let manifest = `${normalizedBase}${cleanDocId}`;
  const manifestList = {};
  manifestList[manifest] = { "provider": "Canadian Research Knowledge Network" };

  let mconfig = {
    id: "my-mirador",
    manifests: manifestList,
    windows: [
      {
        manifestId: manifest,
        contentSearch
      }
    ],
    view: "catalogueView",
    selectedTheme: 'light',
    language,
    translations: {
      en: {
        searchUnavailable: 'Searchable text unavailable',
        searchUnavailableTooltip: 'Searchable PDFs and text search are unavailable when no OCR (machine-readable text) exists.',
        pdfDisabledTooltip: 'Searchable PDFs and text search are unavailable when no OCR (machine-readable text) exists.'
      },
      fr: {
        searchUnavailable: 'Texte interrogeable non disponible',
        searchUnavailableTooltip: "Les fichiers PDF interrogeables et la recherche de texte ne sont pas disponibles lorsqu'il n'y a pas de texte lisible par machine (ROC).",
        pdfDisabledTooltip: "Les fichiers PDF interrogeables et la recherche de texte ne sont pas disponibles lorsqu'il n'y a pas de texte lisible par machine (ROC)."
      }
    },
    window: {
      imageToolsOpen: false,
      allowClose: false,
      allowFullscreen: true,
      allowMaximize: false,
      allowTopMenuButton: true,
      allowWindowSideBar: false,
      authNewWindowCenter: "parent",
      sideBarPanel: "info",
      defaultSidebarPanelHeight: 201,
      defaultSidebarPanelWidth: 235,
      defaultView: "single",
      forceDrawAnnotations: true,
      hideWindowTitle: true,
      highlightAllAnnotations: false,
      showLocalePicker: false,
      sideBarOpen: false,
      switchCanvasOnSearch: true,
      panels: {
        info: true,
        attribution: false,
        canvas: true,
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
      showNavigationControl: 1
    },
    workspace: {
      draggingEnabled: false,
      allowNewWindows: true,
      isWorkspaceAddVisible: false,
      exposeModeOn: false,
      height: 5000,
      showZoomControls: false,
      type: "mosaic",
      viewportPosition: {
        x: 0,
        y: 0
      },
      width: 5000
    },
    workspaceControlPanel: {
      enabled: false
    }
  };

  let miradorViewer = Mirador.viewer(mconfig);

  const isFr = (language || '').startsWith('fr');
  const searchableTextUnavailableText = pageViewer.getAttribute('data-searchable-text-unavailable') ||
    (isFr ? 'Texte interrogeable non disponible' : 'Searchable text unavailable');
  const searchUnavailableTooltipText = pageViewer.getAttribute('data-pdf-disabled-tooltip') ||
    pageViewer.getAttribute('data-searchable-text-unavailable-tooltip') ||
    (isFr ? "Les fichiers PDF interrogeables et la recherche de texte ne sont pas disponibles lorsqu'il n'y a pas de texte lisible par machine (ROC)." : "Searchable PDFs and text search are unavailable when no OCR (machine-readable text) exists.");

  const enhanceMiradorSearchControls = () => {
    const unavailableNotes = pageViewer.querySelectorAll('.SearchPanelControls-unavailableNote, [class*="SearchPanelControls-unavailableNote"]');
    unavailableNotes.forEach((note) => {
      const text = note.textContent.trim();
      if (text === 'Search is not available' || text === 'La recherche n\'est pas disponible' || !text) {
        note.textContent = searchableTextUnavailableText;
      }
      if (!note.getAttribute('title')) {
        note.setAttribute('title', searchUnavailableTooltipText);
      }
      const currentAria = note.getAttribute('aria-label') || '';
      if (!currentAria || currentAria.includes('Search is not available') || currentAria.includes('La recherche')) {
        note.setAttribute('aria-label', `${searchableTextUnavailableText}: ${searchUnavailableTooltipText}`);
      }
      note.setAttribute('role', 'status');
      note.setAttribute('tabindex', '0');
    });

    const disabledInputs = pageViewer.querySelectorAll('form[aria-label="Search"] input:disabled, form[aria-label="Recherche"] input:disabled, .SearchPanelControls-form input:disabled, input[aria-label*="Search"]:disabled');
    disabledInputs.forEach((input) => {
      input.setAttribute('title', searchUnavailableTooltipText);
      input.setAttribute('aria-label', `${searchableTextUnavailableText}: ${searchUnavailableTooltipText}`);
    });

    const disabledButtons = pageViewer.querySelectorAll('form[aria-label="Search"] button:disabled, form[aria-label="Recherche"] button:disabled, .SearchPanelControls-form button:disabled, button[aria-label*="Search"]:disabled');
    disabledButtons.forEach((btn) => {
      btn.setAttribute('title', searchUnavailableTooltipText);
      btn.setAttribute('aria-label', `${searchableTextUnavailableText}: ${searchUnavailableTooltipText}`);
    });
  };

  demoteMiradorMainLandmark();
  enhanceMiradorSearchControls();
  const miradorLandmarkObserver = new MutationObserver(() => {
    demoteMiradorMainLandmark();
    enhanceMiradorSearchControls();
  });
  miradorLandmarkObserver.observe(pageViewer, { childList: true, subtree: true });
  window.addEventListener('beforeunload', () => miradorLandmarkObserver.disconnect(), { once: true });
}

document.addEventListener('DOMContentLoaded', initMiradorViewer);
document.addEventListener('turbo:load', initMiradorViewer);

let lenisInstance = null
let lenisRafStarted = false

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
      smoothTouch: false,
      prevent: (node) => {
        if (!(node instanceof Element)) return false

        const collectionViewer = node.closest('.collection-item__viewer')
        if (collectionViewer) {
          return collectionViewer.classList.contains('is-active')
        }

        const featuredViewer = node.closest('.featured-item__viewer')
        if (featuredViewer) {
          return featuredViewer.classList.contains('is-active')
        }

        return Boolean(
          node.closest(
            '#my-mirador, .mirador-viewer, .mirador-canvas-container, .mirador-companion-window, .modal, dialog, [data-lenis-prevent]'
          )
        )
      }
    })
  }

  if (!lenisRafStarted) {
    lenisRafStarted = true
    window.requestAnimationFrame(rafLenis)
  }
}

document.addEventListener('DOMContentLoaded', initLenis)
document.addEventListener('turbo:load', initLenis)

import "bootstrap-icons/font/bootstrap-icons.css";
import BlacklightRangeLimit from 'blacklight-range-limit';
//Blacklight.onLoad(() => {});
BlacklightRangeLimit.init({ onLoadHandler: Blacklight.onLoad });

// Enhance search bars (navbar + home hero) consistently
function enhanceSearchBar(rootSelector) {
  const root = document.querySelector(rootSelector);
  if (!root) return;
  const form = root.querySelector('form.search-query-form');
  const input = root.querySelector('input#q');
  const submit = root.querySelector('#search');
  if (!form || !input || !submit) return;

  const body = document.body;
  const isCatalogPageSearch = root.matches('.navbar-search') && (
    body.classList.contains('blacklight-catalog-show') ||
    body.classList.contains('blacklight-catalog-index')
  );
  const hasCatalogHero = body.classList.contains('blacklight-catalog-index') &&
    !!document.querySelector('.catalog-search-hero');

  if (hasCatalogHero && !root.classList.contains('catalog-search-hero__search')) {
    return;
  }

  if (isCatalogPageSearch && !root.querySelector('.catalog-show-search-heading')) {
    const headingContainer = document.createElement('div');
    headingContainer.className = 'container';

    const heading = document.createElement('h1');
    heading.id = 'catalog-show-search-heading';
    heading.className = 'catalog-show-search-heading';
    heading.textContent = (document.documentElement.lang || 'en').startsWith('fr')
      ? 'Rechercher dans la collection Canadiana'
      : 'Search the Canadiana Collection';

    headingContainer.appendChild(heading);
    root.insertBefore(headingContainer, root.firstChild);
    root.setAttribute('aria-labelledby', heading.id);
    root.removeAttribute('aria-label');
  }

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
  const defaultPhrase = phrases[0];

  input.addEventListener('focus', () => {
    if (input.value.length === 0) {
      input.setAttribute('placeholder', '');
    }
  });

  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    input.setAttribute('placeholder', defaultPhrase);
    input.addEventListener('blur', () => {
      if (input.value.length === 0) {
        input.setAttribute('placeholder', defaultPhrase);
      }
    });
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

function initSearchBarEnhancements() {
  enhanceSearchBar('.navbar-search');
  enhanceSearchBar('.home-search');
}

document.addEventListener('DOMContentLoaded', () => {
  initSearchBarEnhancements();
  initTypedPlaceholders();
});
document.addEventListener('turbo:load', () => {
  initSearchBarEnhancements();
  initTypedPlaceholders();
});


// Full text chip is rendered server-side based on Solr content_search has_ocr query

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
    'a.home-hero__cta',
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

function getAboutFeaturePanContainer(img) {
  return img.closest(
    '.about-modern-card--media, .canadiana-story-mosaic__card--image'
  );
}

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
      const mediaCard = getAboutFeaturePanContainer(img);
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
      '.about-modern-feature-grid .about-modern-card--media img, .about-modern-work-grid .about-modern-card--media img, .canadiana-story-mosaic__card--image img'
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





function setFacetCardExpanded(card, expand) {
  const collapseEl = card.querySelector('.facet-content.collapse');
  const btn = card.querySelector('.card-header button.collapse-toggle, button[data-bs-toggle="collapse"], button[data-toggle="collapse"]');
  if (!collapseEl) return;

  if (expand) {
    collapseEl.classList.add('show');
    if (btn) {
      btn.classList.remove('collapsed');
      btn.setAttribute('aria-expanded', 'true');
    }
  } else {
    collapseEl.classList.remove('show');
    if (btn) {
      btn.classList.add('collapsed');
      btn.setAttribute('aria-expanded', 'false');
    }
  }
}

function getFacetCardId(card) {
  const collapseEl = card.querySelector('.facet-content.collapse');
  if (collapseEl && collapseEl.id) return collapseEl.id;
  const match = card.className.split(/\s+/).find((c) => c.startsWith('blacklight-'));
  return match || '';
}

function saveFacetAccordionState() {
  const container = document.querySelector('#facet-panel-collapse, #facets');
  if (!container) return;

  const cards = Array.from(container.querySelectorAll('.facet-limit'));
  if (cards.length === 0) return;

  const openIds = [];
  cards.forEach((card) => {
    const collapseEl = card.querySelector('.facet-content.collapse');
    if (collapseEl && collapseEl.classList.contains('show')) {
      const id = getFacetCardId(card);
      if (id) openIds.push(id);
    }
  });

  try {
    localStorage.setItem('canadiana_open_facet_ids', JSON.stringify(openIds));
    if (openIds.length === cards.length) {
      localStorage.setItem('canadiana_facet_expand_state', 'expand_all');
    } else if (openIds.length === 0) {
      localStorage.setItem('canadiana_facet_expand_state', 'collapse_all');
    } else {
      localStorage.setItem('canadiana_facet_expand_state', 'custom');
    }
  } catch (_e) {}
}

function expandAllFacets(save = true) {
  const container = document.querySelector('#facet-panel-collapse, #facets');
  if (!container) return;

  const cards = container.querySelectorAll('.facet-limit');
  cards.forEach((card) => setFacetCardExpanded(card, true));

  if (save) {
    try {
      localStorage.setItem('canadiana_facet_expand_state', 'expand_all');
      const allIds = Array.from(cards).map(getFacetCardId).filter(Boolean);
      localStorage.setItem('canadiana_open_facet_ids', JSON.stringify(allIds));
    } catch (_e) {}
  }
}

function collapseAllFacets(save = true) {
  const container = document.querySelector('#facet-panel-collapse, #facets');
  if (!container) return;

  const cards = container.querySelectorAll('.facet-limit');
  cards.forEach((card) => setFacetCardExpanded(card, false));

  if (save) {
    try {
      localStorage.setItem('canadiana_facet_expand_state', 'collapse_all');
      localStorage.setItem('canadiana_open_facet_ids', JSON.stringify([]));
    } catch (_e) {}
  }
}

function restoreFacetAccordionState() {
  const container = document.querySelector('#facet-panel-collapse, #facets');
  if (!container) return;

  const cards = container.querySelectorAll('.facet-limit');
  if (cards.length === 0) return;

  let state = null;
  let openIds = null;
  try {
    state = localStorage.getItem('canadiana_facet_expand_state');
    const rawIds = localStorage.getItem('canadiana_open_facet_ids');
    if (rawIds) openIds = JSON.parse(rawIds);
  } catch (_e) {}

  if (state === 'expand_all') {
    expandAllFacets(false);
  } else if (state === 'collapse_all') {
    collapseAllFacets(false);
  } else if (Array.isArray(openIds)) {
    cards.forEach((card) => {
      const id = getFacetCardId(card);
      const shouldOpen = openIds.includes(id);
      setFacetCardExpanded(card, shouldOpen);
    });
  }
}

function handleFacetExpandCollapseClick(event) {
  const target = event.target.closest('#facet-expand-all-btn, #facet-collapse-all-btn, .facet-expand-all-btn, .facet-collapse-all-btn');
  if (!target) return;

  event.preventDefault();
  if (target.matches('#facet-expand-all-btn, .facet-expand-all-btn')) {
    expandAllFacets(true);
  } else if (target.matches('#facet-collapse-all-btn, .facet-collapse-all-btn')) {
    collapseAllFacets(true);
  }
}

document.addEventListener('DOMContentLoaded', observeModalDomChanges);
document.addEventListener('turbo:load', observeModalDomChanges);
document.addEventListener('DOMContentLoaded', restoreFacetAccordionState);
document.addEventListener('turbo:load', restoreFacetAccordionState);
document.addEventListener('click', handleFacetExpandCollapseClick);
document.addEventListener('click', (e) => {
  if (e.target.closest('.facet-limit .collapse-toggle, .facet-limit button[data-bs-toggle="collapse"], .facet-limit button[data-toggle="collapse"]')) {
    setTimeout(saveFacetAccordionState, 350);
  }
});
document.addEventListener('shown.bs.collapse', (e) => {
  if (e.target.closest('.facet-limit')) saveFacetAccordionState();
});
document.addEventListener('hidden.bs.collapse', (e) => {
  if (e.target.closest('.facet-limit')) saveFacetAccordionState();
});
document.addEventListener('pointerdown', handleCheckboxFacetMoreActivation, true);
document.addEventListener('mousedown', handleCheckboxFacetMoreActivation, true);
document.addEventListener('click', handleCheckboxFacetMoreActivation, true);
document.addEventListener('keydown', handleCheckboxFacetMoreActivation, true);
function initFacetSuggestHandler() {
  let debounceTimeout = null;
  let activeAbortController = null;

  document.addEventListener('input', (e) => {
    const target = e.target;
    if (!target || !target.matches('.facet-suggest')) return;

    clearTimeout(debounceTimeout);
    if (activeAbortController) {
      activeAbortController.abort();
      activeAbortController = null;
    }

    debounceTimeout = setTimeout(async () => {
      const queryFragment = target.value ? target.value.trim() : '';
      const facetField = target.dataset.facetField;
      const modal = target.closest('#blacklight-modal, .modal, dialog') || document.querySelector('#blacklight-modal, .modal');
      const facetArea = modal ? modal.querySelector('.facet-extended-list') : document.querySelector('.facet-extended-list');
      const prevNextLinks = modal ? modal.querySelectorAll('.prev_next_links') : document.querySelectorAll('.prev_next_links');
      if (!facetField || !facetArea) return;

      const facetSearchContext = target.dataset.facetSearchContext || '';
      let facetSearchParams = '';
      try {
        const url = new URL(facetSearchContext, window.location.origin);
        url.searchParams.delete('facet.page');
        facetSearchParams = url.searchParams.toString();
      } catch (_err) {
        facetSearchParams = window.location.search.replace(/^\?/, '');
      }

      const urlToFetch = queryFragment
        ? `/catalogue/facet_suggest/${encodeURIComponent(facetField)}/${encodeURIComponent(queryFragment)}?${facetSearchParams}`
        : `/catalogue/facet_suggest/${encodeURIComponent(facetField)}?${facetSearchParams}`;

      activeAbortController = new AbortController();
      try {
        const response = await fetch(urlToFetch, {
          signal: activeAbortController.signal,
          headers: { 'Accept': 'text/html' }
        });
        if (response.ok) {
          const text = await response.text();
          if (facetArea) {
            facetArea.innerHTML = text;
            if (modal) syncAllSidebarToCheckboxesInModal(modal);
          }
        }
      } catch (err) {
        if (err.name !== 'AbortError') {
          console.warn('Facet suggest error:', err);
        }
      } finally {
        activeAbortController = null;
      }

      prevNextLinks.forEach((el) => {
        el.classList.toggle('invisible', Boolean(queryFragment));
      });
      facetArea.classList.toggle('facet-suggestions', Boolean(queryFragment));
    }, 180);
  }, true);
}

document.addEventListener('change', handleCheckboxFacetChange, true);
document.addEventListener('submit', handleCheckboxFacetFormSubmit, true);
initFacetSuggestHandler();
document.addEventListener('shown.bs.modal', (e) => syncAllSidebarToCheckboxesInModal(e.target));
document.addEventListener('loaded.blacklight.blacklight-modal', (e) => syncAllSidebarToCheckboxesInModal(e.target));
document.addEventListener('hidden.bs.modal', (e) => syncAllModalToCheckboxesInSidebar(e.target));
document.addEventListener('hide.bs.modal', (e) => syncAllModalToCheckboxesInSidebar(e.target));

