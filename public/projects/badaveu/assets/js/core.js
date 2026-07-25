/**
 * BadaVeu — core.js
 * Utilitats compartides entre app.js i admin.js.
 * Ha de carregar-se ABANS que app.js i admin.js.
 */

// ── XSS protection ────────────────────────────────────────────────────────────
function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

// ── Barris estàtics de Badalona per districte ─────────────────────────────────
const BADALONA_BARRIOS_ESTATICOS = {
    'Districte 1': ['Centre', 'Dalt la Vila', 'Coll i Pujol', 'Casagemes', 'Progrés', 'El Manresà'],
    'Districte 2': ['Sant Crist de Can Cabanyes', 'El Remei', 'Sistrells'],
    'Districte 3': ['La Salut', 'Gorg', 'La Mora', 'Congrés', 'Pep Ventura'],
    'Districte 4': ['Canyadó', 'Morera', 'Pomar de Dalt', 'Sant Joan de Llefià', 'El Raval', 'El Guindó'],
    'Districte 5': ['Sant Roc', 'Artigues', 'Llefià', 'La Llibertat', 'Nova Lloreda', 'Sant Antoni de Llefià'],
    'Districte 6': ['Bufalà', 'Canyet', 'Mas Ram', 'Montigalà'],
    'Districte 7': ['Les Guixeres', 'Bon Pastor', 'Can Ruti'],
};

// ── Tile layer ────────────────────────────────────────────────────────────────
const CARTO_TILE_URL = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

// ── Chart helper ──────────────────────────────────────────────────────────────
/**
 * Destroys any existing Chart.js instance on a canvas before recreating it.
 * Accepts either the canvas element or a CanvasRenderingContext2D.
 */
function destroyExistingChart(canvasOrCtx) {
    const canvas = (canvasOrCtx instanceof HTMLCanvasElement)
        ? canvasOrCtx
        : canvasOrCtx?.canvas;
    if (!canvas) return;
    const existing = (typeof Chart !== 'undefined') && Chart.getChart(canvas);
    if (existing) existing.destroy();
}

// ── Badge helpers (desduplicats d'app.js i admin.js) ─────────────────────────

/**
 * Returns the WCAG-AA-compliant background color for a status badge.
 * All colors pass ≥4.5:1 contrast with white text.
 */
function getStatusBadgeColor(estado, categoria) {
    if (estado === 'resuelto') return '#047857';      // emerald-700  ~5.9:1
    if (categoria === 'denuncia') return '#dc2626';   // red-600      ~5.9:1
    if (estado === 'proceso')  return '#b45309';      // amber-700    ~7.3:1
    return '#002D5A';                                 // primary      ~14.7:1
}

/**
 * Returns the i18n key label for a status value.
 * Falls back to a Catalan default if the i18n object is unavailable.
 */
function getStatusLabel(estado, i18n, lang) {
    const fallback = { pendiente: 'Pendent', proceso: 'En Procés', resuelto: 'Resolt', denegado: 'Denegat' };
    if (i18n && lang && i18n[lang]) return i18n[lang][`status_${estado}`] || fallback[estado] || estado;
    return fallback[estado] || estado;
}
