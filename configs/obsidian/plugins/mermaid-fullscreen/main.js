const { Plugin, Modal, Notice } = require('obsidian');

class MermaidLightboxModal extends Modal {
    constructor(app, sourceContainer, sourceSvg) {
        super(app);
        this.sourceContainer = sourceContainer;
        this.sourceSvg = sourceSvg;
        this.scale = 1;
        this.panX = 0;
        this.panY = 0;
        this.initialScale = 1;
        
        // Multi-touch gesture engine state
        this.pointers = new Map();
        this.initialDistance = 0;
        this.initialScaleAtPinch = 1;
        this.lastTapTime = 0;
    }

    onOpen() {
        const { contentEl, modalEl } = this;
        const isMobile = window.innerWidth <= 768;
        
        // Detect Dark vs Light mode dynamically from Obsidian document body
        const isDark = document.body.classList.contains('theme-dark');
        const themeClass = isDark ? 'theme-dark' : 'theme-light';

        // Modal container styling with strict touch-action: none
        modalEl.addClass('mermaid-lightbox-modal');
        modalEl.addClass(themeClass);
        modalEl.style.width = isMobile ? '98vw' : '96vw';
        modalEl.style.maxWidth = '1920px';
        modalEl.style.height = isMobile ? '94vh' : '94vh';
        modalEl.style.maxHeight = '1400px';
        modalEl.style.display = 'flex';
        modalEl.style.flexDirection = 'column';
        modalEl.style.padding = '0';
        modalEl.style.overflow = 'hidden';
        modalEl.style.borderRadius = isMobile ? '12px' : '16px';
        modalEl.style.border = '1px solid var(--background-modifier-border)';
        modalEl.style.background = 'var(--background-primary)';
        modalEl.style.boxShadow = '0 32px 80px rgba(0, 0, 0, 0.55)';
        modalEl.style.touchAction = 'none';
        modalEl.style.userSelect = 'none';

        contentEl.empty();
        contentEl.addClass('mermaid-lightbox-content');
        contentEl.addClass('markdown-rendered');
        contentEl.addClass(themeClass);
        contentEl.style.position = 'relative';
        contentEl.style.width = '100%';
        contentEl.style.height = '100%';
        contentEl.style.overflow = 'hidden';
        contentEl.style.display = 'flex';
        contentEl.style.alignItems = 'center';
        contentEl.style.justifyContent = 'center';
        contentEl.style.cursor = 'grab';
        contentEl.style.userSelect = 'none';
        contentEl.style.touchAction = 'none';
        contentEl.style.background = 'var(--background-primary)';

        // Top Floating Glass Toolbar
        const toolbar = contentEl.createDiv({ cls: 'mermaid-lightbox-toolbar' });
        toolbar.style.position = 'absolute';
        toolbar.style.top = isMobile ? '10px' : '16px';
        toolbar.style.right = isMobile ? '10px' : '16px';
        toolbar.style.display = 'flex';
        toolbar.style.alignItems = 'center';
        toolbar.style.gap = isMobile ? '4px' : '6px';
        toolbar.style.zIndex = '100';
        toolbar.style.padding = isMobile ? '4px 6px' : '6px 10px';
        toolbar.style.borderRadius = '10px';
        toolbar.style.background = 'color-mix(in srgb, var(--background-secondary) 88%, transparent)';
        toolbar.style.backdropFilter = 'blur(12px)';
        toolbar.style.border = '1px solid var(--background-modifier-border)';
        toolbar.style.boxShadow = '0 4px 16px rgba(0, 0, 0, 0.25)';
        toolbar.style.touchAction = 'auto';

        const zoomBadge = toolbar.createDiv({ cls: 'mermaid-zoom-badge' });
        zoomBadge.style.color = 'var(--text-muted)';
        zoomBadge.style.fontSize = isMobile ? '11px' : '12px';
        zoomBadge.style.fontWeight = '600';
        zoomBadge.style.fontFamily = 'var(--font-monospace-theme, monospace)';
        zoomBadge.style.padding = isMobile ? '2px 4px' : '4px 8px';
        zoomBadge.style.display = 'flex';
        zoomBadge.style.alignItems = 'center';
        this.zoomBadge = zoomBadge;

        const createButton = (title, iconSvg, onClick) => {
            const btn = toolbar.createEl('button', { cls: 'mermaid-toolbar-btn' });
            btn.title = title;
            btn.innerHTML = iconSvg;
            btn.style.background = 'transparent';
            btn.style.border = 'none';
            btn.style.borderRadius = '6px';
            btn.style.padding = isMobile ? '5px 6px' : '6px 8px';
            btn.style.color = 'var(--text-muted)';
            btn.style.cursor = 'pointer';
            btn.style.display = 'inline-flex';
            btn.style.alignItems = 'center';
            btn.style.justifyContent = 'center';
            btn.style.transition = 'all 120ms ease';

            btn.addEventListener('mouseenter', () => {
                btn.style.color = 'var(--text-normal)';
                btn.style.background = 'color-mix(in srgb, var(--interactive-accent) 15%, transparent)';
            });
            btn.addEventListener('mouseleave', () => {
                btn.style.color = 'var(--text-muted)';
                btn.style.background = 'transparent';
            });
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                onClick();
            });
            return btn;
        };

        const zoomInIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/><line x1="11" y1="8" x2="11" y2="14"/><line x1="8" y1="11" x2="14" y2="11"/></svg>`;
        const zoomOutIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/><line x1="8" y1="11" x2="14" y2="11"/></svg>`;
        const fitIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>`;
        const resetIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>`;
        const copyIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`;
        const closeIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="${isMobile ? 14 : 16}" height="${isMobile ? 14 : 16}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>`;

        createButton('Zoom Out (-)', zoomOutIcon, () => this.zoom(0.8));
        createButton('Zoom In (+)', zoomInIcon, () => this.zoom(1.25));
        createButton('Fit to Screen (F)', fitIcon, () => this.fitToScreen());
        createButton('Reset 100% (0)', resetIcon, () => this.resetTransform());
        if (!isMobile) {
            createButton('Copy SVG', copyIcon, () => this.copySvg());
        }
        createButton('Close (ESC)', closeIcon, () => this.close());

        // Dynamic Mermaid Container Wrapper
        const outerWrapper = contentEl.createDiv({ cls: `markdown-preview-view markdown-rendered ${themeClass}` });
        outerWrapper.style.width = '100%';
        outerWrapper.style.height = '100%';
        outerWrapper.style.display = 'flex';
        outerWrapper.style.alignItems = 'center';
        outerWrapper.style.justifyContent = 'center';
        outerWrapper.style.background = 'transparent';
        outerWrapper.style.overflow = 'hidden';
        outerWrapper.style.touchAction = 'none';
        outerWrapper.style.userSelect = 'none';

        this.viewport = outerWrapper.createDiv({ cls: 'block-language-mermaid mermaid' });
        this.viewport.style.transformOrigin = 'center center';
        this.viewport.style.transition = 'transform 60ms ease-out';
        this.viewport.style.display = 'flex';
        this.viewport.style.alignItems = 'center';
        this.viewport.style.justifyContent = 'center';
        this.viewport.style.background = 'transparent';
        this.viewport.style.border = 'none';
        this.viewport.style.padding = '0';
        this.viewport.style.margin = '0';
        this.viewport.style.cursor = 'grab';
        this.viewport.style.touchAction = 'none';
        this.viewport.style.userSelect = 'none';

        // Clone the exact pristine SVG without altering internal styles
        const clonedSvg = this.sourceSvg.cloneNode(true);
        clonedSvg.style.maxWidth = 'none';
        clonedSvg.style.maxHeight = 'none';
        clonedSvg.style.display = 'block';
        clonedSvg.style.pointerEvents = 'none';
        clonedSvg.style.touchAction = 'none';

        // Extract native SVG dimensions
        let measuredW = 800;
        let measuredH = 600;

        if (clonedSvg.viewBox && clonedSvg.viewBox.baseVal && clonedSvg.viewBox.baseVal.width > 0) {
            measuredW = clonedSvg.viewBox.baseVal.width;
            measuredH = clonedSvg.viewBox.baseVal.height;
        } else if (clonedSvg.hasAttribute('viewBox')) {
            const vb = clonedSvg.getAttribute('viewBox').split(/[\s,]+/);
            if (vb.length === 4) {
                const w = parseFloat(vb[2]);
                const h = parseFloat(vb[3]);
                if (w > 0 && h > 0) {
                    measuredW = w;
                    measuredH = h;
                }
            }
        } else if (this.sourceSvg.getBBox) {
            try {
                const bbox = this.sourceSvg.getBBox();
                if (bbox.width > 0 && bbox.height > 0) {
                    measuredW = bbox.width;
                    measuredH = bbox.height;
                }
            } catch (e) {}
        } else if (this.sourceSvg.getBoundingClientRect) {
            const rect = this.sourceSvg.getBoundingClientRect();
            if (rect.width > 0 && rect.height > 0) {
                measuredW = rect.width;
                measuredH = rect.height;
            }
        }

        this.svgWidth = measuredW;
        this.svgHeight = measuredH;
        clonedSvg.style.width = `${measuredW}px`;
        clonedSvg.style.height = `${measuredH}px`;

        this.viewport.appendChild(clonedSvg);

        // Calculate initial auto-fit scale
        const containerW = window.innerWidth * (isMobile ? 0.94 : 0.90);
        const containerH = window.innerHeight * (isMobile ? 0.84 : 0.86);
        const scaleW = containerW / measuredW;
        const scaleH = containerH / measuredH;
        const fitScale = Math.min(scaleW, scaleH);

        this.initialScale = Math.min(Math.max(fitScale, 0.2), 1.0);
        this.scale = this.initialScale;
        this.panX = 0;
        this.panY = 0;
        this.applyTransform();

        // ---------------- POINTER EVENTS GESTURE ENGINE ----------------
        const getDistance = (p1, p2) => Math.hypot(p1.x - p2.x, p1.y - p2.y);

        this.pointerDownHandler = (e) => {
            if (e.target.closest('.mermaid-lightbox-toolbar')) return;
            e.preventDefault();
            e.stopPropagation();

            try {
                contentEl.setPointerCapture(e.pointerId);
            } catch (err) {}

            // Double-tap zoom toggle
            const now = Date.now();
            if (this.pointers.size === 0 && now - this.lastTapTime < 300) {
                this.lastTapTime = 0;
                if (Math.abs(this.scale - 1.0) < 0.08) {
                    this.fitToScreen();
                } else {
                    this.scale = 1.0;
                    this.panX = 0;
                    this.panY = 0;
                    this.applyTransform();
                }
                return;
            }
            this.lastTapTime = now;

            this.pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

            if (this.pointers.size === 1) {
                contentEl.style.cursor = 'grabbing';
                if (this.viewport) this.viewport.style.cursor = 'grabbing';
            } else if (this.pointers.size === 2) {
                const [p1, p2] = Array.from(this.pointers.values());
                this.initialDistance = getDistance(p1, p2);
                this.initialScaleAtPinch = this.scale;
            }
        };

        this.pointerMoveHandler = (e) => {
            if (!this.pointers.has(e.pointerId)) return;
            e.preventDefault();
            e.stopPropagation();

            const prevPos = this.pointers.get(e.pointerId);
            const currentPos = { x: e.clientX, y: e.clientY };
            this.pointers.set(e.pointerId, currentPos);

            if (this.pointers.size === 1) {
                // 1-Finger Pan
                const deltaX = currentPos.x - prevPos.x;
                const deltaY = currentPos.y - prevPos.y;
                this.panX += deltaX;
                this.panY += deltaY;
                this.applyTransform();
            } else if (this.pointers.size === 2) {
                // 2-Finger Pinch-to-Zoom
                const [p1, p2] = Array.from(this.pointers.values());
                const currentDist = getDistance(p1, p2);
                if (this.initialDistance > 0 && currentDist > 0) {
                    const ratio = currentDist / this.initialDistance;
                    this.scale = Math.min(Math.max(this.initialScaleAtPinch * ratio, 0.15), 6.0);
                    this.applyTransform();
                }
            }
        };

        this.pointerUpHandler = (e) => {
            if (this.pointers.has(e.pointerId)) {
                this.pointers.delete(e.pointerId);
                try {
                    contentEl.releasePointerCapture(e.pointerId);
                } catch (err) {}
            }

            if (this.pointers.size === 0) {
                contentEl.style.cursor = 'grab';
                if (this.viewport) this.viewport.style.cursor = 'grab';
            } else if (this.pointers.size === 1) {
                // Update position of remaining pointer to prevent jump
                const [remId, remPos] = Array.from(this.pointers.entries())[0];
                this.pointers.set(remId, remPos);
            }
        };

        contentEl.addEventListener('pointerdown', this.pointerDownHandler);
        contentEl.addEventListener('pointermove', this.pointerMoveHandler);
        contentEl.addEventListener('pointerup', this.pointerUpHandler);
        contentEl.addEventListener('pointercancel', this.pointerUpHandler);

        // Fallback touch event blocking to prevent iOS/Android rubber-banding
        this.touchPreventHandler = (e) => {
            if (e.target.closest('.mermaid-lightbox-toolbar')) return;
            e.preventDefault();
            e.stopPropagation();
        };
        contentEl.addEventListener('touchmove', this.touchPreventHandler, { passive: false });

        // Mouse Wheel Zoom
        this.wheelHandler = (e) => {
            e.preventDefault();
            e.stopPropagation();
            const factor = e.deltaY < 0 ? 1.15 : 0.87;
            this.zoom(factor);
        };
        contentEl.addEventListener('wheel', this.wheelHandler, { passive: false });

        // Keyboard Shortcuts
        this.keyHandler = (e) => {
            if (e.key === '+' || e.key === '=') this.zoom(1.2);
            if (e.key === '-' || e.key === '_') this.zoom(0.83);
            if (e.key === '0') this.resetTransform();
            if (e.key === 'f' || e.key === 'F') this.fitToScreen();
        };
        window.addEventListener('keydown', this.keyHandler);
    }

    zoom(factor) {
        this.scale = Math.min(Math.max(this.scale * factor, 0.15), 6.0);
        this.applyTransform();
    }

    fitToScreen() {
        const isMobile = window.innerWidth <= 768;
        const containerW = window.innerWidth * (isMobile ? 0.94 : 0.90);
        const containerH = window.innerHeight * (isMobile ? 0.84 : 0.86);
        const scaleW = containerW / (this.svgWidth || 800);
        const scaleH = containerH / (this.svgHeight || 600);
        this.scale = Math.min(Math.max(Math.min(scaleW, scaleH), 0.2), 1.15);
        this.panX = 0;
        this.panY = 0;
        this.applyTransform();
    }

    resetTransform() {
        this.scale = 1.0;
        this.panX = 0;
        this.panY = 0;
        this.applyTransform();
    }

    applyTransform() {
        if (this.viewport) {
            this.viewport.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.scale})`;
        }
        if (this.zoomBadge) {
            this.zoomBadge.textContent = `${Math.round(this.scale * 100)}%`;
        }
    }

    async copySvg() {
        try {
            const svgText = this.sourceSvg.outerHTML;
            await navigator.clipboard.writeText(svgText);
            new Notice('Mermaid SVG copied to clipboard');
        } catch (err) {
            new Notice('Failed to copy SVG');
        }
    }

    onClose() {
        if (this.pointerDownHandler) this.contentEl.removeEventListener('pointerdown', this.pointerDownHandler);
        if (this.pointerMoveHandler) this.contentEl.removeEventListener('pointermove', this.pointerMoveHandler);
        if (this.pointerUpHandler) {
            this.contentEl.removeEventListener('pointerup', this.pointerUpHandler);
            this.contentEl.removeEventListener('pointercancel', this.pointerUpHandler);
        }
        if (this.touchPreventHandler) this.contentEl.removeEventListener('touchmove', this.touchPreventHandler);
        if (this.wheelHandler) this.contentEl.removeEventListener('wheel', this.wheelHandler);
        if (this.keyHandler) window.removeEventListener('keydown', this.keyHandler);
        this.pointers.clear();
        this.contentEl.empty();
    }
}

module.exports = class MermaidFullscreenPlugin extends Plugin {
    async onload() {
        this.registerDomEvent(document, 'click', (evt) => {
            if (evt.target.closest('.mermaid-lightbox-toolbar') || evt.target.closest('.copy-code-button')) {
                return;
            }

            if (evt.target.closest('.mermaid-lightbox-modal')) return;

            const mermaidContainer = evt.target.closest('.block-language-mermaid, .mermaid, .cm-embed-block:has(.mermaid)');
            if (!mermaidContainer) return;

            const svg = mermaidContainer.querySelector('svg');
            if (svg) {
                evt.preventDefault();
                evt.stopPropagation();
                new MermaidLightboxModal(this.app, mermaidContainer, svg).open();
            }
        });
    }

    onunload() {}
};
