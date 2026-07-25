/**
 * BadaVeu – La Voz de Badalona — Admin Module
 * Contiene toda la lógica específica para el panel de administración.
 * Extiende el objeto 'app' definido en app.js.
 */

// 1. PROPIEDADES ESPECÍFICAS DE ADMIN (Añadidas al objeto 'app' de app.js)
app.adminIncidents = []; 
app.adminUsers = []; 
app.adminRole = null; 
app.activeAdminTab = 'stats'; 
app.detailMap = null; // Mapa del panel de detalle

// Nuevo: Mapa Avanzado del Admin
app.adminMap = null;
app.adminMapMarkers = L.layerGroup();
app.adminMapFilters = {
    status: 'all',
    category: 'all',
    urgency: 'all',
    afectacion: 'all',
    votos: 'all'
};

app.adminFilters = {
    status: 'all',
    category: 'all',
    barri: 'all',
    search: ''      
};

// 2. FUNCIONES DE INICIALIZACIÓN Y AUTH (Añadidas a 'app')

app.updateAdminNav = function() {
    const sidebarNav = document.getElementById('admin-tabs');
    const mobileNav = document.getElementById('admin-tabs-mobile-nav');
    const tabButtons = sidebarNav.innerHTML;

    // Poblar navegación móvil si existe
    if (mobileNav) {
        mobileNav.innerHTML = tabButtons;
        
        // Re-adjuntar eventos a los nuevos botones de móvil (si se clona)
        mobileNav.querySelectorAll('.admin-tab-btn').forEach(btn => {
             btn.onclick = () => app.setActiveAdminTab(btn.getAttribute('data-tab'));
        });
    }

    // Ocultar botón de usuarios si no es Superadmin
    const tabUsersBtn = document.getElementById('tab-users-btn');
    const isSuperadmin = app.adminRole === 'superadmin';
    if (tabUsersBtn) {
        tabUsersBtn.style.display = isSuperadmin ? '' : 'none';
        
        const tabUsersBtnMobile = mobileNav?.querySelector('[data-tab="users"]');
        if (tabUsersBtnMobile) tabUsersBtnMobile.style.display = isSuperadmin ? '' : 'none';
    }
};

app.setActiveAdminTab = function(tabName) {
    // 1. Actualizar botones de navegación (Sidebar y Móvil)
    const tabsContainer = document.getElementById('admin-tabs');
    const tabsMobileContainer = document.getElementById('admin-tabs-mobile-nav');
    const allTabBtns = [...tabsContainer.querySelectorAll('.admin-tab-btn'), ...tabsMobileContainer?.querySelectorAll('.admin-tab-btn') || []];

    allTabBtns.forEach(btn => {
        if (btn.getAttribute('data-tab') === tabName) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // 2. Actualizar contenido
    document.querySelectorAll('.admin-tab-content').forEach(content => content.classList.add('hidden'));
    const activeContent = document.getElementById(`tab-${tabName}-content`);
    if (activeContent) activeContent.classList.remove('hidden');
    
    // 3. Actualizar título de la cabecera
    const titleElement = document.getElementById('current-tab-title');
    if (titleElement) {
        const titleKey = `admin_tab_${tabName}`;
        titleElement.textContent = app.i18n[app.lang][titleKey] || tabName.toUpperCase();
    }
    
    // 4. Mostrar/Ocultar botón de crear usuario (LOGIC REMOVED/MOVED)
    // NOTA: El botón #createUserBtn ya no está en el header y se gestiona en loadUserManagement.

    this.activeAdminTab = tabName;
    
    // 5. Cargar datos específicos e inicializar mapa
    if (tabName === 'incidents') {
        this.loadAdminData();
    } else if (tabName === 'stats') {
        this.loadAdminStats();
    } else if (tabName === 'users') {
        this.loadUserManagement();
    } else if (tabName === 'map') {
        this.initAdminMap();
    } else if (tabName === 'priority') {
        this.loadPriorityView();
    } else if (tabName === 'activity') {
        this.loadActivityLog(1);
    }
};

app.handleUnauthorized = function() {
    const adminLogin = document.getElementById('admin-login');
    const adminDashboard = document.getElementById('admin-dashboard');
    if (adminDashboard) adminDashboard.classList.add('hidden');
    if (adminLogin) adminLogin.classList.remove('hidden');
    if (typeof ui !== 'undefined' && ui.showToast) {
        ui.showToast('Sessió expirada. Si us plau, torna a entrar.', 'error', 5000);
    }
};

// ── Centralised fetch wrapper ─────────────────────────────────────────────────
// Handles: CSRF injection for POST, credentials, 401/403 → login redirect, JSON parsing.
app.adminFetch = async function(url, options = {}) {
    const method = (options.method || 'GET').toUpperCase();
    options.credentials = 'same-origin';

    if (method === 'POST') {
        const token = await this.getCsrfToken();
        if (options.body instanceof FormData) {
            if (!options.body.has('_csrf_token')) options.body.set('_csrf_token', token);
        } else {
            options.headers = { ...(options.headers || {}), 'X-CSRF-Token': token };
        }
    }

    const res = await fetch(url, options);

    if (res.status === 401 || res.status === 403) {
        this.handleUnauthorized();
        const err = new Error('SESSION_EXPIRED');
        err.code  = 'AUTH';
        throw err;
    }

    // Non-JSON (e.g. CSV export) — return raw Response for the caller
    const ct = res.headers.get('content-type') || '';
    if (!ct.includes('application/json')) return res;

    const json = await res.json();
    if (!res.ok) throw new Error(json.message || `HTTP ${res.status}`);
    return json;
};

// ── Dark Mode ─────────────────────────────────────────────────────────────────
app.toggleDarkMode = function() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const next   = isDark ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('admin_theme', next);
    const btn = document.getElementById('btn-dark-mode');
    if (btn) btn.innerHTML = next === 'dark'
        ? '<i class="ri-sun-line"></i>'
        : '<i class="ri-moon-line"></i>';
};

app.initAdminTheme = function() {
    const saved = localStorage.getItem('admin_theme')
        ?? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    document.documentElement.setAttribute('data-theme', saved);
    const btn = document.getElementById('btn-dark-mode');
    if (btn) btn.innerHTML = saved === 'dark'
        ? '<i class="ri-sun-line"></i>'
        : '<i class="ri-moon-line"></i>';
};

app.checkAdminAuth = async function() {
    const loadingScreen = document.getElementById('loading-screen');
    const adminLogin = document.getElementById('admin-login');
    const adminDashboard = document.getElementById('admin-dashboard');
    const loginMessage = document.getElementById('loginMessage');
    const username = localStorage.getItem('admin_username') || 'Admin';

    if (loadingScreen) loadingScreen.style.display = 'flex';

    try {
        const json = await app.adminFetch('api/index.php?action=check_auth');

        if (json.logged_in) {
            app.adminRole = json.admin_role;

            // Avatar initials
            const initials = username.split('@')[0].substring(0, 2).toUpperCase();
            ['sidebar-avatar-initials', 'topbar-avatar'].forEach(id => {
                const el = document.getElementById(id);
                if (el) el.textContent = initials;
            });

            // Role badge labels
            const roleLabels = { superadmin: 'Superadmin', admin: 'Admin', moderator: 'Moderador' };
            const roleLabel = roleLabels[json.admin_role] || json.admin_role || 'Usuari';
            const sidebarRole = document.getElementById('sidebar-role-label');
            if (sidebarRole) sidebarRole.textContent = roleLabel;

            // User display
            const displayName = username.split('@')[0];
            document.getElementById('admin-user-display-pc').textContent = displayName;
            document.getElementById('admin-user-display-mobile').textContent = displayName;

            app.updateAdminNav();

            if (adminDashboard) adminDashboard.classList.remove('hidden');
            if (adminLogin) adminLogin.classList.add('hidden');

            app.initTopbarClock();
            app.setActiveAdminTab('stats');
            app.startAutoRefresh();
        } else {
            if (adminDashboard) adminDashboard.classList.add('hidden');
            if (adminLogin) adminLogin.classList.remove('hidden');
            if (loginMessage) loginMessage.textContent = '';
        }
    } catch(e) {
        if (loginMessage) loginMessage.textContent = "Error de connexió amb el servidor.";
        if (adminLogin) adminLogin.classList.remove('hidden');
    } finally {
        if (loadingScreen) loadingScreen.style.display = 'none';
    }
};

app.initTopbarClock = function() {
    const updateClock = () => {
        const el = document.getElementById('topbar-date-text');
        if (!el) return;
        const now = new Date();
        el.textContent = now.toLocaleDateString('ca-ES', {
            weekday: 'short', day: 'numeric', month: 'short'
        }) + ' · ' + now.toLocaleTimeString('ca-ES', { hour: '2-digit', minute: '2-digit' });
    };
    updateClock();
    setInterval(updateClock, 30000);
};

app.handleAdminLogin = async function(e) {
    e.preventDefault();
    const form = e.target;
    const btn = form.querySelector('button');
    const originalText = btn.innerHTML;
    const username = form.querySelector('input[name="usuario"]').value;
    const loginMessage = document.getElementById('loginMessage');
    
    btn.disabled = true;
    btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Entrant...';
    if(loginMessage) loginMessage.textContent = '';

    try {
        const formData = new FormData(form);
        const res = await fetch('api/index.php?action=login', { method: 'POST', body: formData });
        
        const errorText = await res.text();
        
        if (!res.ok) {
            let message = "Error desconegut en iniciar sessió.";
            try {
                const json = JSON.parse(errorText);
                message = json.message || `Error de servidor: ${res.status}`;
            } catch {
                message = `Error ${res.status}: Error de servidor. Reviseu els logs PHP.`;
            }
            if (loginMessage) loginMessage.textContent = message;
            return;
        }

        const json = JSON.parse(errorText);
        
        if (json.status === 'success') {
            localStorage.setItem('admin_username', username);
            app.checkAdminAuth(); 
        } else {
            if (loginMessage) loginMessage.textContent = json.message || 'Error de autenticación.';
        }
    } catch (e) {
        if (loginMessage) loginMessage.textContent = 'Error de conexión al servidor.';
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
};

app.handleAdminLogout = async function() {
    try { await fetch('api/index.php?action=logout'); } catch (_) { /* always proceed */ }
    localStorage.removeItem('admin_username');
    location.reload();
};

// 3. GESTIÓN DE INCIDENCIAS (Añadidas a 'app')

app.exportCsv = function() {
    const s = app.adminFilters.status   || 'all';
    const c = app.adminFilters.category || 'all';
    window.open(`api/index.php?action=export_csv&status=${encodeURIComponent(s)}&category=${encodeURIComponent(c)}`, '_blank');
};

function showAdminSkeletons(container, n = 5) {
    const tableRow = () => `
        <div class="sk-table-row">
            <div class="sk-line skeleton" style="width:32px;height:32px;border-radius:50%;flex-shrink:0;margin:0;"></div>
            <div style="flex:1;display:flex;flex-direction:column;gap:6px;">
                <div class="sk-line w-75 skeleton" style="margin:0;"></div>
                <div class="sk-line w-50 skeleton" style="margin:0;height:9px;"></div>
            </div>
            <div class="sk-line skeleton" style="width:70px;height:22px;border-radius:12px;margin:0;flex-shrink:0;"></div>
            <div class="sk-line skeleton" style="width:80px;height:22px;border-radius:12px;margin:0;flex-shrink:0;"></div>
        </div>`;
    container.innerHTML = `<div class="sk-table-card">${Array(n).fill(tableRow()).join('')}</div>`;
}

function showStatsSkeletons(container) {
    const kpiSk = Array(4).fill(`
        <div class="sk-kpi">
            <div class="sk-kpi-icon skeleton"></div>
            <div class="sk-kpi-body">
                <div class="sk-line w-50 h-big skeleton"></div>
                <div class="sk-line w-30 h-small skeleton" style="margin-top:8px;"></div>
            </div>
        </div>`).join('');
    const chartSk = `
        <div class="sk-card" style="height:220px;display:flex;align-items:center;justify-content:center;">
            <div class="sk-line w-full skeleton" style="height:100%;border-radius:var(--r-sm);"></div>
        </div>`;
    container.innerHTML = `
        <div class="stats-kpi-row">${kpiSk}</div>
        <div class="chart-duo">${chartSk}${chartSk}</div>
        <div class="chart-duo">${chartSk}${chartSk}</div>`;
}

app.loadAdminData = async function() {
    const listContainer = document.getElementById('incident-list');
    this.adminFilters.status   = document.getElementById('filter-status')?.value    || 'all';
    this.adminFilters.category = document.getElementById('filter-category')?.value  || 'all';
    this.adminFilters.barri    = document.getElementById('filter-barri-admin')?.value || 'all';
    this.adminFilters.search   = document.getElementById('filter-search')?.value.toLowerCase() || '';

    if (listContainer && this.activeAdminTab === 'incidents') {
        showAdminSkeletons(listContainer);
    }

    try {
        const json = await app.adminFetch('api/index.php?action=admin_data');
        if (json.status === 'success') {
            app.adminIncidents = json.data;
            app.populateAdminFilterBarrios();
            app.renderAdminList();
            app.renderKPIs(app.adminIncidents);
            if (app.activeAdminTab === 'map' && app.adminMap) {
                app.drawAdminMapMarkers();
            }
        } else {
            if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color:var(--danger);">Error carregant dades: ${json.message}</p>`;
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color:var(--danger);">Error de connexió: ${e.message}</p>`;
    }
};

app.populateAdminFilterBarrios = function() {
    const filterBarriSelect = document.getElementById('filter-barri-admin');
    if (!filterBarriSelect) return;
    
    const currentBarri = filterBarriSelect.value;
    filterBarriSelect.innerHTML = `<option value="all">${this.i18n[this.lang].filter_barri_all}</option>`;
    
    const existingBarrios = new Set();
    this.adminIncidents.forEach(inc => {
        if (inc.barri && inc.barri !== '') {
            existingBarrios.add(inc.barri);
        }
    });
    
    const districtsWithIncidents = {};
    existingBarrios.forEach(barri => {
        const districteNum = this.BARRIOS_MAP[barri];
        const districteLabel = districteNum ? ('Districte ' + districteNum) : 'Sense Districte';

        if (!districtsWithIncidents[districteLabel]) {
            districtsWithIncidents[districteLabel] = [];
        }
        districtsWithIncidents[districteLabel].push(barri);
    });
    
    for (const districteLabel in districtsWithIncidents) {
        districtsWithIncidents[districteLabel].sort(); 
        
        const optgroup = document.createElement('optgroup');
        optgroup.label = districteLabel;
        
        districtsWithIncidents[districteLabel].forEach(barri => {
            const option = document.createElement('option');
            option.value = barri;
            option.textContent = barri;
            optgroup.appendChild(option);
        });
         filterBarriSelect.appendChild(optgroup);
    }
    
    filterBarriSelect.value = currentBarri || 'all';
};

app.renderAdminList = function() {
    const listContainer = document.getElementById('incident-list');
    if (!listContainer) return;

    listContainer.innerHTML = '';
    const filters = this.adminFilters;
    
    let filteredData = app.adminIncidents.filter(inc => {
        const matchesStatus = filters.status === 'all' || inc.estado === filters.status;
        const matchesCategory = filters.category === 'all' || inc.categoria === filters.category;
        const matchesBarri = filters.barri === 'all' || inc.barri === filters.barri;
        
        const matchesSearch = filters.search === '' ||
                              inc.titulo.toLowerCase().includes(filters.search) ||
                              inc.descripcion.toLowerCase().includes(filters.search);

        return matchesStatus && matchesCategory && matchesBarri && matchesSearch;
    });
    
    if (filteredData.length === 0) {
        listContainer.innerHTML = `
            <div class="empty-state">
                <i class="ri-inbox-line"></i>
                <h3>Cap incidència trobada</h3>
                <p>Prova canviant els filtres o espera que arribin nous reports.</p>
            </div>`;
        return;
    }
    
    const SLA_HOURS = 48;
    const now = Date.now();

    // Helper: retorna les hores transcorregudes i si supera el SLA de 48h
    const slaInfo = (inc) => {
        if (inc.estado !== 'pendiente' || !inc.created_at) return { overdue: false, hours: 0 };
        const hours = Math.floor((now - new Date(inc.created_at).getTime()) / 3600000);
        return { overdue: hours > SLA_HOURS, hours };
    };

    // Vista de Escritorio: Tabla
    const tableHTML = `
        <div class="table-wrapper desktop-table-view">
            <table class="incident-table">
                <thead>
                    <tr>
                        <th class="bulk-th" style="width:3%;"><input type="checkbox" id="select-all-cb" class="bulk-cb" aria-label="Seleccionar totes les incidències" onchange="app.toggleSelectAll(this.checked)" onclick="event.stopPropagation()"></th>
                        <th style="width: 5%;">ID</th>
                        <th style="width: 25%;">Títol / Descripció</th>
                        <th style="width: 15%;">Ubicació / Barri</th>
                        <th style="width: 10%;">Tipus</th>
                        <th style="width: 10%;">Urgència</th>
                        <th style="width: 5%;">Vots</th>
                        <th style="width: 10%;">Estat</th>
                        <th style="width: 10%;">Acció</th>
                    </tr>
                </thead>
                <tbody>
                    ${filteredData.map(inc => {
                        const statusLabel = app.i18n[app.lang][`status_${inc.estado}`] || 'Estat Desconegut';
                        const categoryLabel = inc.categoria === 'infraestructura' ? app.i18n[app.lang].cat_infra : app.i18n[app.lang].cat_denuncia;
                        const formattedDate = app.formatDate(inc.created_at);
                        const shortDesc = inc.descripcion.substring(0, 50) + '...';
                        const urgencyLabel = app.i18n[app.lang][`urg_${inc.urgencia}`] || inc.urgencia || 'Baixa';
                        const votes = inc.votos || 0;
                        const sla = slaInfo(inc);
                        const slaBadge = sla.overdue
                            ? `<span class="sla-badge" title="Pendent fa ${sla.hours}h (SLA: ${SLA_HOURS}h)"><i class="ri-alarm-warning-line"></i> Prioritat Crítica</span>`
                            : '';

                        return `
                            <tr class="${sla.overdue ? 'sla-overdue' : ''}" onclick="app.openDetailPanel(${inc.id})">
                                <td class="bulk-td" onclick="event.stopPropagation()"><input type="checkbox" class="row-select-cb bulk-cb" value="${inc.id}" aria-label="Seleccionar incidència #${inc.id}" onchange="app.toggleIncidentSelection(${inc.id}, this.checked)"></td>
                                <td>#${inc.id}<br><small>${escapeHtml(formattedDate.split(',')[0])}</small>${slaBadge}</td>
                                <td><strong>${escapeHtml(inc.titulo)}</strong><br><small>${escapeHtml(shortDesc)}</small></td>
                                <td>${escapeHtml(inc.direccion || 'Desconeguda')}<br><small>${escapeHtml(inc.barri)} (D${escapeHtml(inc.districte || '?')})</small></td>
                                <td>${escapeHtml(categoryLabel)}<br><small>${escapeHtml(inc.tipo)}</small></td>
                                <td><span class="urgency-pill urgency-${escapeHtml(inc.urgencia)}">${escapeHtml(urgencyLabel.toUpperCase())}</span></td>
                                <td>${votes}</td>
                                <td class="status-cell">
                                    <span class="card-status status-${escapeHtml(inc.estado)}">${escapeHtml(statusLabel.toUpperCase())}</span>
                                </td>
                                <td><button class="btn-sm btn-primary">Detalls</button></td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        </div>
    `;

    // Vista Móvil: Tarjetas
    const cardHTML = filteredData.map(inc => {
        const statusLabel = app.i18n[app.lang][`status_${inc.estado}`] || 'Estat Desconegut';
        const categoryLabel = inc.categoria === 'infraestructura' ? app.i18n[app.lang].cat_infra : app.i18n[app.lang].cat_denuncia;
        const formattedDate = app.formatDate(inc.created_at);
        const urgencyLabel = app.i18n[app.lang][`urg_${inc.urgencia}`] || inc.urgencia || 'Baixa';
        const votes = inc.votos || 0;
        const sla = slaInfo(inc);
        const slaBadge = sla.overdue
            ? `<span class="sla-badge" style="margin-left:6px;" title="Pendent fa ${sla.hours}h (SLA: ${SLA_HOURS}h)"><i class="ri-alarm-warning-line"></i> Prioritat Crítica</span>`
            : '';

        return `
            <div class="incident-card-admin mobile-card-view ${sla.overdue ? 'sla-overdue' : ''}" onclick="app.openDetailPanel(${inc.id})" style="position:relative;">
                <input type="checkbox" class="row-select-cb mobile-card-cb bulk-cb" value="${inc.id}" aria-label="Seleccionar incidència #${inc.id}" onchange="app.toggleIncidentSelection(${inc.id}, this.checked)" onclick="event.stopPropagation()" style="position:absolute;top:14px;left:14px;z-index:2;width:18px;height:18px;cursor:pointer;">
                <div class="card-header-admin" style="display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:6px;">
                    <div style="display:flex; align-items:center; gap:6px; flex-wrap:wrap;">
                        <span class="card-status status-${escapeHtml(inc.estado)}">${escapeHtml(statusLabel.toUpperCase())}</span>
                        ${slaBadge}
                    </div>
                    <div style="display:flex; gap:10px; align-items:center;">
                        <span class="card-category text-muted">${escapeHtml(categoryLabel)}</span>
                        <span class="urgency-pill urgency-${escapeHtml(inc.urgencia)}">${escapeHtml(urgencyLabel.toUpperCase())}</span>
                    </div>
                </div>
                <h4 class="card-title-admin" style="margin: 10px 0 5px 0; font-size:1.1rem;">${escapeHtml(inc.titulo)} <small style="color:var(--text-secondary); font-weight:400;">(#${inc.id})</small></h4>
                <p class="card-location-admin text-muted" style="margin-bottom: 5px;"><i class="ri-map-pin-line"></i> ${escapeHtml(inc.barri || 'Sense Barri')}</p>
                <p class="card-meta-admin text-muted" style="font-size:0.8rem;"><i class="ri-calendar-line"></i> ${escapeHtml(formattedDate)}</p>
                <div class="card-votes-admin" style="position: absolute; top: 15px; right: 15px; font-weight:700; color:var(--text-secondary);">
                    <i class="ri-thumb-up-fill"></i> ${votes}
                </div>
            </div>
        `;
    }).join('');

    listContainer.innerHTML = tableHTML + cardHTML;
};

app.openDetailPanel = function(id) {
    const incident = app.adminIncidents.find(i => i.id === id);
    if (!incident) return;

    const panel = document.getElementById('detail-panel');
    const content = document.getElementById('detail-content');
    
    const statusLabel = app.i18n[app.lang][`status_${incident.estado}`].toUpperCase();
    const categoryLabel = incident.categoria === 'infraestructura' ? app.i18n[app.lang].cat_infra : app.i18n[app.lang].cat_denuncia;
    
    const statusOptions = ['pendiente', 'proceso', 'resuelto'].map(status => {
        const label = app.i18n[app.lang][`status_${status}`];
        const selected = status === incident.estado ? 'selected' : '';
        return `<option value="${status}" ${selected}>${label}</option>`;
    }).join('');
    
    const urgencyLabel = app.i18n[app.lang][`urg_${incident.urgencia}`] || app.i18n[app.lang].urg_low; // Default a Baja si es nulo

    if (content) content.innerHTML = `
        <div class="detail-header-admin">
            <div class="detail-header-status-row">
                <span class="card-status status-${escapeHtml(incident.estado)}">${escapeHtml(statusLabel)}</span>
                <span class="urgency-pill urgency-${escapeHtml(incident.urgencia)}">${escapeHtml(urgencyLabel.toUpperCase())}</span>
                <span class="detail-header-id" style="margin-left:auto;">ID #${incident.id}</span>
            </div>
            <h2 class="detail-header-title">${escapeHtml(incident.titulo)}</h2>
            <p style="font-size:0.78rem;color:var(--text-muted);margin-top:5px;display:flex;align-items:center;gap:5px;">
                <i class="ri-calendar-line"></i> ${escapeHtml(app.formatDate(incident.created_at))}
                <span style="margin:0 4px;">·</span>
                <i class="ri-thumb-up-line"></i> ${incident.votos || 0} suports
            </p>
        </div>

        <div class="detail-content">
            <div id="detailMap" class="detail-map-container"></div>

            <div class="detail-section">
                <div class="detail-section-title"><i class="ri-map-pin-line"></i> Ubicació</div>
                <div class="detail-info-grid">
                    <div class="detail-info-item">
                        <div class="detail-info-label">Adreça</div>
                        <div class="detail-info-value">${escapeHtml(incident.direccion || 'Desconeguda')}</div>
                    </div>
                    <div class="detail-info-item">
                        <div class="detail-info-label">Barri / Districte</div>
                        <div class="detail-info-value">${escapeHtml(incident.barri || '—')} (D${escapeHtml(String(incident.districte || '?'))})</div>
                    </div>
                    <div class="detail-info-item" style="grid-column:1/span 2;">
                        <div class="detail-info-label">Coordenades</div>
                        <div class="detail-info-value" style="font-family:monospace;font-size:0.8rem;">
                            ${Number(incident.lat).toFixed(6)}, ${Number(incident.lng).toFixed(6)}
                        </div>
                    </div>
                </div>
                <a href="https://www.google.com/maps/search/?api=1&query=${incident.lat},${incident.lng}"
                   target="_blank" rel="noopener" class="btn-sm btn-info" style="margin-top:10px;">
                    <i class="ri-direction-line"></i> Veure a Google Maps
                </a>
            </div>

            <div class="detail-section">
                <div class="detail-section-title"><i class="ri-list-check"></i> Detalls de la Incidència</div>
                <div class="detail-info-grid" style="margin-bottom:12px;">
                    <div class="detail-info-item">
                        <div class="detail-info-label">Categoria</div>
                        <div class="detail-info-value">${escapeHtml(categoryLabel)}</div>
                    </div>
                    <div class="detail-info-item">
                        <div class="detail-info-label">Tipus</div>
                        <div class="detail-info-value">${escapeHtml(incident.tipo || '—')}</div>
                    </div>
                    <div class="detail-info-item">
                        <div class="detail-info-label">Afectació</div>
                        <div class="detail-info-value">${escapeHtml(app.i18n[app.lang][`imp_${incident.afectacion}`] || incident.afectacion || '—')}</div>
                    </div>
                    <div class="detail-info-item" style="grid-column:1/span 2;">
                        <div class="detail-info-label">Urgència / Prioritat</div>
                        <div class="urgency-btn-group" id="urgency-control-${incident.id}">
                            <button class="urgency-btn urgency-baja ${incident.urgencia === 'baja' ? 'active' : ''}"
                                    onclick="app.handleUrgencyChange(${incident.id}, 'baja', this)">
                                <i class="ri-arrow-down-line" aria-hidden="true"></i> Baixa
                            </button>
                            <button class="urgency-btn urgency-media ${incident.urgencia === 'media' ? 'active' : ''}"
                                    onclick="app.handleUrgencyChange(${incident.id}, 'media', this)">
                                <i class="ri-subtract-line" aria-hidden="true"></i> Mitja
                            </button>
                            <button class="urgency-btn urgency-alta ${incident.urgencia === 'alta' ? 'active' : ''}"
                                    onclick="app.handleUrgencyChange(${incident.id}, 'alta', this)">
                                <i class="ri-alarm-warning-line" aria-hidden="true"></i> Alta
                            </button>
                        </div>
                    </div>
                </div>
                <div class="detail-info-label" style="margin-bottom:5px;">Descripció</div>
                <p style="font-size:0.88rem;color:var(--text);line-height:1.6;background:var(--bg-main);padding:12px;border-radius:var(--r-sm);border:1px solid var(--border);">
                    ${escapeHtml(incident.descripcion)}
                </p>
            </div>

            ${incident.foto_url ? `
            <div class="detail-section">
                <div class="detail-section-title"><i class="ri-camera-line"></i> Fotografia</div>
                <img src="${incident.foto_url}" class="detail-image" alt="Foto de la incidència" loading="lazy">
                <a href="${incident.foto_url}" target="_blank" rel="noopener" class="btn-sm btn-info" style="margin-top:8px;display:inline-flex;">
                    <i class="ri-zoom-in-line"></i> Veure foto completa
                </a>
            </div>` : ''}

            <div class="detail-section">
                <div class="detail-section-title"><i class="ri-user-line"></i> Ciutadà</div>
                <div class="detail-info-item">
                    <div class="detail-info-label">Correu electrònic</div>
                    <div class="detail-info-value">${incident.email ? `<a href="mailto:${escapeHtml(incident.email)}" style="color:var(--primary)">${escapeHtml(incident.email)}</a>` : '<span style="color:var(--text-muted)">No proporcionat</span>'}</div>
                </div>
            </div>

            <div class="detail-section">
                <div class="detail-section-title"><i class="ri-exchange-box-line"></i> Gestió de l'Estat</div>
                <div class="detail-action-bar">
                    <select id="newStatusSelect-${incident.id}"
                            class="select-status status-${escapeHtml(incident.estado)}"
                            onchange="this.className='select-status status-'+this.value">
                        ${statusOptions}
                    </select>
                    <button class="btn-sm btn-primary"
                            onclick="app.handleStatusChange(${incident.id}, document.getElementById('newStatusSelect-${incident.id}').value, this)">
                        <i class="ri-check-line"></i> Actualitzar
                    </button>
                </div>
                <textarea id="adminComment-${incident.id}" rows="3"
                          class="detail-comment-area" style="margin-top:10px;"
                          placeholder="Comentari intern o missatge per al ciutadà (opcional, apareixerà al timeline públic)..."></textarea>
                <div style="margin-top:14px;padding-top:14px;border-top:1px solid var(--border-light);">
                    <button onclick="app.archiveIncident(${incident.id})"
                            style="width:100%;padding:10px;background:transparent;border:1.5px solid var(--danger);color:var(--danger);border-radius:var(--r-sm);font-weight:600;cursor:pointer;display:flex;align-items:center;justify-content:center;gap:7px;font-family:inherit;font-size:0.85rem;transition:all 0.15s;"
                            onmouseover="this.style.background='var(--danger-bg)'"
                            onmouseout="this.style.background='transparent'"
                            aria-label="Arxivar incidència ${incident.id}">
                        <i class="ri-archive-line"></i> Arxivar incidència
                    </button>
                </div>
            </div>
        </div>
    `;
    
    if (panel) panel.classList.add('open'); 
    
    // Inicializar el mapa de detalle
    setTimeout(() => {
         app.initDetailMap(incident.lat, incident.lng);
    }, 100); 
};

app.initDetailMap = function(lat, lng) {
    const mapElement = document.getElementById('detailMap');
    if (!mapElement) return;

    if (app.detailMap) {
        app.detailMap.remove();
    }

    if (typeof L === 'undefined') {
        return;
    }

    app.detailMap = L.map('detailMap', {
        zoomControl: false,
        dragging: false,
        scrollWheelZoom: false,
        doubleClickZoom: false,
        attributionControl: false
    }).setView([lat, lng], 16);

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '© CARTO', 
        maxZoom: 18
    }).addTo(app.detailMap);
    
    const customIcon = L.divIcon({
        html: '<i class="ri-map-pin-fill" style="font-size:35px; color:#ef4444; filter:drop-shadow(0 2px 3px rgba(0,0,0,0.3)); position:relative; top:-17px;"></i>',
        className: 'custom-pin-detail', iconSize: [35, 35], iconAnchor: [17, 35]
    });

    L.marker([lat, lng], { icon: customIcon }).addTo(app.detailMap);

    setTimeout(() => app.detailMap && app.detailMap.invalidateSize(), 300);
};

app.closeDetailPanel = function() {
    const panel = document.getElementById('detail-panel');
    if (panel) panel.classList.remove('open');
    
    if (app.detailMap) {
        app.detailMap.remove();
        app.detailMap = null;
    }
};

app.handleStatusChange = async function(id, newStatus, btn) {
    const originalText = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> ...';

    const comentari = document.getElementById(`adminComment-${id}`)?.value?.trim() || '';
    const fd = new FormData();
    fd.append('id', id);
    fd.append('estado', newStatus);
    if (comentari) fd.append('comentario', comentari);

    try {
        await app.adminFetch('api/index.php?action=update_status', { method: 'POST', body: fd });
        ui.showToast('Estat actualitzat correctament!', 'success', 3000);
        app.loadAdminData();
        app.closeDetailPanel();
    } catch(e) {
        if (e.code === 'AUTH') return;
        ui.showToast(`Error: ${e.message}`, 'error', 7000);
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
};

app.handleUrgencyChange = async function(id, newUrgency, btn) {
    const group = document.getElementById(`urgency-control-${id}`);
    const btns  = group?.querySelectorAll('.urgency-btn');
    btns?.forEach(b => b.classList.add('loading'));

    const fd = new FormData();
    fd.append('id', id);
    fd.append('urgencia', newUrgency);

    try {
        await app.adminFetch('api/index.php?action=update_urgencia', { method: 'POST', body: fd });

        // Update local cache so re-renders reflect the change immediately
        const inc = app.adminIncidents.find(i => i.id === id);
        if (inc) inc.urgencia = newUrgency;

        // Update button group active state
        btns?.forEach(b => {
            b.classList.remove('active');
            if (b.classList.contains(`urgency-${newUrgency}`)) b.classList.add('active');
        });

        // Update urgency pill in the detail header
        const i18n = app.i18n[app.lang];
        const label = i18n[`urg_${newUrgency}`] || newUrgency;
        const pill = document.querySelector('.detail-header-status-row .urgency-pill');
        if (pill) {
            pill.className = `urgency-pill urgency-${newUrgency}`;
            pill.textContent = label.toUpperCase();
        }

        // Refresh the incident row/card badge in the list without a full reload
        app.renderAdminList();
        ui.showToast(`Prioritat actualitzada: ${label}`, 'success', 2500);
    } catch(e) {
        if (e.code === 'AUTH') return;
        ui.showToast(`Error actualitzant prioritat: ${e.message}`, 'error', 5000);
    } finally {
        btns?.forEach(b => b.classList.remove('loading'));
    }
};

// 4. LÓGICA DEL MAPA ADMIN AVANZADO (Mejorado)

app.initAdminMap = function() {
    // Si no hay incidentes cargados, cargarlos
    if (this.adminIncidents.length === 0) {
        this.loadAdminData(); 
    }
    
    const mapElement = document.getElementById('map-admin');
    if (!mapElement) return;
    
    // Inicialización del mapa si no existe
    if (!app.adminMap) {
        if (typeof L === 'undefined') {
            return;
        }

        app.adminMap = L.map('map-admin').setView([41.450, 2.240], 13); // Centrado en Badalona

        L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
            attribution: '© CARTO', 
            maxZoom: 18
        }).addTo(app.adminMap);
        
        app.adminMapMarkers.addTo(app.adminMap);
        
        // Inicializar filtros al cargar el mapa por primera vez
        app.populateAdminMapFilters();
    }
    
    // Asegurar que el mapa se redibuje correctamente al cambiar de pestaña
    setTimeout(() => {
        app.adminMap.invalidateSize();
        app.drawAdminMapMarkers(); // Dibujar marcadores con filtros
    }, 200);
};

app.populateAdminMapFilters = function() {
    const i18n = this.i18n[this.lang];
    
    // Estado
    const statusSelect = document.getElementById('map-filter-status');
    statusSelect.innerHTML = `<option value="all">${i18n.admin_list_all} (${i18n.lbl_status})</option>` + 
        `<option value="pendiente">${i18n.status_pendiente}</option>` +
        `<option value="proceso">${i18n.status_proceso}</option>` +
        `<option value="resuelto">${i18n.status_resuelto}</option>`;
        
    // Categoría
    const categorySelect = document.getElementById('map-filter-category');
    categorySelect.innerHTML = `<option value="all">${i18n.admin_list_all} (${i18n.lbl_category})</option>` +
        `<option value="infraestructura">${i18n.cat_infra}</option>` +
        `<option value="denuncia">${i18n.cat_denuncia}</option>`;
        
    // Urgencia
    const urgencySelect = document.getElementById('map-filter-urgency');
    urgencySelect.innerHTML = `<option value="all">${i18n.admin_list_all} (${i18n.lbl_urgency})</option>` +
        `<option value="baja">${i18n.urg_low}</option>` +
        `<option value="media">${i18n.urg_medium}</option>` +
        `<option value="alta">${i18n.urg_high}</option>`;
        
    // Afectación (Impacto)
    const afectacionSelect = document.getElementById('map-filter-afectacion');
    afectacionSelect.innerHTML = `<option value="all">${i18n.admin_list_all} (${i18n.lbl_impact})</option>` +
        `<option value="individual">${i18n.imp_individual}</option>` +
        `<option value="col·lectiva">${i18n.imp_collective}</option>`;
        
    // Votos (Popularidad)
    const votosSelect = document.getElementById('map-filter-votos');
    votosSelect.innerHTML = `<option value="all">${i18n.admin_list_all} (${i18n.lbl_votes})</option>` +
        `<option value="5">${i18n.filter_votos_more_than} 5</option>` +
        `<option value="10">${i18n.filter_votos_more_than} 10</option>` +
        `<option value="20">${i18n.filter_votos_more_than} 20</option>`;

    // Restaurar valores si existen
    statusSelect.value = this.adminMapFilters.status;
    categorySelect.value = this.adminMapFilters.category;
    urgencySelect.value = this.adminMapFilters.urgency;
    afectacionSelect.value = this.adminMapFilters.afectacion;
    votosSelect.value = this.adminMapFilters.votos;
};

app.updateAdminMapFilters = function() {
    this.adminMapFilters.status = document.getElementById('map-filter-status').value;
    this.adminMapFilters.category = document.getElementById('map-filter-category').value;
    this.adminMapFilters.urgency = document.getElementById('map-filter-urgency').value;
    this.adminMapFilters.afectacion = document.getElementById('map-filter-afectacion').value;
    this.adminMapFilters.votos = document.getElementById('map-filter-votos').value;
    
    this.drawAdminMapMarkers();
};

app.resetAdminMapFilters = function() {
    this.adminMapFilters = { status: 'all', category: 'all', urgency: 'all', afectacion: 'all', votos: 'all' };
    this.populateAdminMapFilters(); // Restablece los valores en el DOM
    this.drawAdminMapMarkers();
};

app.drawAdminMapMarkers = function() {
    if (!app.adminMap) return;

    app.adminMapMarkers.clearLayers();
    const filters = this.adminMapFilters;
    let bounds = [];

    const filteredIncidents = app.adminIncidents.filter(inc => {
        const matchesStatus = filters.status === 'all' || inc.estado === filters.status;
        const matchesCategory = filters.category === 'all' || inc.categoria === filters.category;
        const matchesUrgency = filters.urgency === 'all' || inc.urgencia === filters.urgency;
        const matchesAfectacion = filters.afectacion === 'all' || inc.afectacion === filters.afectacion;
        
        const minVotes = filters.votos === 'all' ? 0 : parseInt(filters.votos, 10);
        const matchesVotos = parseInt(inc.votos) >= minVotes;

        return matchesStatus && matchesCategory && matchesUrgency && matchesAfectacion && matchesVotos;
    });
    
    // Crear y añadir marcadores
    filteredIncidents.forEach(inc => {
        if (!inc.lat || !inc.lng) return;
        
        const pinColor = this.getPinColor(inc.estado);
        const iconHtml = `<i class="ri-map-pin-2-fill" style="font-size:30px; color:${pinColor}; filter:drop-shadow(0 1px 2px rgba(0,0,0,0.4));"></i>`;
        
        const customIcon = L.divIcon({
            html: iconHtml,
            className: 'custom-map-pin', iconSize: [30, 30], iconAnchor: [15, 30]
        });
        
        const marker = L.marker([inc.lat, inc.lng], { icon: customIcon });
        
        // Mejorado: Contenido del Popup más claro
        const urgencyLabel = this.i18n[this.lang][`urg_${inc.urgencia}`] || 'Sense especificar';
        const statusLabel = this.i18n[this.lang][`status_${inc.estado}`].toUpperCase();

        const popupContent = `
            <div style="font-family: 'Inter', sans-serif; padding: 5px;">
                <h4 style="margin: 0 0 5px 0; color: ${pinColor}; font-weight:700;">#${inc.id}: ${escapeHtml(inc.titulo)}</h4>
                <p style="margin: 0 0 5px 0; font-size: 0.9rem;">
                    <strong>Estat:</strong> <span class="card-status status-${escapeHtml(inc.estado)}">${escapeHtml(statusLabel)}</span>
                </p>
                <p style="margin: 0 0 5px 0; font-size: 0.8rem;">
                    <i class="ri-map-pin-line" style="font-size:1.1rem; vertical-align:middle; margin-right: 3px;"></i>
                    ${escapeHtml(inc.barri || 'Ubicació Desconeguda')}
                </p>
                <div style="display: flex; justify-content: space-between; font-size: 0.85rem; margin-bottom: 10px;">
                    <span><i class="ri-thumb-up-fill"></i> <strong>Vots:</strong> ${inc.votos || 0}</span>
                    <span><i class="ri-fire-line"></i> <strong>Urgència:</strong> ${escapeHtml(urgencyLabel)}</span>
                </div>
                <button class="btn-sm btn-primary" onclick="app.openDetailPanel(${inc.id})" style="width: 100%;">Veure Detalls</button>
            </div>
        `;
        
        marker.bindPopup(popupContent, { maxWidth: 300 });
        app.adminMapMarkers.addLayer(marker);
        
        bounds.push([inc.lat, inc.lng]);
    });
    
    // Ajustar vista del mapa si hay marcadores y no es el zoom inicial
    if (bounds.length > 0) {
         try {
            app.adminMap.fitBounds(bounds, { padding: [20, 20], maxZoom: 16 });
         } catch(e) {
            // Falla si solo hay un punto, centramos en el primero
             app.adminMap.setView(bounds[0], 15);
         }
    }
};

app.getPinColor = function(status) {
    switch (status) {
        case 'pendiente': return '#f59e0b'; // warning
        case 'proceso': return '#3b82f6';    // info
        case 'resuelto': return '#10b981';   // success
        default: return '#6b7280';
    }
};


// 5. GESTIÓN DE ESTADÍSTICAS AVANZADAS (Admin) (Mantenido)

app.loadAdminStats = async function() {
    const content = document.getElementById('tab-stats-content');

    Object.keys(this.chartInstances).forEach(key => {
        if (this.chartInstances[key]?.destroy) this.chartInstances[key].destroy();
    });
    this.chartInstances = {};

    if (content) showStatsSkeletons(content);

    try {
        const json = await app.adminFetch('api/index.php?action=admin_stats');
        if (json.status === 'success') {
            app.renderAdminStats(json.data);
        } else {
            if (content) content.innerHTML = `<p class="text-center" style="color:var(--danger);padding:50px;">Error: ${json.message}</p>`;
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        if (content) content.innerHTML = `<p class="text-center" style="color:var(--danger);padding:50px;">Error de connexió: ${e.message}</p>`;
    }
};

app.renderAdminStats = function(data) {
    const i18n = this.i18n[this.lang];

    const totalResolved = data.urgency_distribution.resuelto || 0;
    const totalPending  = data.urgency_distribution.pendiente || 0;
    const totalProcess  = data.urgency_distribution.proceso   || 0;
    const totalUrgent   = data.urgency_distribution.alta      || 0;
    const total         = data.total_incidents || 1;
    const resolutionRate = Math.round((totalResolved / total) * 100);

    // Top barris from adminIncidents
    const barriCount = {};
    (app.adminIncidents || []).forEach(inc => {
        if (inc.barri) barriCount[inc.barri] = (barriCount[inc.barri] || 0) + 1;
    });
    const topBarris = Object.entries(barriCount)
        .sort((a, b) => b[1] - a[1]).slice(0, 6);
    const maxBarri = topBarris[0]?.[1] || 1;

    const topBarrisHTML = topBarris.map(([barri, count]) => `
        <div class="stat-bar-item">
            <div class="stat-bar-header">
                <span class="stat-bar-label">${escapeHtml(barri)}</span>
                <span class="stat-bar-value">${count}</span>
            </div>
            <div class="stat-bar-track">
                <div class="stat-bar-fill" style="width:${Math.round((count/maxBarri)*100)}%"></div>
            </div>
        </div>`).join('') || '<p style="color:var(--text-light);font-size:0.85rem;">Sense dades de barri disponibles.</p>';

    const contentHTML = `
        <div class="stats-section-title"><i class="ri-pulse-line"></i> Indicadors Clau de Rendiment</div>
        <div class="stats-kpi-row">
            <div class="stats-kpi-mini">
                <div class="stats-kpi-mini-label">Total incidències</div>
                <div class="stats-kpi-mini-value" style="color:var(--primary)">${total}</div>
                <div class="stats-kpi-mini-sub">En tots els estats</div>
            </div>
            <div class="stats-kpi-mini">
                <div class="stats-kpi-mini-label">Taxa de resolució</div>
                <div class="stats-kpi-mini-value" style="color:var(--success)">${resolutionRate}%</div>
                <div class="stats-kpi-mini-sub">${totalResolved} resoltes</div>
            </div>
            <div class="stats-kpi-mini">
                <div class="stats-kpi-mini-label">Pendents d'atenció</div>
                <div class="stats-kpi-mini-value" style="color:var(--warning)">${totalPending + totalProcess}</div>
                <div class="stats-kpi-mini-sub">${totalPending} pendent · ${totalProcess} en procés</div>
            </div>
            <div class="stats-kpi-mini">
                <div class="stats-kpi-mini-label">Urgència alta</div>
                <div class="stats-kpi-mini-value" style="color:var(--danger)">${totalUrgent}</div>
                <div class="stats-kpi-mini-sub">${Math.round((totalUrgent/total)*100)}% del total</div>
            </div>
        </div>

        <div class="stats-section-title" style="margin-top:8px;"><i class="ri-line-chart-line"></i> Tendències Temporals</div>
        <div class="chart-duo" style="margin-bottom:20px;">
            <div class="chart-card">
                <div class="chart-card-title"><i class="ri-bar-chart-2-line"></i> Flux setmanal (nous vs resolts)</div>
                <div class="chart-container"><canvas id="adminWeeklyFlowChart"></canvas></div>
            </div>
            <div class="chart-card">
                <div class="chart-card-title"><i class="ri-line-chart-line"></i> Tendència mensual (darrers 6 mesos)</div>
                <div class="chart-container"><canvas id="adminMonthlyChart"></canvas></div>
            </div>
        </div>

        <div class="stats-section-title"><i class="ri-pie-chart-2-line"></i> Classificació i Distribució</div>
        <div class="chart-duo" style="margin-bottom:20px;">
            <div class="chart-card">
                <div class="chart-card-title"><i class="ri-error-warning-line"></i> Distribució per urgència</div>
                <div class="chart-container"><canvas id="adminUrgencyChart"></canvas></div>
            </div>
            <div class="chart-card">
                <div class="chart-card-title"><i class="ri-group-line"></i> Distribució per afectació</div>
                <div class="chart-container"><canvas id="adminAfectacionChart"></canvas></div>
            </div>
        </div>

        <div class="stats-section-title"><i class="ri-map-pin-line"></i> Top Barris per Incidències</div>
        <div class="chart-card" style="margin-bottom:20px;">
            <div class="chart-card-title"><i class="ri-bar-chart-horizontal-line"></i> Barris amb més incidències reportades</div>
            ${topBarrisHTML}
        </div>
    `;

    const content = document.getElementById('tab-stats-content');
    if (content) content.innerHTML = contentHTML;

    setTimeout(() => {
        this.drawWeeklyFlowChart(data.weekly_status_flow, i18n);
        this.drawAdminMonthlyChart(data.monthly_trend, i18n);
        this.drawAdminUrgencyChart(data.urgency_distribution, i18n);
        this.drawAdminAfectacionChart(data.afectacion_distribution, i18n);
    }, 100);
};


app.drawWeeklyFlowChart = function(data, i18n) {
    const ctx = document.getElementById('adminWeeklyFlowChart');
    if (!ctx) return;
    
    const existingChart = Chart.getChart(ctx);
    if (existingChart) {
        existingChart.destroy();
    }

    const dates = data.map(d => new Date(d.date).toLocaleDateString(this.lang, { weekday: 'short', day: 'numeric' }));
    const createdData = data.map(d => d.created);
    const resolvedData = data.map(d => d.resolved);

    this.chartInstances.adminWeeklyFlowChart = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: dates,
            datasets: [
                {
                    label: i18n.admin_stats_created,
                    data: createdData,
                    backgroundColor: 'rgba(37, 99, 235, 0.7)',
                    borderColor: 'rgb(37, 99, 235)',
                    borderWidth: 1,
                    type: 'bar',
                    order: 2 
                },
                {
                    label: i18n.admin_stats_solved_wk,
                    data: resolvedData,
                    backgroundColor: 'rgba(16, 185, 129, 0.8)',
                    borderColor: 'rgb(16, 185, 129)',
                    borderWidth: 2,
                    type: 'line',
                    fill: false,
                    tension: 0.3,
                    pointRadius: 5,
                    order: 1 
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: { beginAtZero: true, stacked: false, ticks: { precision: 0 } },
                x: { stacked: false }
            },
            plugins: {
                legend: { position: 'bottom' },
                title: { display: false }
            }
        }
    });
};

app.drawAdminMonthlyChart = function(data, i18n) {
    const ctx = document.getElementById('adminMonthlyChart');
    if (!ctx) return;
    
    const existingChart = Chart.getChart(ctx);
    if (existingChart) {
        existingChart.destroy();
    }

    const labels = data.map(d => {
        const [year, month] = d.month.split('-');
        const date = new Date(year, month - 1, 1);
        return date.toLocaleDateString(this.lang, { month: 'short', year: '2-digit' });
    }).reverse();
    const counts = data.map(d => d.count).reverse();

    this.chartInstances.adminMonthlyChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: i18n.admin_stats_created,
                data: counts,
                backgroundColor: 'rgba(245, 158, 11, 0.3)',
                borderColor: 'rgb(245, 158, 11)',
                borderWidth: 2,
                fill: true,
                tension: 0.4,
                pointBackgroundColor: 'rgb(245, 158, 11)'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: { beginAtZero: true, ticks: { precision: 0 } }
            },
            plugins: {
                legend: { display: false }
            }
        }
    });
};

app.drawAdminUrgencyChart = function(data, i18n) {
    const ctx = document.getElementById('adminUrgencyChart');
    if (!ctx) return;
    
    const existingChart = Chart.getChart(ctx);
    if (existingChart) {
        existingChart.destroy();
    }

    const urgencyLabels = {
        'baja': i18n.urg_low,
        'media': i18n.urg_medium,
        'alta': i18n.urg_high
    };
    const relevantKeys = ['baja', 'media', 'alta'];
    const labels = relevantKeys.map(key => urgencyLabels[key]);
    const counts = relevantKeys.map(key => data[key] || 0);
    const colors = ['#34d399', '#facc15', '#ef4444'];

    this.chartInstances.adminUrgencyChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: counts,
                backgroundColor: colors,
                hoverOffset: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
};

app.drawAdminAfectacionChart = function(data, i18n) {
    const ctx = document.getElementById('adminAfectacionChart');
    if (!ctx) return;
    
    const existingChart = Chart.getChart(ctx);
    if (existingChart) {
        existingChart.destroy();
    }

    const labels = [
        i18n.imp_individual, 
        i18n.imp_collective, 
        'Sense especificar' 
    ];
    
    const counts = [
        data.individual || 0, 
        data['col·lectiva'] || 0, 
        (data[''] || 0) + (data[null] || 0)
    ];
    const colors = ['#60a5fa', '#f87171', '#94a3b8'];

    this.chartInstances.adminAfectacionChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: counts,
                backgroundColor: colors,
                hoverOffset: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { position: 'bottom' }
            }
        }
    });
};


// 6. GESTIÓN DE USUARIOS (Mantenido y funcional)

app.openCreateAdminModal = function() {
    const form = document.getElementById('adminUserForm');
    form.reset();
    
    document.getElementById('adminUserId').value = '';
    document.getElementById('adminModalTitle').textContent = app.i18n[app.lang].admin_btn_new_user;
    document.getElementById('adminSubmitBtn').textContent = app.i18n[app.lang].admin_btn_new_user;
    
    document.getElementById('adminPassword').required = true;
    document.getElementById('passwordLabel').textContent = `${app.i18n[app.lang].lbl_password} (${app.i18n[app.lang].ph_password_new})`;
    document.getElementById('adminPassword').placeholder = app.i18n[app.lang].ph_password_new;
    
    app.populateAdminUserForm();
    
    form.onsubmit = app.handleCreateAdminSubmit;

    const modal = document.getElementById('adminUserModal');
    modal.classList.remove('hidden');
    modal._backdropHandler = function(e) { if (e.target === modal) app.closeAdminUserModal(); };
    modal.addEventListener('click', modal._backdropHandler);
    document.addEventListener('keydown', function escHandler(e) {
        if (e.key === 'Escape') { app.closeAdminUserModal(); document.removeEventListener('keydown', escHandler); }
    }, { once: true });
};

app.openEditAdminModal = function(id) {
    const user = app.adminUsers.find(u => u.id == id);
    if (!user) return;
    
    const form = document.getElementById('adminUserForm');
    form.reset(); 
    
    document.getElementById('adminUserId').value = user.id;
    document.getElementById('adminUsername').value = user.usuario;
    
    document.getElementById('adminPassword').required = false; 
    document.getElementById('adminPassword').value = ''; 
    document.getElementById('passwordLabel').textContent = `${app.i18n[app.lang].lbl_password} (${app.i18n[app.lang].ph_password_optional})`;
    document.getElementById('adminPassword').placeholder = app.i18n[app.lang].ph_password_optional;
    
    app.populateAdminUserForm(user.role, user.access_type, user.district_access);
    
    document.getElementById('adminModalTitle').textContent = app.i18n[app.lang].btn_edit_user || "Editar Administrador";
    document.getElementById('adminSubmitBtn').textContent = app.i18n[app.lang].detail_btn_update;
    
    form.onsubmit = app.handleUpdateAdminSubmit;

    const modal = document.getElementById('adminUserModal');
    modal.classList.remove('hidden');
    modal._backdropHandler = function(e) { if (e.target === modal) app.closeAdminUserModal(); };
    modal.addEventListener('click', modal._backdropHandler);
    document.addEventListener('keydown', function escHandler(e) {
        if (e.key === 'Escape') { app.closeAdminUserModal(); document.removeEventListener('keydown', escHandler); }
    }, { once: true });
};

app.closeAdminUserModal = function() {
    const modal = document.getElementById('adminUserModal');
    modal.classList.add('hidden');
    if (modal._backdropHandler) {
        modal.removeEventListener('click', modal._backdropHandler);
        modal._backdropHandler = null;
    }
    const msg = document.getElementById('userMessage');
    if (msg) msg.textContent = "";
};

app.populateAdminUserForm = function(selectedRole = 'moderator', selectedAccess = 'all', selectedDistricts = '') {
    const roleSelect = document.getElementById('adminRole');
    const accessSelect = document.getElementById('adminAccessType');
    const districtInput = document.getElementById('adminDistrictAccess');
    const districtContainer = document.getElementById('districtAccessContainer');

    roleSelect.innerHTML = `
        <option value="superadmin" ${selectedRole === 'superadmin' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_superadmin}</option>
        <option value="admin" ${selectedRole === 'admin' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_admin}</option>
        <option value="moderator" ${selectedRole === 'moderator' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_moderator}</option>
    `;
    
    accessSelect.innerHTML = `
        <option value="all" ${selectedAccess === 'all' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_all}</option>
        <option value="infraestructura" ${selectedAccess === 'infraestructura' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_infra}</option>
        <option value="denuncia" ${selectedAccess === 'denuncia' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_denuncia}</option>
    `;

    districtInput.value = selectedDistricts;
    
    const toggleDistrictAccess = () => {
        const currentRole = roleSelect.value;
        
        if (currentRole === 'superadmin' || currentRole === 'admin' || currentRole === 'moderator') {
             districtContainer.classList.remove('hidden');
        } else {
             districtContainer.classList.add('hidden');
        }
    };
    
    roleSelect.onchange = toggleDistrictAccess;
    accessSelect.onchange = toggleDistrictAccess;
    toggleDistrictAccess(); 
    
    roleSelect.value = selectedRole;
    accessSelect.value = selectedAccess;
};

app.handleCreateAdminSubmit = async function(e) {
    e.preventDefault();
    const form = e.target;
    const btn = document.getElementById('adminSubmitBtn');
    const msg = document.getElementById('userMessage');
    const originalText = btn.innerHTML;
    
    msg.textContent = "";
    btn.disabled = true;
    btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Creant...';

    try {
        const formData = new FormData(form);
        formData.delete('id');

        const usuario = formData.get('usuario');
        const password = formData.get('password');
        if (!usuario || usuario.trim() === '' || !password || password.length < 8) {
            throw new Error("Error de validació: L'usuari (email) i la contrasenya (mínim 8 caràcters) són obligatoris.");
        }

        const json = await app.adminFetch('api/index.php?action=create_admin', { method: 'POST', body: formData });
        if (json.status === 'success') {
            ui.showToast(json.message, 'success', 3000);
            app.closeAdminUserModal();
            app.loadUserManagement();
        } else {
            if (msg) msg.textContent = json.message || "Error desconegut en crear l'usuari.";
            throw new Error(json.message);
        }
    } catch(err) {
        ui.showToast("Error: " + (err.message || "Error en connectar amb l'API."), 'error', 5000);
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
};

app.handleUpdateAdminSubmit = async function(e) {
    e.preventDefault();
    const form = e.target;
    const btn = document.getElementById('adminSubmitBtn');
    const msg = document.getElementById('userMessage');
    const originalText = btn.innerHTML;
    
    msg.textContent = "";
    btn.disabled = true;
    btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Actualitzant...';

    try {
        const formData = new FormData(form);
        if (formData.get('password') === '') formData.delete('password');
        else if (formData.has('password') && formData.get('password').length < 8)
            throw new Error("Error de validació: La nova contrasenya ha de tenir almenys 8 caràcters.");

        const json = await app.adminFetch('api/index.php?action=update_admin', { method: 'POST', body: formData });
        if (json.status === 'success') {
            ui.showToast(json.message, 'success', 3000);
            app.closeAdminUserModal();
            app.loadUserManagement();
        } else {
            if (msg) msg.textContent = json.message || "Error desconegut en actualitzar l'usuari.";
            throw new Error(json.message);
        }
    } catch(err) {
        ui.showToast("Error: " + (err.message || "Error en connectar amb l'API."), 'error', 5000);
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
};


app.loadUserManagement = async function() {
    const listContainer = document.getElementById('admin-users-list');
    const createUserBtn = document.getElementById('createUserBtn');
    
    if (listContainer) {
        listContainer.innerHTML = `<p class="text-center" style="padding: 20px; color: var(--text-light);">${app.i18n[app.lang].admin_list_loading}</p>`;
    }
    
    // IMPORTANTE: Controla la visibilidad del botón 'Crear Usuario' (ahora dentro de la pestaña)
    if (app.adminRole !== 'superadmin') {
        if (listContainer) listContainer.innerHTML = `<p class="text-center" style="padding: 20px; color: var(--danger);">Permisos insuficients. Només el Superadmin pot gestionar usuaris.</p>`;
        if (createUserBtn) createUserBtn.style.display = 'none';
        return;
    }
    // Superadmin: always show create button when on the users tab
    if (createUserBtn) createUserBtn.style.display = '';


    try {
        const json = await app.adminFetch('api/index.php?action=get_admins');
        if (json.status === 'success') {
            app.adminUsers = json.data;
            app.renderUserList();
        } else {
            if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color:var(--danger);">Error: ${json.message}</p>`;
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color:var(--danger);">Error de connexió: ${e.message}</p>`;
    }
};

app.renderUserList = function() {
    const listContainer = document.getElementById('admin-users-list');
    if (!listContainer) return;

    const isSuperadmin = app.adminRole === 'superadmin';
    const currentUsername = localStorage.getItem('admin_username');

    const tableHTML = `
        <div class="table-wrapper">
            <table id="admin-users-table" class="incident-table">
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Usuari</th>
                        <th>Rols</th>
                        <th>Accés (Tipus)</th>
                        <th>Accés (Districte)</th>
                        <th>Accions</th>
                    </tr>
                </thead>
                <tbody>
                    ${app.adminUsers.map(user => {
                        const roleLabel = app.i18n[app.lang][`admin_user_role_${user.role}`] || user.role;
                        const roleClass = `role-${user.role}`;
                        const accessTypeLabel = app.i18n[app.lang][`admin_user_access_${user.access_type}`] || user.access_type;
                        
                        const isCurrentUser = user.usuario === currentUsername; 
                        const isOnlySuperadmin = user.role === 'superadmin' && app.adminUsers.filter(u => u.role === 'superadmin').length === 1;

                        const canEdit = isSuperadmin;
                        const canDelete = isSuperadmin && !isCurrentUser && !(user.role === 'superadmin' && isOnlySuperadmin);

                        const editBtn = canEdit ?
                            `<button class="btn-sm btn-info" title="Editar usuari" onclick="event.stopPropagation(); app.openEditAdminModal(${user.id})">
                                <i class="ri-edit-line"></i>
                            </button>` :
                            `<button class="btn-sm btn-info" disabled title="No tens permisos per editar." style="opacity:0.5; cursor: not-allowed;">
                                <i class="ri-edit-line"></i>
                            </button>`;

                        const deleteBtn = canDelete ?
                            `<button class="btn-sm btn-del" onclick="event.stopPropagation(); app.handleDeleteAdmin(${user.id}, this)">
                                <i class="ri-delete-bin-line"></i>
                            </button>` :
                            `<button class="btn-sm btn-del" disabled title="${isCurrentUser ? "No pots eliminar el teu propi usuari." : isOnlySuperadmin ? "No pots eliminar l'únic Superadmin." : "Permisos insuficients."}" style="opacity:0.5; cursor: not-allowed;">
                                <i class="ri-delete-bin-line"></i>
                            </button>`;

                        return `
                            <tr style="cursor: default;">
                                <td data-label="ID">#${user.id}</td>
                                <td data-label="Usuari"><strong>${user.usuario}</strong></td>
                                <td data-label="Rol"><span class="user-role ${roleClass}">${roleLabel}</span></td>
                                <td data-label="Tipus">${accessTypeLabel}</td>
                                <td data-label="Districte">${user.district_access || 'Tots'}</td>
                                <td data-label="Accions" class="user-actions">
                                    ${editBtn}
                                    ${deleteBtn}
                                </td>
                            </tr>
                        `;
                    }).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    listContainer.innerHTML = tableHTML;
};

app.handleDeleteAdmin = async function(id, btn) {
    if (!confirm(app.i18n[app.lang].users_delete_confirm)) return;

    const originalText = btn.innerHTML;
    btn.disabled = true;
    btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i>';

    try {
        const formData = new FormData();
        formData.append('id', id);
        const json = await app.adminFetch('api/index.php?action=delete_admin', { method: 'POST', body: formData });
        ui.showToast(json.message || "Usuari eliminat correctament.", 'success', 3000);
        app.loadUserManagement();
    } catch(e) {
        if (e.code === 'AUTH') return;
        ui.showToast(e.message || "Error de connexió al servidor.", 'error', 5000);
    } finally {
        btn.innerHTML = originalText;
        btn.disabled = false;
    }
};


app.renderKPIs = function(incidents) {
    const pending    = incidents.filter(i => i.estado === 'pendiente');
    const inprocess  = incidents.filter(i => i.estado === 'proceso');
    const resolved   = incidents.filter(i => i.estado === 'resuelto');
    const urgent     = incidents.filter(i => i.urgencia === 'alta');

    let avgDays = '—';
    if (resolved.length > 0) {
        const withDates = resolved.filter(i => i.updated_at && i.created_at);
        if (withDates.length > 0) {
            const totalMs = withDates.reduce((acc, i) =>
                acc + (new Date(i.updated_at) - new Date(i.created_at)), 0);
            avgDays = Math.round(totalMs / withDates.length / 86400000) + 'd';
        }
    }

    const setVal = (id, val) => {
        const el = document.getElementById(id);
        if (el) el.textContent = val;
    };

    setVal('kpi-total',     incidents.length);
    setVal('kpi-open',      pending.length);
    setVal('kpi-inprocess', inprocess.length);
    setVal('kpi-resolved',  resolved.length);
    setVal('kpi-avg',       avgDays);
    setVal('kpi-urgent',    urgent.length);

    // Trend: resolution rate badge on total card
    const totalTrend = document.getElementById('kpi-total-trend');
    if (totalTrend && incidents.length > 0) {
        const rate = Math.round((resolved.length / incidents.length) * 100);
        totalTrend.innerHTML = `<span style="color:var(--success);font-size:0.72rem;font-weight:700;">${rate}% resoltes</span>`;
    }
};

app.heatmapLayer = null;
app.heatmapActive = false;

app.toggleHeatmap = function() {
    if (!app.adminMap) return;
    const btn = document.getElementById('btn-heatmap');
    if (app.heatmapActive) {
        if (app.heatmapLayer) app.adminMap.removeLayer(app.heatmapLayer);
        app.heatmapActive = false;
        if (btn) btn.classList.remove('active');
    } else {
        const points = (app.adminIncidents || [])
            .filter(i => i.lat && i.lng)
            .map(i => [parseFloat(i.lat), parseFloat(i.lng),
                       i.urgencia === 'alta' ? 1.0 : i.urgencia === 'media' ? 0.6 : 0.3]);
        if (points.length === 0) { ui.showToast('No hi ha punts per mostrar al mapa de calor.', 'info', 3000); return; }
        app.heatmapLayer = L.heatLayer(points, {
            radius: 25, blur: 15, maxZoom: 17,
            gradient: { 0.4: '#002D5A', 0.65: '#FFC107', 1: '#ef4444' }
        }).addTo(app.adminMap);
        app.heatmapActive = true;
        if (btn) btn.classList.add('active');
    }
};

// ── Vista de Prioritat ────────────────────────────────────────────────────────
app.loadPriorityView = async function() {
    const container = document.getElementById('priority-list');
    if (!container) return;

    // Translate info banner
    const banner = document.getElementById('priority-info-banner')?.querySelector('span');
    if (banner) banner.textContent = app.i18n[app.lang].priority_info || banner.textContent;

    container.innerHTML = '<p class="text-center" style="padding:30px;color:var(--text-light);"><i class="ri-loader-4-line ri-spin"></i> Carregant...</p>';

    try {
        const json = await app.adminFetch('api/index.php?action=admin_data&sort=score');
        if (json.status !== 'success') throw new Error(json.message);

        const incidents = json.data;
        if (!incidents.length) {
            container.innerHTML = `<p class="text-center" style="padding:30px;color:var(--text-light);">${app.i18n[app.lang].admin_list_empty}</p>`;
            return;
        }

        // openDetailPanel cerca a app.adminIncidents; si s'ha obert
        // Prioritat directament (sense passar per Incidències), poblem la llista.
        if (!app.adminIncidents.length) {
            app.adminIncidents = incidents;
        }

        const i18n = app.i18n[app.lang];
        const rows = incidents.map((inc, idx) => {
            const score        = (inc.urgency_score ?? 0).toFixed(2);
            const statusLabel  = i18n[`status_${inc.estado}`] || inc.estado;
            const urgencyLabel = i18n[`urg_${inc.urgencia}`]  || inc.urgencia;
            const rankClass    = idx === 0 ? 'priority-rank-1' : idx === 1 ? 'priority-rank-2' : idx === 2 ? 'priority-rank-3' : '';
            const rankIcon     = idx === 0 ? '🥇' : idx === 1 ? '🥈' : idx === 2 ? '🥉' : `<span class="priority-rank-num">${idx + 1}</span>`;

            return `
            <div class="incident-card-admin mobile-card-view priority-card ${rankClass}" onclick="app.openDetailPanel(${inc.id})" role="button" tabindex="0" aria-label="Incidència ${escapeHtml(inc.titulo)}, score ${score}">
                <div class="priority-card-header">
                    <span class="priority-rank-badge">${rankIcon}</span>
                    <span class="priority-score-pill" title="${i18n.priority_score_label}">
                        <i class="ri-fire-fill" aria-hidden="true"></i> ${score}
                    </span>
                    <span class="card-status status-${escapeHtml(inc.estado)}">${escapeHtml(statusLabel.toUpperCase())}</span>
                    <span class="urgency-pill urgency-${escapeHtml(inc.urgencia)}">${escapeHtml(urgencyLabel.toUpperCase())}</span>
                </div>
                <h4 class="card-title-admin" style="margin:8px 0 4px;">${escapeHtml(inc.titulo)}</h4>
                <p class="card-location-admin text-muted"><i class="ri-map-pin-line"></i> ${escapeHtml(inc.barri || '—')} · <i class="ri-thumb-up-line"></i> ${inc.votos} suports</p>
            </div>`;
        });

        container.innerHTML = rows.join('');

        // Keyboard navigation for cards
        container.querySelectorAll('.priority-card').forEach(card => {
            card.addEventListener('keydown', e => {
                if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); card.click(); }
            });
        });
    } catch (e) {
        if (e.code === 'AUTH') return;
        container.innerHTML = `<p class="text-center" style="padding:30px;color:var(--danger);">Error carregant prioritats: ${escapeHtml(e.message)}</p>`;
    }
};

// ── Bulk Actions ──────────────────────────────────────────────────────────────
app.selectedIncidents = new Set();
app.bulkMode = false;

app.toggleBulkMode = function() {
    this.bulkMode = !this.bulkMode;
    const btn  = document.getElementById('btn-bulk-toggle');
    const list = document.getElementById('incident-list');
    if (this.bulkMode) {
        list?.classList.add('bulk-mode-active');
        btn?.classList.add('active');
    } else {
        list?.classList.remove('bulk-mode-active');
        btn?.classList.remove('active');
        this.clearBulkSelection();
    }
};

app.toggleIncidentSelection = function(id, checked) {
    if (checked) this.selectedIncidents.add(id);
    else this.selectedIncidents.delete(id);
    this.updateBulkBar();
};

app.toggleSelectAll = function(checked) {
    document.querySelectorAll('.row-select-cb').forEach(cb => {
        cb.checked = checked;
        const id = parseInt(cb.value, 10);
        if (checked) this.selectedIncidents.add(id);
        else this.selectedIncidents.delete(id);
    });
    this.updateBulkBar();
};

app.updateBulkBar = function() {
    const bar   = document.getElementById('bulk-action-bar');
    const label = document.getElementById('bulk-count-label');
    const count = this.selectedIncidents.size;
    if (!bar) return;
    if (count > 0 && this.bulkMode) {
        bar.classList.remove('hidden');
        if (label) label.textContent = `${count} incidèn${count === 1 ? 'cia' : 'cies'} seleccionada${count === 1 ? '' : 'es'}`;
    } else {
        bar.classList.add('hidden');
    }
};

app.executeBulkAction = async function() {
    const statusSelect = document.getElementById('bulk-status-select');
    const newStatus = statusSelect?.value;
    if (!newStatus) { ui.showToast('Selecciona un estat de destinació', 'error', 3000); return; }
    if (this.selectedIncidents.size === 0) { ui.showToast('Cap incidència seleccionada', 'error', 3000); return; }

    const count = this.selectedIncidents.size;
    const statusLabels = { pendiente: 'Pendent', proceso: 'En Procés', resuelto: 'Resolt' };
    if (!confirm(`Actualitzar ${count} incidèn${count === 1 ? 'cia' : 'cies'} a "${statusLabels[newStatus]}"?`)) return;

    try {
        const fd = new FormData();
        fd.append('estado', newStatus);
        this.selectedIncidents.forEach(id => fd.append('ids[]', id));
        const json = await app.adminFetch('api/index.php?action=bulk_update_status', { method: 'POST', body: fd });
        if (json.status === 'success') {
            ui.showToast(json.message, 'success', 3000);
            this.clearBulkSelection();
            this.loadAdminData();
        } else {
            ui.showToast(`Error: ${json.message}`, 'error', 5000);
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        ui.showToast('Error de connexió al servidor', 'error', 5000);
    }
};

app.clearBulkSelection = function() {
    this.selectedIncidents.clear();
    document.querySelectorAll('.row-select-cb').forEach(cb => cb.checked = false);
    const sa = document.getElementById('select-all-cb');
    if (sa) sa.checked = false;
    this.updateBulkBar();
};

app.archiveIncident = async function(id) {
    if (!confirm('Vols arxivar aquesta incidència? Deixarà de ser visible al mapa públic però es conservarà per auditoria.')) return;
    try {
        const fd = new FormData();
        fd.append('id', id);
        const json = await app.adminFetch('api/index.php?action=archive_incident', { method: 'POST', body: fd });
        if (json.status === 'success') {
            ui.showToast('Incidència arxivada correctament.', 'success', 3000);
            this.closeDetailPanel();
            this.loadAdminData();
        } else {
            ui.showToast(`Error: ${json.message}`, 'error', 5000);
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        ui.showToast('Error de connexió al servidor', 'error', 5000);
    }
};

// ── Activity Log ──────────────────────────────────────────────────────────────
app._activityPage = 1;

app.loadActivityLog = async function(page = 1) {
    this._activityPage = page;
    const container = document.getElementById('activity-log-list');
    const pager     = document.getElementById('activity-pagination');
    if (!container) return;

    container.innerHTML = `<p class="text-center" style="padding:30px;color:var(--text-light);"><i class="ri-loader-4-line ri-spin"></i> Carregant registre d'activitat...</p>`;

    try {
        const json = await app.adminFetch(`api/index.php?action=get_activity_log&page=${page}`);
        if (json.status !== 'success') throw new Error(json.message);

        if (!json.data.length) {
            container.innerHTML = `<p class="text-center" style="padding:30px;color:var(--text-light);">Sense registre d'activitat.</p>`;
            if (pager) pager.innerHTML = '';
            return;
        }

        const statusColors = { pendiente: '#f59e0b', proceso: '#3b82f6', resuelto: '#10b981' };
        const statusLabels = { pendiente: 'Pendent', proceso: 'En Procés', resuelto: 'Resolt' };
        const statusIcons  = { pendiente: 'ri-time-line', proceso: 'ri-refresh-line', resuelto: 'ri-checkbox-circle-line' };

        container.innerHTML = json.data.map(item => {
            const color    = statusColors[item.estado_nuevo] || '#6b7280';
            const label    = statusLabels[item.estado_nuevo] || item.estado_nuevo;
            const icon     = statusIcons[item.estado_nuevo]  || 'ri-circle-line';
            const prevColor = statusColors[item.estado_anterior] || '#94a3b8';
            const prevLabel = item.estado_anterior ? (statusLabels[item.estado_anterior] || item.estado_anterior) : 'Nou report';
            const date     = new Date(item.fecha).toLocaleString('ca-ES', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
            const title    = item.titulo ? escapeHtml(item.titulo) : `Incidència #${item.incidencia_id}`;

            return `
            <div class="activity-log-item">
                <div class="activity-dot" style="background:${color};">
                    <i class="${icon}"></i>
                </div>
                <div class="activity-body">
                    <div class="activity-header">
                        <button class="activity-title-btn" onclick="app.openDetailPanel(${item.incidencia_id})" title="Obrir detall">${title} <span style="color:var(--text-light);font-weight:400;">#${item.incidencia_id}</span></button>
                        <span class="activity-date"><i class="ri-time-line"></i> ${date}</span>
                    </div>
                    <div class="activity-meta">
                        <span class="activity-transition">
                            <span style="color:${prevColor};">${prevLabel}</span>
                            <i class="ri-arrow-right-s-line" style="margin:0 2px;color:var(--text-light);"></i>
                            <span style="color:${color};font-weight:700;">${label}</span>
                        </span>
                        ${item.admin_usuario ? `<span class="activity-admin"><i class="ri-user-line"></i> ${escapeHtml(item.admin_usuario)}</span>` : ''}
                    </div>
                    ${item.comentario_admin ? `<p class="activity-comment"><i class="ri-chat-quote-line"></i> ${escapeHtml(item.comentario_admin)}</p>` : ''}
                </div>
            </div>`;
        }).join('');

        if (pager) {
            pager.innerHTML = json.pages > 1 ? `
                <div class="activity-pager">
                    <button class="btn-sm btn-info" ${page <= 1 ? 'disabled' : ''} onclick="app.loadActivityLog(${page - 1})">← Anterior</button>
                    <span>Pàgina ${page} de ${json.pages} (${json.total} registres)</span>
                    <button class="btn-sm btn-info" ${page >= json.pages ? 'disabled' : ''} onclick="app.loadActivityLog(${page + 1})">Següent →</button>
                </div>` : `<p style="text-align:center;font-size:0.82rem;color:var(--text-light);margin-top:12px;">${json.total} registres totals</p>`;
        }
    } catch(e) {
        if (e.code === 'AUTH') return;
        container.innerHTML = `<p class="text-center" style="padding:30px;color:var(--danger);">Error: ${escapeHtml(e.message)}</p>`;
    }
};

// ── Auto-refresh (every 60 s) ─────────────────────────────────────────────────
app._refreshInterval = null;
app._lastSeenPending = -1;

app.startAutoRefresh = function() {
    if (this._refreshInterval) clearInterval(this._refreshInterval);
    this._refreshInterval = setInterval(async () => {
        try {
            const json = await app.adminFetch('api/index.php?action=admin_data');
            if (json.status !== 'success') return;

            const pendingCount = json.data.filter(i => i.estado === 'pendiente').length;
            const badge        = document.getElementById('incidents-tab-badge');

            if (this._lastSeenPending >= 0 && pendingCount > this._lastSeenPending) {
                const diff = pendingCount - this._lastSeenPending;
                if (badge) {
                    badge.textContent = `+${diff}`;
                    badge.classList.remove('hidden');
                    setTimeout(() => badge.classList.add('hidden'), 12000);
                }
                if (typeof ui !== 'undefined' && ui.showToast) {
                    ui.showToast(`${diff} nova${diff === 1 ? '' : 'es'} incidèn${diff === 1 ? 'cia' : 'cies'} pendent${diff === 1 ? '' : 's'}`, 'info', 5000);
                }
            }
            this._lastSeenPending = pendingCount;

            if (this.activeAdminTab === 'incidents') {
                this.adminIncidents = json.data;
                this.populateAdminFilterBarrios();
                this.renderAdminList();
                this.renderKPIs(json.data);
            }
        } catch(e) {
            if (e.code === 'AUTH') clearInterval(this._refreshInterval);
        }
    }, 60000);
};

// Ejecutar la inicialización específica del admin al cargar la página
document.addEventListener('DOMContentLoaded', () => {
    if (document.getElementById('admin-dashboard')) {
        app.initAdminTheme();

        const loginForm = document.getElementById('adminLoginForm');
        if(loginForm) loginForm.addEventListener('submit', app.handleAdminLogin);

        app.checkAdminAuth();
    }
});