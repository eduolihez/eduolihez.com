/**
 * BadaVeu – La Voz de Badalona
 * Plataforma institucional de gestió d'incidències ciutadanes
 *
 * Requereix core.js carregat prèviament (escapeHtml, BADALONA_BARRIOS_ESTATICOS,
 * getStatusBadgeColor, getStatusLabel).
 */

const app = {
    lang: 'ca', 
    map: null,
    centerMarker: null,
    markers: null, 
    allIncidents: [], 
    BARRIOS_MAP: {}, 
    currentFilters: {
        categoria: 'all',
        tipo: 'all',
        barri: 'all',
        showResolved: false
    },
    
    chartInstances: {},
    statsData: null,
    adminIncidents: [],
    adminUsers: [],
    adminRole: null,
    activeAdminTab: 'stats',
    detailMap: null,
    csrfToken: null,
    heatLayer: null,
    heatmapActive: false,

    // Map picker state
    _pickerCalledFromStep: 0,
    _pickerGeoTimer: null,

    // Pagination state
    currentPage: 1,
    totalPages: 1,
    PAGE_LIMIT: 50,
    isLoadingMore: false,

    // Filtros del panel de administración
    adminFilters: {
        status: 'all',
        category: 'all',
        barri: 'all',
        urgency: 'all', 
        search: ''      
    },


    // DICCIONARIO DE TRADUCCIÓN
    i18n: { 
        ca: {
            nav_map: "Mapa", nav_stats: "Dades", nav_admin: "Admin", nav_about: "Sobre",
            nav_guide: "Guia", nav_incidents: "Incidències",
            form_title: "Nova Incidència", cat_infra: "Infraestructura", cat_denuncia: "Denúncia",
            lbl_loc: "Ubicació Exacta", btn_map_select: "SELECCIONAR UBICACIÓ AL MAPA", picker_msg: "Mou el mapa per situar la incidència",
            btn_confirm: "Fixar Ubicació", ph_addr: "Carrer, número...", ph_cp: "Codi Postal",
            loc_searching: "Cercant adreça...", loc_manual: "Escriu l'adreça manualment", loc_unknown: "Adreça desconeguda",
            lbl_title: "Títol", ph_title: "Ex: Fanals trencats...", lbl_type: "Tipus de problema",
            lbl_desc: "Descripció", ph_desc: "Explica els detalls...", lbl_photo: "Afegir una foto",
            btn_send: "Publicar Incidència", alert_ok: "Incidència publicada correctament!", alert_err: "Hi ha hagut un error.",
            alert_loc: "Si us preau, marca la ubicació al mapa abans d'enviar.",
            status_pendiente: "Pendent", status_proceso: "En Procés", status_resuelto: "Solucionat",
            btn_vote: "A mi també", voted_msg: "Votat (Retirar)",
            infra_types: ["Enllumenat", "Neteja", "Voreres", "Parcs", "Mobiliari", "Altres"],
            denun_types: ["Vandalisme", "Soroll", "Ocupació", "Seguretat", "Incivisme", "Altres"],
            lbl_urgency: "Nivell d'Urgència", urg_low: "Baixa", urg_medium: "Mitjana", urg_high: "Alta",
            lbl_email: "Email (Opcional)", ph_email: "nom@exemple.com",
            lbl_barri: "Barri", ph_barri_select: "-- Selecciona Barri --",
            lbl_impact: "A qui afecta?", imp_individual: "Només a mi", imp_collective: "Barri / Comunitat",
            filter_barri_all: "Tots els Barris",
            
            stats_page_title: "Estadístiques en Temps Real",
            stats_incidents_total: "Total Incidències",
            stats_incidents_pending: "Incidències Pendents",
            stats_incidents_solved: "Incidències Solucionades",
            stats_incidents_process: "Incidències En Procés",
            stats_chart_category: "Incidències per Categoria",
            stats_chart_status: "Estat de les Incidències",
            stats_chart_barri: "Top 5 Barris amb Més Incidències",
            stats_empty: "No hi ha prou dades per mostrar estadístiques.",

            // ADMIN KEYS
            admin_list_title: "Gestió d'Incidències",
            admin_list_all: "Tots els Estats",
            admin_list_loading: "Carregant dades...",
            admin_list_empty: "No s'han trobat incidències amb aquests filtres.",
            admin_tab_incidents: "Incidències",
            admin_tab_stats: "Dashboard",
            admin_tab_users: "Usuaris",
            admin_btn_new_user: "Nou Usuari",
            admin_user_role_superadmin: "Superadmin",
            admin_user_role_admin: "Admin",
            admin_user_role_moderator: "Moderador",
            admin_user_access_all: "Tots",
            admin_user_access_infra: "Infraestructura",
            admin_user_access_denuncia: "Denúncia",
            
            // NEW ADMIN STATS KEYS
            admin_stats_total: "Total Registrat",
            admin_stats_pending: "Pendents",
            admin_stats_resolved: "Resolts (Total)",
            admin_stats_monthly: "Tendència Mensual (Creades)",
            admin_stats_weekly_flow: "Flux Operatiu Setmanal (Creació vs Resolució)",
            admin_stats_urgency: "Distribució per Urgència",
            admin_stats_afectacion: "Distribució per Afectació",
            admin_stats_created: "Creades",
            admin_stats_solved_wk: "Resoltes",
            imp_individual: "Individual",
            imp_collective: "Col·lectiva",
            users_delete_confirm: "Estàs segur que vols eliminar aquest usuari administrador?",
            users_delete_error: "No es pot eliminar l'usuari.",
            
            // NEW INCIDENT DETAIL KEYS
            detail_section_location: "Ubicació",
            detail_section_details: "Detalls de la Incidència",
            detail_section_contact: "Contacte i Vots",
            detail_section_actions: "Actualitzar Estat",
            detail_img_view: "Veure Foto Gran",
            detail_urgency_level: "Nivell d'Urgència",
            detail_affects: "Afectació",
            detail_type_problem: "Tipus de Problema",
            detail_address: "Adreça",
            detail_district: "Barri / Districte",
            detail_coords: "Coordenades",
            detail_email: "Email",
            detail_votes: "Vots",
            detail_description: "Descripció",
            detail_btn_update: "Actualitzar",
            filter_urgency_all: "Totes les Urgències",
            filter_search_ph: "Cercar Títol o Descripció...",
            
            // NEW TRANSLATION KEYS FOR READ MORE/LESS (usadas en popup y admin)
            detail_read_more: "Veure més...",
            detail_read_less: "Veure menys",
            
            // USER MANAGEMENT KEYS
            btn_edit_user: "Editar Administrador",
            ph_password_new: "Mín. 8 caràcters",
            ph_password_optional: "Deixar buit per no canviar",
            lbl_password: "Contrasenya",

            // ABOUT PAGE KEYS (NEW)
            about_credits_html: `
                <h2 style="color: var(--primary);">Crèdits del Desenvolupament</h2>
                <p style="margin-top: 15px;">Aquesta plataforma ha estat dissenyada i desenvolupada per:</p>
                
                <h3 style="margin-bottom: 5px; color: var(--text-main);">Edu Olivares</h3>
                <p style="font-size: 0.95rem; line-height: 1.8; color: var(--text-light);">
                    <i class="ri-global-line" style="width: 20px;"></i> <a href="http://eduolihez.com" target="_blank" style="color: var(--primary); text-decoration: none;">eduolihez.com</a><br>
                    <i class="ri-instagram-line" style="width: 20px;"></i> <a href="https://instagram.com/eduolihez" target="_blank" style="color: var(--primary); text-decoration: none;">@eduolihez</a><br>
                    <i class="ri-linkedin-box-fill" style="width: 20px;"></i> <a href="https://linkedin.com/in/eduolihez" target="_blank" style="color: var(--primary); text-decoration: none;">linkedin.com/in/eduolihez</a>
                </p>
            `,
            page_title_about: "Sobre BadaVeu — Plataforma cívica de Badalona",
            page_title_guia: "Com reportar una incidència a Badalona — BadaVeu",
            page_title_incidents: "Incidències obertes i resoltes de Badalona — BadaVeu",
            page_title_stats: "Estadístiques d'incidències de Badalona — BadaVeu",
            about_section_credits: "Crèdits del Desenvolupament",
            step_loc_short: "Ubicació",
            step_detail_short: "Detalls",
            step_send_short: "Enviar",
            heatmap_on: "🔥 Calor",
            heatmap_off: "📍 Marcadors",
            show_resolved: "Veure resoltes",
            hide_resolved: "Ocultar resoltes",
            link_copied: "Enllaç copiat!",
            export_csv: "Exportar CSV",
            admin_tab_map: "Mapa",
            admin_tab_priority: "Prioritat",
            admin_tab_activity: "Activitat",
            priority_view_title: "Vista de Prioritat",
            priority_score_label: "Score",
            priority_info: "Ordenat per Score d'Urgència = (Vots × 0.4) + (Pes urgència × 0.6) — alta=3, mitjana=2, baixa=1",
            lbl_status: "Estat",
            lbl_category: "Categoria",
            lbl_votes: "Vots",
            stats_most_viewed: "Incidència Més Vista",
            load_more: "Carrega més incidències",
            load_more_loading: "Carregant...",
            load_more_end: "No hi ha més incidències",
        },
        es: {
            nav_map: "Mapa", nav_stats: "Datos", nav_admin: "Admin", nav_about: "Sobre",
            nav_guide: "Guía", nav_incidents: "Incidencias",
            form_title: "Nueva Incidencia", cat_infra: "Infraestructura", cat_denuncia: "Denuncia",
            lbl_loc: "Ubicación Exacta", btn_map_select: "SELECCIONAR UBICACIÓN EN EL MAPA", picker_msg: "Mueve el mapa para situar la incidencia",
            btn_confirm: "Fijar Ubicación", ph_addr: "Calle, número...", ph_cp: "Código Postal",
            loc_searching: "Buscando dirección...", loc_manual: "Escribe la dirección manualmente", loc_unknown: "Dirección desconocida",
            lbl_title: "Título", ph_title: "Ej: Farolas rotas...", lbl_type: "Tipo de problema",
            lbl_desc: "Descripción", ph_desc: "Explica los detalles...", lbl_photo: "Añadir una foto",
            btn_send: "Publicar Incidencia", alert_ok: "¡Incidencia publicada correctamente!", alert_err: "Ha ocurrido un error.",
            alert_loc: "Por favor, marca la ubicación en el mapa antes de enviar.",
            status_pendiente: "Pendiente", status_proceso: "En Proceso", status_resuelto: "Solucionado",
            btn_vote: "A mí también", voted_msg: "Votado (Retirar)",
            infra_types: ["Alumbrado", "Limpieza", "Aceras", "Parques", "Mobiliario", "Otros"],
            denun_types: ["Vandalismo", "Ruido", "Ocupación", "Seguridad", "Incivismo", "Otros"],
            lbl_urgency: "Nivel de Urgencia", urg_low: "Baja", urg_medium: "Media", urg_high: "Alta",
            lbl_email: "Email (Opcional)", ph_email: "nombre@ejemplo.com",
            lbl_barri: "Barrio", ph_barri_select: "-- Selecciona Barrio --",
            lbl_impact: "A quién afecta?", imp_individual: "Solo a mí", imp_collective: "Barrio / Comunidad",
            filter_barri_all: "Todos los Barrios",
            
            stats_page_title: "Estadísticas en Tiempo Real",
            stats_incidents_total: "Total Incidencias",
            stats_incidents_pending: "Incidencias Pendientes",
            stats_incidents_solved: "Incidencias Solucionadas",
            stats_incidents_process: "Incidencias En Procéso",
            stats_chart_category: "Incidencias por Categoría",
            stats_chart_status: "Estado de las Incidencias",
            stats_chart_barri: "Top 5 Barrios con Más Incidencias",
            stats_empty: "No hay datos suficientes para mostrar estadísticas.",

            // ADMIN KEYS
            admin_list_title: "Gestión de Incidencias",
            admin_list_all: "Todos los Estados",
            admin_list_loading: "Cargando datos...",
            admin_list_empty: "No se han encontrado incidencias con estos filtros.",
            admin_tab_incidents: "Incidencias",
            admin_tab_stats: "Dashboard",
            admin_tab_users: "Usuarios",
            admin_btn_new_user: "Nuevo Usuario",
            admin_user_role_superadmin: "Superadmin",
            admin_user_role_admin: "Admin",
            admin_user_role_moderator: "Moderador",
            admin_user_access_all: "Todos",
            admin_user_access_infra: "Infraestructura",
            admin_user_access_denuncia: "Denuncia",
            
            // NEW ADMIN STATS KEYS
            admin_stats_total: "Total Registrado",
            admin_stats_pending: "Pendientes",
            admin_stats_resolved: "Resueltas (Total)",
            admin_stats_monthly: "Tendencia Mensual (Creadas)",
            admin_stats_weekly_flow: "Flujo Operativo Semanal (Creación vs Resolución)",
            admin_stats_urgency: "Distribució por Urgencia",
            admin_stats_afectacion: "Distribució por Afectación",
            admin_stats_created: "Creadas",
            admin_stats_solved_wk: "Resueltas",
            imp_individual: "Individual",
            imp_collective: "Colectiva",
            users_delete_confirm: "Estás seguro que quieres eliminar a este usuario administrador?",
            users_delete_error: "No se puede eliminar el usuario.",

            // NEW INCIDENT DETAIL KEYS
            detail_section_location: "Ubicación",
            detail_section_details: "Detalles de la Incidencia",
            detail_section_contact: "Contacto y Votos",
            detail_section_actions: "Actualizar Estado",
            detail_img_view: "Ver Foto Grande",
            detail_urgency_level: "Nivel de Urgencia",
            detail_affects: "Afectación",
            detail_type_problem: "Tipo de Problema",
            detail_address: "Dirección",
            detail_district: "Barrio / Distrito",
            detail_coords: "Coordenadas",
            detail_email: "Email",
            detail_votes: "Votos",
            detail_description: "Descripción",
            detail_btn_update: "Actualizar",
            filter_urgency_all: "Todas las Urgencias",
            filter_search_ph: "Buscar Título o Descripción...",
            
            // NEW TRANSLATION KEYS FOR READ MORE/LESS
            detail_read_more: "Ver más...",
            detail_read_less: "Ver menos",

            // USER MANAGEMENT KEYS
            btn_edit_user: "Editar Administrador",
            ph_password_new: "Mín. 8 caracteres",
            ph_password_optional: "Dejar vacío para no cambiar",
            lbl_password: "Contraseña",

            // ABOUT PAGE KEYS (NEW)
            about_credits_html: `
                <h2 style="color: var(--primary);">Créditos del Desarrollo</h2>
                <p style="margin-top: 15px;">Esta plataforma ha sido diseñada y desarrollada por:</p>
                
                <h3 style="margin-bottom: 5px; color: var(--text-main);">Edu Olivares</h3>
                <p style="font-size: 0.95rem; line-height: 1.8; color: var(--text-light);">
                    <i class="ri-global-line" style="width: 20px;"></i> <a href="http://eduolihez.com" target="_blank" style="color: var(--primary); text-decoration: none;">eduolihez.com</a><br>
                    <i class="ri-instagram-line" style="width: 20px;"></i> <a href="https://instagram.com/eduolihez" target="_blank" style="color: var(--primary); text-decoration: none;">@eduolihez</a><br>
                    <i class="ri-linkedin-box-fill" style="width: 20px;"></i> <a href="https://linkedin.com/in/eduolihez" target="_blank" style="color: var(--primary); text-decoration: none;">linkedin.com/in/eduolihez</a>
                </p>
            `,
            page_title_about: "Sobre BadaVeu — Plataforma cívica de Badalona",
            page_title_guia: "Cómo reportar una incidencia en Badalona — BadaVeu",
            page_title_incidents: "Incidencias abiertas y resueltas de Badalona — BadaVeu",
            page_title_stats: "Estadísticas de incidencias de Badalona — BadaVeu",
            about_section_credits: "Créditos del Desarrollo",
            step_loc_short: "Ubicación",
            step_detail_short: "Detalles",
            step_send_short: "Enviar",
            heatmap_on: "🔥 Calor",
            heatmap_off: "📍 Marcadores",
            show_resolved: "Ver resueltas",
            hide_resolved: "Ocultar resueltas",
            link_copied: "¡Enlace copiado!",
            export_csv: "Exportar CSV",
            admin_tab_map: "Mapa",
            admin_tab_priority: "Prioridad",
            admin_tab_activity: "Actividad",
            priority_view_title: "Vista de Prioridad",
            priority_score_label: "Score",
            priority_info: "Ordenado por Score de Urgencia = (Votos × 0.4) + (Peso urgencia × 0.6) — alta=3, media=2, baja=1",
            lbl_status: "Estado",
            lbl_category: "Categoría",
            lbl_votes: "Votos",
            stats_most_viewed: "Incidencia Más Vista",
            load_more: "Cargar más incidencias",
            load_more_loading: "Cargando...",
            load_more_end: "No hay más incidencias",
        }
    },
    
    // Delegat a core.js — app.lang correcte gràcies al binding sobre 'this'
    formatDate: function(dateString) {
        if (!dateString) return 'Data Desconeguda';
        try {
            const date = new Date(dateString);
            return date.toLocaleString(this.lang, {
                year: 'numeric', month: 'short', day: 'numeric',
                hour: '2-digit', minute: '2-digit', hour12: false,
            });
        } catch (e) { return 'Data Invàlida'; }
    },

    // FUNCIÓN NUEVA: Toggle para la descripción larga en el MAPA POPUP
    togglePopupDescription: function(id, btn) {
        const fullTextEl = document.getElementById(`popup-full-desc-${id}`);
        const shortTextEl = document.getElementById(`popup-short-desc-${id}`);
        const btnTextEl = document.getElementById(`popup-text-${id}`);
        const btnIconEl = document.getElementById(`popup-icon-${id}`);

        if (fullTextEl.style.display === 'none') {
            // Mostrar texto completo
            fullTextEl.style.display = '';
            shortTextEl.style.display = 'none';
            btnTextEl.textContent = app.i18n[app.lang].detail_read_less;
            btnIconEl.className = 'ri-arrow-up-s-line';
        } else {
            // Mostrar texto corto
            fullTextEl.style.display = 'none';
            shortTextEl.style.display = '';
            btnTextEl.textContent = app.i18n[app.lang].detail_read_more;
            btnIconEl.className = 'ri-arrow-down-s-line';
        }
    },

    // FUNCIÓN EXISTENTE: Toggle para la descripción larga en el PANEL DE DETALLES (Admin)
    toggleDescription: function(id) {
        const fullTextEl = document.getElementById(`full-desc-${id}`);
        const shortTextEl = document.getElementById(`short-desc-${id}`);
        const btn = document.getElementById(`desc-toggle-btn-${id}`);

        if (fullTextEl.classList.contains('hidden')) {
            // Expande
            fullTextEl.classList.remove('hidden');
            shortTextEl.classList.add('hidden');
            btn.innerHTML = `<i class="ri-arrow-up-s-line"></i> ${app.i18n[app.lang].detail_read_less}`;
        } else {
            // Contrae
            fullTextEl.classList.add('hidden');
            shortTextEl.classList.remove('hidden');
            btn.innerHTML = `<i class="ri-arrow-down-s-line"></i> ${app.i18n[app.lang].detail_read_more}`;
        }
    },


    // ── CSRF ──────────────────────────────────────────────────────────────────
    // Token cached en memòria — es reseteja a cada càrrega de pàgina (no sessionStorage).
    getCsrfToken: async function() {
        if (this.csrfToken) return this.csrfToken;
        try {
            const res = await fetch('api/index.php?action=get_csrf', { credentials: 'same-origin' });
            const d   = await res.json();
            this.csrfToken = d.csrf_token;
        } catch(_) { this.csrfToken = ''; }
        return this.csrfToken;
    },

    refreshCsrfToken: async function() {
        this.csrfToken = null;
        return this.getCsrfToken();
    },

    // ── Dark mode eliminat — BadaVeu és 100% Mode Clar (WCAG AA/AAA) ────────────
    initDarkMode: function() {
        document.body.classList.remove('dark');
        localStorage.removeItem('badaveu_theme');
    },

    // ── Form progress ─────────────────────────────────────────────────────────
    updateFormProgress: function(step) {
        document.querySelectorAll('.progress-step').forEach(el => {
            const s = parseInt(el.dataset.step);
            el.classList.toggle('active', s === step);
            el.classList.toggle('done',   s < step);
        });
        document.querySelectorAll('.progress-line').forEach((el, i) => {
            el.classList.toggle('done', i + 1 < step);
        });
    },

    // INICIALIZACIÓN PRINCIPAL
    init: function() {
        this.initDarkMode();
        this.getCsrfToken();
        const savedLang = localStorage.getItem('badaveu_lang') || 'ca';
        app.setLang(savedLang);
        this.populateFormBarrios();
        
        // Determinar qué enlace de navegación inferior está activo
        const currentPath = window.location.pathname.split('/').pop() || 'index.html';
        document.querySelectorAll('.bottom-nav .nav-item').forEach(item => {
            const href = item.getAttribute('href');
            if (href === currentPath || (currentPath === 'admin.html' && href === 'index.html')) {
                item.classList.add('active');
            } else {
                item.classList.remove('active');
            }
        });
        
        if (document.getElementById('slide-panel')) {
            document.getElementById('slide-panel').classList.add('closed');
            this.handleCategoryChange('infraestructura', false); 
        }

        const form = document.getElementById('incidentForm');
        if (form) {
            form.addEventListener('submit', this.handleSubmit);
            form.querySelectorAll('.modern-input[required], .modern-select[required], .modern-textarea[required]').forEach(el => {
                el.addEventListener('blur', () => app.validateField(el));
                el.addEventListener('input', () => { if (el.classList.contains('field-error')) app.validateField(el); });
            });
        }
        
        if (document.getElementById('map')) {
            ui.loadApp();

            // Auto-open report flow when arriving from another page via ?action=new
            const _urlParams = new URLSearchParams(window.location.search);
            if (_urlParams.get('action') === 'new') {
                window.history.replaceState({}, '', window.location.pathname);
                setTimeout(() => ui.startReportFlow(), 800);
            }

            // Keyboard: Escape closes slide-panel or incident card
            document.addEventListener('keydown', (e) => {
                if (e.key === 'Escape') {
                    const card = document.getElementById('incident-bottom-card');
                    if (card && card.classList.contains('open')) {
                        app.closeIncidentCard(); return;
                    }
                    const panel = document.getElementById('slide-panel');
                    if (panel && panel.classList.contains('open')) {
                        ui.closePanel();
                    }
                }
            });

            // Swipe-down gesture to close incident-bottom-card
            const ibc = document.getElementById('incident-bottom-card');
            if (ibc) {
                let touchStartY = 0;
                let ibcDragging = false;
                ibc.addEventListener('touchstart', (e) => {
                    touchStartY = e.touches[0].clientY;
                    ibcDragging = true;
                    ibc.style.transition = 'none';
                }, { passive: true });
                ibc.addEventListener('touchmove', (e) => {
                    if (!ibcDragging) return;
                    const delta = e.touches[0].clientY - touchStartY;
                    if (delta > 0) ibc.style.transform = `translateY(${delta}px)`;
                }, { passive: true });
                ibc.addEventListener('touchend', (e) => {
                    ibcDragging = false;
                    ibc.style.transition = '';
                    const delta = e.changedTouches[0].clientY - touchStartY;
                    if (delta > 100) {
                        app.closeIncidentCard();
                    } else {
                        ibc.style.transform = '';
                    }
                }, { passive: true });
            }
        } else if (document.getElementById('incidents-page-container')) {
            this.loadIncidentsPage();
        } else if (document.getElementById('stats-content') || document.getElementById('stats-loading')) {
            this.loadStats();
        } else if (document.getElementById('admin-dashboard')) {
            
            // Listeners para el Admin Panel
            document.getElementById('logoutBtnMobile')?.addEventListener('click', this.handleAdminLogout);
            document.getElementById('logoutBtn')?.addEventListener('click', this.handleAdminLogout);
            document.querySelectorAll('.admin-tab-btn').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    app.setActiveAdminTab(e.currentTarget.getAttribute('data-tab'));
                });
            });
            
            // Listeners para los filtros de Admin
            document.getElementById('filter-status')?.addEventListener('change', () => this.loadAdminData());
            document.getElementById('filter-category')?.addEventListener('change', () => this.loadAdminData());
            document.getElementById('filter-barri-admin')?.addEventListener('change', () => this.loadAdminData());
            document.getElementById('filter-urgency')?.addEventListener('change', () => this.loadAdminData());
            document.getElementById('filter-search')?.addEventListener('input', () => this.loadAdminData());
            
            // El checkAdminAuth inicia todo
            this.checkAdminAuth();
            const loginForm = document.getElementById('adminLoginForm');
            if(loginForm) loginForm.addEventListener('submit', this.handleAdminLogin);
        }
    },
    
    // --- LÓGICA DEL MAPA Y FILTROS PÚBLICOS ---
    // Debounce timer for moveend-triggered bbox reloads
    _bboxDebounce: null,

    loadIncidents: async function() {
        if (document.getElementById('map') && !this.map) {
            this.map = L.map('map', {zoomControl: false}).setView([41.450, 2.247], 14);
            L.tileLayer(CARTO_TILE_URL, {
                attribution: '© CARTO', maxZoom: 20
            }).addTo(this.map);

            this.markers = L.markerClusterGroup({ showCoverageOnHover: false, maxClusterRadius: 40 });
            this.map.addLayer(this.markers);

            this.map.on('click', () => app.closeIncidentCard());

            // Reload visible markers on pan/zoom with debounce
            this.map.on('moveend', () => {
                clearTimeout(app._bboxDebounce);
                app._bboxDebounce = setTimeout(() => app.loadIncidentsInView(), 600);
            });
        }

        // Reset pagination state on fresh load
        this.currentPage = 1;
        this.allIncidents = [];

        // Build bbox from current map bounds when the map is ready
        let bboxParam = '';
        if (this.map) {
            const b = this.map.getBounds();
            bboxParam = `&bbox=${b.getSouth()},${b.getWest()},${b.getNorth()},${b.getEast()}`;
        }

        try {
            const res = await fetch(`api/index.php?action=public_data&page=1&limit=${this.PAGE_LIMIT}${bboxParam}`);
            if (!res.ok) throw new Error('API request failed');
            const json = await res.json();

            // Handle both paginated envelope {data,total,page,pages} and legacy bare array
            const incoming = Array.isArray(json) ? json : (json.data || []);
            this.totalPages  = json.pages ?? 1;
            this.currentPage = json.page  ?? 1;
            this.allIncidents = incoming;

            try {
                localStorage.setItem('badaveu_last_incidents', JSON.stringify(this.allIncidents.slice(0, 20)));
            } catch(e) {}

            this.populateFilterBarrios();
            if (this.map) this.applyFilters();

            // Bottom Sheet — initial render
            this.renderSheetIncidents(this.allIncidents, false);
            const resolved = this.allIncidents.filter(i => i.estado === 'resuelto');
            this.renderSheetLogros(resolved);
            this._updateLoadMoreBtn();
        } catch(_) {}
    },

    loadMoreIncidents: async function() {
        if (this.isLoadingMore || this.currentPage >= this.totalPages) return;
        this.isLoadingMore = true;

        const btn = document.getElementById('btn-load-more');
        const lbl = document.getElementById('load-more-label');
        if (btn) btn.disabled = true;
        if (lbl) lbl.textContent = this.i18n[this.lang].load_more_loading;

        try {
            const nextPage = this.currentPage + 1;
            const res = await fetch(`api/index.php?action=public_data&page=${nextPage}&limit=${this.PAGE_LIMIT}`);
            if (!res.ok) throw new Error('API error');
            const json = await res.json();

            const incoming = Array.isArray(json) ? json : (json.data || []);
            this.totalPages  = json.pages ?? this.totalPages;
            this.currentPage = json.page  ?? nextPage;

            // Append new incidents to master list
            this.allIncidents = this.allIncidents.concat(incoming);

            // Add new markers to cluster group (renderMarkers clears all — use addLayer instead)
            if (this.map && this.markers) {
                incoming.forEach(inc => {
                    let color = '#002D5A', iconHtml;
                    if (inc.estado === 'resuelto') {
                        iconHtml = `<div style="background:#047857;width:32px;height:32px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:15px;"><i class="ri-check-line"></i></div>`;
                    } else {
                        let iconClass = 'ri-hammer-line';
                        if (inc.categoria === 'denuncia') { color = '#ef4444'; iconClass = 'ri-alert-line'; }
                        if (inc.estado === 'proceso')     { color = '#f59e0b'; iconClass = 'ri-time-line'; }
                        iconHtml = `<div style="background:${color};width:32px;height:32px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:15px;"><i class="${iconClass}"></i></div>`;
                    }
                    const icon = L.divIcon({ html: iconHtml, className: 'custom-pin', iconSize:[34,34], iconAnchor:[17,17] });
                    this.markers.addLayer(L.marker([inc.lat, inc.lng], {icon}));
                });
            }

            // Append new cards to bottom sheet (don't re-render from scratch)
            this.renderSheetIncidents(incoming, true);

            // Refresh logros with full resolved list
            const resolved = this.allIncidents.filter(i => i.estado === 'resuelto');
            this.renderSheetLogros(resolved);

            // Refresh barri filter with any new barrios
            this.populateFilterBarrios();
        } catch(_) {
        } finally {
            this.isLoadingMore = false;
            this._updateLoadMoreBtn();
        }
    },

    // Reload only the markers visible in the current map viewport (bbox mode).
    loadIncidentsInView: async function() {
        if (!this.map) return;
        const b = this.map.getBounds();
        const bbox = `${b.getSouth()},${b.getWest()},${b.getNorth()},${b.getEast()}`;
        try {
            const res  = await fetch(`api/index.php?action=public_data&page=1&limit=200&bbox=${bbox}`);
            if (!res.ok) return;
            const json = await res.json();
            const incoming = Array.isArray(json) ? json : (json.data || []);
            this.allIncidents = incoming;
            this.applyFilters();
        } catch(_) {}
    },

    _updateLoadMoreBtn: function() {
        const wrapper = document.getElementById('sheet-load-more-wrapper');
        const lbl     = document.getElementById('load-more-label');
        if (!wrapper) return;
        if (this.currentPage >= this.totalPages) {
            // Hide button if all pages loaded
            wrapper.style.display = 'none';
        } else {
            wrapper.style.display = 'block';
            if (lbl) lbl.textContent = this.i18n[this.lang].load_more;
            const btn = document.getElementById('btn-load-more');
            if (btn) btn.disabled = false;
        }
    },

    renderMarkers: function(data) {
        if (!this.markers) return;
        this.markers.clearLayers();
        data.forEach(inc => {
            const latLng = [inc.lat, inc.lng];
            let color = '#002D5A';
            let iconHtml;

            if (inc.estado === 'resuelto') {
                iconHtml = `<div style="background:#047857;width:32px;height:32px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:15px;"><i class="ri-check-line"></i></div>`;
            } else {
                let iconClass = 'ri-hammer-line';
                if (inc.categoria === 'denuncia') { color = '#ef4444'; iconClass = 'ri-alert-line'; }
                if (inc.estado === 'proceso')     { color = '#f59e0b'; iconClass = 'ri-time-line'; }
                iconHtml = `<div style="background:${color};width:32px;height:32px;border-radius:50%;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,0.2);display:flex;align-items:center;justify-content:center;color:#fff;font-size:15px;"><i class="${iconClass}"></i></div>`;
            }

            const icon = L.divIcon({
                html: iconHtml,
                className: 'custom-pin', iconSize: [34, 34], iconAnchor: [17, 17]
            });

            // Marker: click obre l'Incident Bottom Card (no popup natiu Leaflet)
            const marker = L.marker(latLng, {icon})
                .on('click', (e) => {
                    if (app.map) {
                        app.map.panTo(e.latlng, { animate: true, duration: 0.4 });
                        app.map.panBy([0, -80], { animate: true, duration: 0.4 });
                    }
                    app.openIncidentCard(inc);
                });

            this.markers.addLayer(marker);
        });
    },

    toggleVote: async function(id, btn, originalColor) {
        const isVoted = localStorage.getItem(`voted_${id}`);
        const action  = isVoted ? 'unvote' : 'vote';
        const endpoint = `api/index.php?action=${action}&id=${id}`;

        const votesElement = document.getElementById(`votes-${id}`);
        btn.disabled = true;

        // Fetch helper with automatic CSRF retry on 403 (stale token)
        const doRequest = async (isRetry = false) => {
            const token = await app.getCsrfToken();
            const fd = new FormData();
            fd.append('_csrf_token', token);
            const response = await fetch(endpoint, { method: 'POST', body: fd });
            if (response.status === 403 && !isRetry) {
                sessionStorage.removeItem('csrf_token');
                app.csrfToken = null;
                return doRequest(true);
            }
            return response.json();
        };

        try {
            const data = await doRequest();

            if (data.status === 'success') {
                const newVotes = data.new_votes;
                votesElement.textContent = newVotes;

                if (action === 'vote') {
                    localStorage.setItem(`voted_${id}`, 'true');
                    btn.style.background = '#dcfce7'; 
                    btn.style.color = '#166534';     
                    btn.querySelector('i').className = 'ri-check-line';
                    btn.querySelector('span').textContent = this.i18n[app.lang].voted_msg;
                } else {
                    localStorage.removeItem(`voted_${id}`);
                    btn.style.background = '#f1f5f9'; 
                    btn.style.color = originalColor;  
                    btn.querySelector('i').className = 'ri-thumb-up-fill';
                    btn.querySelector('span').textContent = this.i18n[app.lang].btn_vote;
                }
            } else {
                alert(this.i18n[app.lang].alert_err + ": " + (data.message || "Error al votar."));
            }
        } catch(_) {
            alert("Error de conexión al servidor. Revisa tu conexión o el log del servidor.");
        } finally {
             btn.disabled = false;
        }
    },

    // ── INCIDENT BOTTOM CARD (reemplaça popups Leaflet) ─────────────────────

    openIncidentCard: function(inc) {
        const card = document.getElementById('incident-bottom-card');
        if (!card) return;

        const color = getStatusBadgeColor(inc.estado, inc.categoria);
        const statusLabels = { pendiente: 'Pendent', proceso: 'En Procés', resuelto: 'Resolt', denegado: 'Denegat' };
        const isVoted = localStorage.getItem(`voted_${inc.id}`);
        const btnVoteClass = isVoted ? 'ibc-btn ibc-btn-voted' : 'ibc-btn';
        const btnVoteIcon  = isVoted ? 'ri-check-line' : 'ri-thumb-up-fill';
        const btnVoteText  = isVoted ? (this.i18n[this.lang].voted_msg || 'Suportat') : (this.i18n[this.lang].btn_vote || 'Donar suport');
        const catLabel = inc.categoria === 'infraestructura' ? this.i18n[this.lang].cat_infra : this.i18n[this.lang].cat_denuncia;
        const statusLabel = statusLabels[inc.estado] || inc.estado || '—';

        const body = document.getElementById('ibc-body-content');
        if (!body) return;

        body.innerHTML = `
            <div class="ibc-header-row">
                <div class="ibc-badges">
                    <span class="card-status" style="background:${color};color:#fff;padding:3px 10px;border-radius:20px;font-size:0.72rem;font-weight:700;">${escapeHtml(statusLabel.toUpperCase())}</span>
                    <span class="sheet-card-badge ${inc.categoria === 'denuncia' ? 'badge-denuncia' : ''}">${escapeHtml(catLabel)}</span>
                </div>
            </div>
            <div class="ibc-title">${escapeHtml(inc.titulo)}</div>
            <div class="ibc-meta">
                <span><i class="ri-map-pin-line"></i> ${escapeHtml(inc.barri || '—')}</span>
                <span><i class="ri-calendar-line"></i> ${this.formatDate(inc.created_at)}</span>
                <span><i class="ri-thumb-up-fill" style="color:${color};"></i> <span id="votes-${inc.id}" class="ibc-votes-count">${inc.votos || 0}</span></span>
            </div>
            ${inc.foto_url ? `<img class="ibc-photo" src="${escapeHtml(inc.foto_url)}" alt="" loading="lazy">` : ''}
            ${inc.descripcion ? `<div class="ibc-desc">${escapeHtml(inc.descripcion.substring(0,120))}${inc.descripcion.length > 120 ? '...' : ''}</div>` : ''}
            <div class="ibc-actions">
                <button id="ibc-vote-btn-${inc.id}" class="${btnVoteClass}"
                        onclick="app.toggleVote(${inc.id}, this, '${color}')"
                        aria-label="Donar suport">
                    <i class="${btnVoteIcon}"></i> <span>${btnVoteText}</span>
                </button>
                <a class="ibc-btn ibc-btn-detail" href="incident.html?id=${inc.id}" aria-label="Veure detalls">
                    <i class="ri-external-link-line"></i> Detalls
                </a>
                <button class="ibc-btn"
                        onclick="app.shareIncident(${inc.id}, ${JSON.stringify(inc.titulo)})"
                        aria-label="Compartir incidència">
                    <i class="ri-share-line" aria-hidden="true"></i>
                </button>
            </div>
        `;

        card.classList.add('open');
        card.removeAttribute('inert');
        card.setAttribute('aria-hidden', 'false');
    },

    closeIncidentCard: function() {
        const card = document.getElementById('incident-bottom-card');
        if (!card) return;
        card.classList.remove('open');
        card.setAttribute('inert', '');
        card.setAttribute('aria-hidden', 'true');
    },

    // ── Web Share API + WhatsApp / X fallback ────────────────────────────────
    shareIncident: function(id, titulo) {
        const url  = `${window.location.origin}/incident.html?id=${id}`;
        const text = `🏛️ BadaVeu — ${titulo}`;

        if (navigator.share) {
            navigator.share({ title: titulo, text, url }).catch(err => {
                if (err.name === 'AbortError') return;
                navigator.clipboard?.writeText(url)
                    .then(() => ui.showToast(this.i18n[this.lang].link_copied || 'Enllaç copiat!', 'success'))
                    .catch(() => this._showShareMenu(id, titulo, url));
            });
            return;
        }
        this._showShareMenu(id, titulo, url);
    },

    _showShareMenu: function(id, titulo, url) {
        document.getElementById('share-menu-popup')?.remove();

        const safeUrl  = encodeURIComponent(url);
        const safeText = encodeURIComponent(`🏛️ BadaVeu — ${titulo}: ${url}`);
        const waHref   = `https://wa.me/?text=${safeText}`;
        const xHref    = `https://twitter.com/intent/tweet?text=${safeText}`;

        const popup = document.createElement('div');
        popup.id = 'share-menu-popup';
        popup.setAttribute('role', 'dialog');
        popup.setAttribute('aria-label', this.i18n[this.lang].link_copied ? 'Compartir incidència' : 'Share incident');
        popup.innerHTML = `
            <div class="share-overlay" onclick="document.getElementById('share-menu-popup').remove()" aria-hidden="true"></div>
            <div class="share-card" role="menu">
                <p class="share-card-title"><i class="ri-share-line" aria-hidden="true"></i> Compartir incidència</p>
                <button class="share-btn" role="menuitem"
                        onclick="navigator.clipboard.writeText('${url}').then(()=>{ui.showToast('${this.i18n[this.lang].link_copied || 'Copiat!'}','success');document.getElementById('share-menu-popup').remove()})">
                    <i class="ri-clipboard-line" aria-hidden="true"></i> Copiar Enllaç
                </button>
                <a class="share-btn share-btn-wa" href="${waHref}" target="_blank" rel="noopener noreferrer" role="menuitem"
                   onclick="setTimeout(()=>document.getElementById('share-menu-popup')?.remove(),200)">
                    <i class="ri-whatsapp-line" aria-hidden="true"></i> WhatsApp
                </a>
                <a class="share-btn share-btn-x" href="${xHref}" target="_blank" rel="noopener noreferrer" role="menuitem"
                   onclick="setTimeout(()=>document.getElementById('share-menu-popup')?.remove(),200)">
                    <i class="ri-twitter-x-line" aria-hidden="true"></i> X (Twitter)
                </a>
            </div>`;
        document.body.appendChild(popup);
        popup.querySelector('.share-btn').focus();
    },

    // ── INCIDENTS PAGE (incidents.html) ──────────────────────────────────────

    loadIncidentsPage: async function() {
        this.currentPage = 1;
        this.allIncidents = [];

        try {
            const res = await fetch(`api/index.php?action=public_data&page=1&limit=${this.PAGE_LIMIT}`);
            if (!res.ok) throw new Error('API error');
            const json = await res.json();
            const incoming = Array.isArray(json) ? json : (json.data || []);
            this.totalPages  = json.pages ?? 1;
            this.currentPage = json.page  ?? 1;
            this.allIncidents = incoming;

            this.renderSheetIncidents(this.allIncidents, false);
            const resolved = this.allIncidents.filter(i => i.estado === 'resuelto');
            this.renderSheetLogros(resolved);
            this._updateLoadMoreBtn();

            // Populate barri filter
            const barriSel = document.getElementById('incidents-filter-barri');
            if (barriSel) {
                const barris = [...new Set(this.allIncidents.map(i => i.barri).filter(Boolean))].sort();
                barris.forEach(b => {
                    const opt = document.createElement('option');
                    opt.value = b; opt.textContent = b;
                    barriSel.appendChild(opt);
                });
            }
        } catch(e) {
            const listEl = document.getElementById('incidents-list-container');
            if (listEl) listEl.innerHTML = '<div class="sheet-placeholder"><i class="ri-alert-line"></i> Error carregant incidències.</div>';
        }
    },

    filterIncidentsList: function(barriValue) {
        const filtered = barriValue === 'all'
            ? this.allIncidents
            : this.allIncidents.filter(i => i.barri === barriValue);
        this.renderSheetIncidents(filtered.filter(i => i.estado !== 'resuelto'), false);
        this.renderSheetLogros(filtered.filter(i => i.estado === 'resuelto'));
    },

    setFilter: function(element) {
        const key = element.getAttribute('data-filter-key');
        let value = element.value || element.getAttribute('data-filter-value');
        
        if (key === 'categoria') {
            // Toggle logic for category buttons
            if (this.currentFilters.categoria === value) {
                value = 'all';
            }
            document.querySelectorAll(`.filter-btn[data-filter-key="categoria"]`).forEach(btn => btn.classList.remove('active'));
            if (value !== 'all') {
                element.classList.add('active');
            } else {
                document.querySelector(`.filter-btn[data-filter-key="categoria"][data-filter-value="all"]`)?.classList.add('active');
            }
            // Clear tipo filter when switching category
            this.currentFilters.tipo = 'all';
            document.querySelectorAll(`.filter-btn[data-filter-key="tipo"]`).forEach(btn => btn.classList.remove('active'));

        } else if (key === 'tipo') {
            // Toggle logic for tipo buttons
            if (this.currentFilters.tipo === value) {
                value = 'all';
            }
            document.querySelectorAll(`.filter-btn[data-filter-key="tipo"]`).forEach(btn => btn.classList.remove('active'));
            if (value !== 'all') {
                element.classList.add('active');
                // Clear categoria when a tipo filter is active
                this.currentFilters.categoria = 'all';
                document.querySelectorAll(`.filter-btn[data-filter-key="categoria"]`).forEach(btn => btn.classList.remove('active'));
                document.querySelector(`.filter-btn[data-filter-key="categoria"][data-filter-value="all"]`)?.classList.add('active');
            } else {
                document.querySelector(`.filter-btn[data-filter-key="categoria"][data-filter-value="all"]`)?.classList.add('active');
            }

        } else if (key === 'barri') {
            // Reset category and tipo filters when changing neighbourhood
            this.currentFilters.categoria = 'all';
            this.currentFilters.tipo = 'all';
            document.querySelectorAll(`.filter-btn[data-filter-key="categoria"]`).forEach(btn => btn.classList.remove('active'));
            document.querySelector(`.filter-btn[data-filter-key="categoria"][data-filter-value="all"]`)?.classList.add('active');
            document.querySelectorAll(`.filter-btn[data-filter-key="tipo"]`).forEach(btn => btn.classList.remove('active'));
        }

        this.currentFilters[key] = value;

        // Sync aria-pressed on all filter buttons to match visual active state
        document.querySelectorAll('.filter-btn[data-filter-key]').forEach(btn => {
            const btnKey = btn.getAttribute('data-filter-key');
            const btnVal = btn.getAttribute('data-filter-value');
            if (btnKey && btnVal !== null) {
                btn.setAttribute('aria-pressed',
                    String(this.currentFilters[btnKey] === btnVal));
            }
        });
        // "Tots" button is pressed when both categoria and tipo are 'all'
        const allBtn = document.querySelector('.filter-btn[data-filter-value="all"][data-filter-key="categoria"]');
        if (allBtn) {
            allBtn.setAttribute('aria-pressed',
                String(this.currentFilters.categoria === 'all' && this.currentFilters.tipo === 'all'));
        }

        this.applyFilters();
    },

    applyFilters: function() {
        let filtered = this.allIncidents;
        const filters = this.currentFilters;

        if (filters.categoria !== 'all') {
            filtered = filtered.filter(i => i.categoria === filters.categoria);
        }
        if (filters.tipo && filters.tipo !== 'all') {
            filtered = filtered.filter(i => i.tipo === filters.tipo);
        }
        if (filters.barri !== 'all') {
            filtered = filtered.filter(i => i.barri === filters.barri);
        }
        if (!filters.showResolved) {
            filtered = filtered.filter(i => i.estado !== 'resuelto');
        }

        this.renderMarkers(filtered);
    },

    toggleShowResolved: function() {
        this.currentFilters.showResolved = !this.currentFilters.showResolved;
        const isOn = this.currentFilters.showResolved;
        const btn = document.getElementById('btn-toggle-resolved');
        if (btn) {
            btn.setAttribute('aria-pressed', String(isOn));
            btn.classList.toggle('active', isOn);
            const label = isOn
                ? (this.i18n[this.lang].hide_resolved || 'Ocultar resoltes')
                : (this.i18n[this.lang].show_resolved  || 'Veure resoltes');
            const span = btn.querySelector('span');
            if (span) span.textContent = label;
        }
        this.applyFilters();
    },
    
    // --- LÓGICA DE GEOLOCALIZACIÓN Y FORMULARIOS ---
    populateFormBarrios: function() {
        const select = document.getElementById('barri_select');
        this.BARRIOS_MAP = {};
        if (select) select.innerHTML = '<option value="" data-i18n="ph_barri_select">-- Selecciona Barri --</option>';

        for (const districteLabel in BADALONA_BARRIOS_ESTATICOS) {
            const parts = districteLabel.split(' '); 
            const districteNum = parts[1]; 
            
            BADALONA_BARRIOS_ESTATICOS[districteLabel].forEach(barri => {
                this.BARRIOS_MAP[barri] = districteNum; 

                if (select) {
                    let optgroup = select.querySelector(`optgroup[label="${districteLabel}"]`);
                    if (!optgroup) {
                         optgroup = document.createElement('optgroup');
                         optgroup.label = districteLabel;
                         select.appendChild(optgroup);
                    }
                    const option = document.createElement('option');
                    option.value = barri;
                    option.textContent = barri;
                    optgroup.appendChild(option);
                }
            });
        }
    },
    
    populateFilterBarrios: function() {
        const filterBarriSelect = document.getElementById('filter-barri');
        if (!filterBarriSelect) return;
        
        // Guardar la opción "Tots els Barris"
        const placeholder = filterBarriSelect.querySelector('option[value="all"]');
        filterBarriSelect.innerHTML = '';
        if(placeholder) filterBarriSelect.appendChild(placeholder);
        
        const existingBarrios = new Set();
        
        this.allIncidents.forEach(inc => {
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
            
            // Crear el optgroup para los distritos
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

        filterBarriSelect.querySelector('option[value="all"]').textContent = this.i18n[this.lang].filter_barri_all;
    },

    updateDistrictFromBarrio: function(barrioName) {
        const districteInput = document.getElementById('districte_input');
        if (districteInput) {
            districteInput.value = this.BARRIOS_MAP[barrioName] || '';
        }
    },
    
    handleCategoryChange: function(category, updateTypes = true) {
        const panel = document.getElementById('slide-panel');
        if (panel) {
            panel.classList.remove('category-infra', 'category-denuncia');
            panel.classList.add(`category-${category}`); 
            if (updateTypes) {
                this.updateTypes();
            }
        }
    },

    setLang: function(l) { 
        this.lang = l;
        localStorage.setItem('badaveu_lang', l);

        document.querySelectorAll('.lang-toggles span').forEach(s => s.classList.remove('active-lang'));
        const activeBtn = document.querySelector(`.lang-toggles span[onclick*="'${l}'"]`);
        if(activeBtn) activeBtn.classList.add('active-lang');
        
        document.querySelectorAll('[data-i18n]').forEach(el => {
            const key = el.getAttribute('data-i18n');
            const translation = this.i18n[l][key];

            if(translation) {
                if(el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') el.placeholder = translation;
                else if (el.tagName === 'TITLE') el.textContent = translation;
                else if (el.tagName === 'SPAN' && el.parentElement.classList.contains('back-link')) el.textContent = translation;
                else if (el.tagName === 'SPAN' && el.parentElement.tagName === 'A' && el.parentElement.classList.contains('nav-item')) el.textContent = translation;
                else if (el.tagName === 'OPTION' && el.value === "") el.textContent = translation; 
                else if (el.tagName === 'SPAN' && el.parentElement.classList.contains('file-upload-btn')) el.textContent = translation;
                // Maneja el bloque de créditos HTML
                else if (el.classList.contains('credits-section') && key === 'about_credits_html') {
                    el.innerHTML = translation;
                }
                else {
                    el.innerHTML = translation;
                }
            }
        });

        if(this.map && this.allIncidents.length > 0) {
            this.renderMarkers(this.allIncidents);
        }
        
        if (document.getElementById('stats-content') && this.statsData) {
             this.renderStats(this.statsData);
        }
        
        if (document.getElementById('admin-dashboard') && this.activeAdminTab === 'incidents') {
             this.renderAdminList(); 
        }
        
        if (document.getElementById('admin-dashboard') && this.activeAdminTab === 'users') {
             this.renderUserList(); 
        }

        this.updateTypes();
    },

    updateTypes: function() {
        // Asume cat-infra checked on load if on index.html, otherwise check on admin panel
        let cat = 'infraestructura';
        const catRadio = document.querySelector('input[name="categoria"]:checked');
        if(catRadio) cat = catRadio.value; 

        const select = document.getElementById('tipoSelect');
        if(!select) return;

        select.innerHTML = '';
        const list = cat === 'infraestructura' ? this.i18n[this.lang].infra_types : this.i18n[this.lang].denun_types;
        list.forEach(t => {
            const opt = document.createElement('option'); opt.innerText = t; opt.value = t; select.appendChild(opt);
        });
    },

    fetchAddress: async function(lat, lng) {
        const addrInput = document.getElementById('addr_input');
        const cpInput = document.getElementById('cp_input');
        const barriSelect = document.getElementById('barri_select');
        const locStatusMsg = document.getElementById('loc-searching-msg'); 
        
        if (addrInput) addrInput.value = '';
        if (cpInput) cpInput.value = '';
        if (barriSelect) barriSelect.value = '';

        // Posar camps readonly en estat "carregant"
        this._setGeoFields({ loading: true });

        if(locStatusMsg) locStatusMsg.textContent = this.i18n[this.lang].loc_searching;

        try {
            const response = await fetch(`api/index.php?action=reverse_geocode&lat=${lat}&lng=${lng}`);

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.message || `Error en el proxy de geocodificación. Código: ${response.status}`);
            }

            const data = await response.json();

            if (data.status && data.status === 'error') {
                 throw new Error(data.message);
            }

            const address = data.address;

            let fullAddress = data.display_name || this.i18n[this.lang].loc_unknown;
            let streetName = address.road || address.pedestrian || '';
            let houseNumber = address.house_number || '';
            let postalCode = address.postcode || '';
            let neighborhood = address.neighbourhood || address.suburb || address.village || address.city_district || '';

            if (addrInput) addrInput.value = `${streetName}${houseNumber ? ', ' + houseNumber : ''}`;
            if (cpInput) cpInput.value = postalCode;

            // Actualitzar camps readonly de geocodificació
            this._setGeoFields({
                street: streetName + (houseNumber ? ', ' + houseNumber : '') || fullAddress,
                neighbourhood: neighborhood,
                cp: postalCode
            });

            if (neighborhood && barriSelect) {
                let found = false;
                Array.from(barriSelect.options).forEach(opt => {
                    if (opt.value && opt.value.toLowerCase().includes(neighborhood.toLowerCase())) {
                        barriSelect.value = opt.value;
                        app.updateDistrictFromBarrio(opt.value);
                        found = true;
                    }
                });

                if (!found) {
                    if (addrInput && !streetName) {
                        addrInput.value = fullAddress;
                    }
                }
            }

            if (locStatusMsg) locStatusMsg.textContent = this.i18n[this.lang].loc_manual;
        } catch (error) {
            if (locStatusMsg) locStatusMsg.textContent = this.i18n[this.lang].loc_unknown + " (" + error.message + ")";
            this._setGeoFields({ street: '—', neighbourhood: '—', cp: '—' });
        }
    },

    // Actualitza els camps readonly de geocodificació al wizard step 2
    _setGeoFields: function({ loading = false, street = '', neighbourhood = '', cp = '' }) {
        const setField = (id, value, isLoading) => {
            const el = document.getElementById(id);
            if (!el) return;
            const span = el.querySelector('span');
            if (!span) return;
            if (isLoading) {
                el.classList.add('loading');
                span.textContent = this.i18n[this.lang].loc_searching;
            } else {
                el.classList.remove('loading');
                span.textContent = value || '—';
            }
        };
        setField('geo-street',        street,        loading);
        setField('geo-neighbourhood',  neighbourhood, loading);
        setField('geo-cp',             cp,            loading);
    },
    
    _dmsToDecimal: function(dms, ref) {
        const [d, m, s] = dms;
        let dd = d + m / 60 + s / 3600;
        if (ref === 'S' || ref === 'W') dd = -dd;
        return dd;
    },

    compressImage: function(file, callback, errorCallback) {
        const MAX_SIDE = 800;
        const QUALITY  = 0.68;

        const reader = new FileReader();
        reader.onerror = () => { if (errorCallback) errorCallback(new Error('No s\'ha pogut llegir el fitxer.')); };
        reader.onload = function(event) {
            const img = new Image();
            img.onerror = () => { if (errorCallback) errorCallback(new Error('La imatge no és vàlida.')); };
            img.onload = function() {
                let width  = img.width;
                let height = img.height;
                if (width > height) {
                    if (width > MAX_SIDE) { height = Math.round(height * MAX_SIDE / width); width = MAX_SIDE; }
                } else {
                    if (height > MAX_SIDE) { width = Math.round(width * MAX_SIDE / height); height = MAX_SIDE; }
                }
                const canvas = document.createElement('canvas');
                canvas.width  = width;
                canvas.height = height;
                canvas.getContext('2d').drawImage(img, 0, 0, width, height);
                const webp   = canvas.toDataURL('image/webp', QUALITY);
                const dataURL = webp.startsWith('data:image/webp') ? webp : canvas.toDataURL('image/jpeg', QUALITY);
                callback(dataURL);
            };
            img.src = event.target.result;
        };
        reader.readAsDataURL(file);
    },

    handleSubmit: function(e) {
        e.preventDefault();
        // Suport tant pel wizard com per formulari clàssic
        const btn = document.querySelector('.btn-submit-wizard') || document.querySelector('.btn-submit-main');
        const fileInput = document.getElementById('foto-input');

        // Validació categoria wizard
        const catError = document.getElementById('wizard-cat-error');
        const catHidden = document.getElementById('cat-hidden');
        if (catHidden && !catHidden.value) {
            if (catError) catError.style.display = 'block';
            return;
        }

        if(!document.getElementById('lat_input').value) {
            alert(app.i18n[app.lang].alert_loc);
            return;
        }

        const originalText = btn ? btn.innerHTML : '';
        if (btn) { btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Enviant...'; btn.disabled = true; }
        
        const submitForm = async (formData) => {
            try {
                const token = await app.getCsrfToken();
                formData.set('_csrf_token', token);

                const controller = new AbortController();
                const timeoutId  = setTimeout(() => controller.abort(), 30000);

                const res = await fetch('api/index.php?action=new_incident', {
                    method:      'POST',
                    body:        formData,
                    signal:      controller.signal,
                    credentials: 'same-origin',
                });
                clearTimeout(timeoutId);

                // Parse response — always read as text first so we can show the real message
                const text = await res.text();
                let json;
                try { json = JSON.parse(text); }
                catch { throw new Error(`Error ${res.status}: resposta del servidor no vàlida.`); }

                if (!res.ok || json.status !== 'success') {
                    throw new Error(json.message || `Error ${res.status}`);
                }

                ui.showToast(app.i18n[app.lang].alert_ok, 'success');
                ui.closePanel();
                setTimeout(() => app.loadIncidents(), 800);

            } catch (err) {
                // AbortError means our 30s timeout fired
                const msg = err.name === 'AbortError'
                    ? 'El servidor no respon. Comprova la connexió i torna-ho a intentar.'
                    : (err.message || app.i18n[app.lang].alert_err);
                ui.showToast('Error: ' + msg, 'error');
                if (btn) { btn.innerHTML = originalText; btn.disabled = false; }
            }
        };

        const formData = new FormData(e.target);

        if (fileInput && fileInput.files && fileInput.files[0]) {
            app.compressImage(
                fileInput.files[0],
                (compressedBase64) => {
                    formData.delete('foto');
                    formData.append('compressed_image', compressedBase64);
                    submitForm(formData);
                },
                (imgErr) => {
                    // Image read/compression failed — submit without photo
                    ui.showToast('⚠️ ' + imgErr.message + ' S\'envia sense foto.', 'warning');
                    submitForm(formData);
                }
            );
        } else {
            submitForm(formData);
        }
    },


    // ===========================================
    // BADAVEU — WIZARD DE 3 PASSOS
    // ===========================================

    // ===========================================
    // BADAVEU — CAPAS OSM (Overpass API)
    // ===========================================

    overpassLayers: {},
    wizardMap: null,

    goWizardStep: function(n) {
        document.querySelectorAll('.wizard-step').forEach(el => {
            el.classList.add('hidden');
            el.setAttribute('inert', '');
        });
        const target = document.getElementById(`wizard-step-${n}`);
        if (target) {
            target.classList.remove('hidden');
            target.removeAttribute('inert');
            // Move focus to first focusable element inside the step
            setTimeout(() => {
                const first = target.querySelector(
                    'button:not([disabled]), [href], input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
                );
                if (first) first.focus();
            }, 50);
        }
        this.updateFormProgress(n);

        // Update aria-current on progress steps
        document.querySelectorAll('.progress-step').forEach(el => {
            el.removeAttribute('aria-current');
        });
        document.getElementById(`step-${n}`)?.setAttribute('aria-current', 'step');

        // Al pas 2 mostrar l'adreça confirmada (ja no hi ha mini-mapa)
        if (n === 2) {
            this._updateWizardAddressDisplay();
        }
    },

    _initWizardMap: function() {
        const container = document.getElementById('wizard-mini-map');
        if (!container || this.wizardMap) return;

        const lat = parseFloat(document.getElementById('lat_input').value) || 41.450;
        const lng = parseFloat(document.getElementById('lng_input').value) || 2.247;

        this.wizardMap = L.map('wizard-mini-map', { zoomControl: true }).setView([lat, lng], 16);
        L.tileLayer(CARTO_TILE_URL, {
            attribution: '© CARTO', maxZoom: 20
        }).addTo(this.wizardMap);

        const marker = L.marker([lat, lng], { draggable: true }).addTo(this.wizardMap);

        marker.on('dragend', async (e) => {
            const pos = e.target.getLatLng();
            document.getElementById('lat_input').value = pos.lat.toFixed(7);
            document.getElementById('lng_input').value = pos.lng.toFixed(7);
            const addrDisplay = document.getElementById('wizard-address-display');
            if (addrDisplay) addrDisplay.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Cercant adreça...';
            await this.fetchAddress(pos.lat, pos.lng);
            this._updateWizardAddressDisplay();
        });

        // Auto-geolocalitzar si no hi ha coordenades ja
        if (!document.getElementById('lat_input').value && navigator.geolocation) {
            navigator.geolocation.getCurrentPosition((pos) => {
                const { latitude, longitude } = pos.coords;
                this.wizardMap.setView([latitude, longitude], 17);
                marker.setLatLng([latitude, longitude]);
                document.getElementById('lat_input').value = latitude.toFixed(7);
                document.getElementById('lng_input').value = longitude.toFixed(7);
                this.fetchAddress(latitude, longitude)
                    .then(() => this._updateWizardAddressDisplay())
                    .catch(() => {});
            }, () => {});
        } else if (document.getElementById('lat_input').value) {
            this._updateWizardAddressDisplay();
        }

        setTimeout(() => { if (this.wizardMap) this.wizardMap.invalidateSize(); }, 300);
    },

    _updateWizardAddressDisplay: function() {
        const addrEl = document.getElementById('wizard-address-display');
        if (!addrEl) return;
        const addr = document.getElementById('addr_input')?.value;
        const barri = document.getElementById('barri_select')?.value;
        const text = [addr, barri].filter(Boolean).join(', ') || this.i18n[this.lang].loc_unknown;
        addrEl.textContent = text;
    },

    selectWizardCategory: function(btn) {
        document.querySelectorAll('.cat-grid-btn').forEach(b => {
            b.classList.remove('selected');
            b.setAttribute('aria-pressed', 'false');
        });
        btn.classList.add('selected');
        btn.setAttribute('aria-pressed', 'true');
        const tipo = btn.getAttribute('data-tipo');
        const cat  = btn.getAttribute('data-cat');
        document.getElementById('cat-hidden').value = cat;
        document.getElementById('tipo-hidden').value = tipo;
        document.getElementById('titulo-hidden').value = tipo;
        const errEl = document.getElementById('wizard-cat-error');
        if (errEl) errEl.style.display = 'none';
        // Actualitzar tema del panel
        this.handleCategoryChange(cat);
    },

    // ===========================================
    // BADAVEU — BOTTOM SHEET
    // ===========================================

    switchSheetTab: function(tab) {
        document.querySelectorAll('.sheet-tab-btn').forEach(b => {
            const isActive = b.getAttribute('data-tab') === tab;
            b.classList.toggle('active', isActive);
            b.setAttribute('aria-selected', String(isActive));
        });
        document.querySelectorAll('.sheet-tab-content').forEach(c => {
            c.classList.toggle('active', c.id === `sheet-tab-${tab}`);
        });
    },

    renderSheetIncidents: function(incidents, append = false) {
        const container = document.getElementById('incidents-list-container');
        if (!container) return;

        const active = incidents.filter(i => i.estado !== 'resuelto');

        if (!append && !active.length) {
            container.innerHTML = '<div class="sheet-placeholder"><i class="ri-map-pin-line"></i> Cap incidència activa.</div>';
            return;
        }

        const html = active.map(inc => {
            const catClass = inc.categoria === 'denuncia' ? 'badge-denuncia' : '';
            const tipo  = escapeHtml(inc.tipo || inc.categoria);
            const barri = escapeHtml(inc.barri || '');
            const date  = this.formatDate(inc.created_at);
            const fotoHtml = inc.foto_url
                ? `<img class="sheet-card-foto" src="${escapeHtml(inc.foto_url)}" alt="" loading="lazy">`
                : `<div class="sheet-card-foto-placeholder">${inc.categoria === 'denuncia' ? '⚠️' : '🔧'}</div>`;
            const isVoted = localStorage.getItem(`voted_${inc.id}`);
            const voteIcon = isVoted ? 'ri-check-line' : 'ri-thumb-up-line';
            const voteClass = isVoted ? 'btn-vote-list voted' : 'btn-vote-list';
            return `<div class="sheet-incident-card" onclick="window.location.href='incident.html?id=${inc.id}'">
                ${fotoHtml}
                <div class="sheet-card-body">
                    <div class="sheet-card-title">${escapeHtml(inc.titulo)}</div>
                    <div class="sheet-card-meta">
                        <span class="sheet-card-badge ${catClass}">${tipo}</span>
                        ${barri ? `<span><i class="ri-map-pin-line"></i> ${barri}</span>` : ''}
                        <span>${date}</span>
                    </div>
                </div>
                <div class="sheet-card-actions" onclick="event.stopPropagation()">
                    <button class="${voteClass}"
                            onclick="app.toggleVote(${inc.id}, this, '#002D5A')"
                            aria-label="Donar suport">
                        <i class="${voteIcon}"></i>
                        <span id="votes-${inc.id}">${inc.votos || 0}</span>
                    </button>
                </div>
            </div>`;
        }).join('');

        if (append) {
            // Remove empty-state placeholder if present, then append
            const placeholder = container.querySelector('.sheet-placeholder');
            if (placeholder) placeholder.remove();
            container.insertAdjacentHTML('beforeend', html);
        } else {
            container.innerHTML = html;
        }
    },

    renderSheetLogros: function(resolved) {
        const container = document.getElementById('logros-list-container');
        if (!container) return;
        const recent = resolved.slice(0, 20);
        if (!recent.length) {
            container.innerHTML = '<div class="sheet-placeholder"><i class="ri-trophy-line"></i> Cap actuació recent.</div>';
            return;
        }
        container.innerHTML = recent.map(inc => {
            const fotoHtml = inc.foto_url
                ? `<img src="${escapeHtml(inc.foto_url)}" style="width:100%;height:100px;object-fit:cover;border-radius:8px;margin-top:8px;" alt="" loading="lazy">`
                : '';
            return `<div class="logro-card" onclick="window.location.href='incident.html?id=${inc.id}'" style="cursor:pointer;">
                <div class="logro-header">
                    <span class="logro-badge">✅ Resolt</span>
                    <span class="logro-date">${this.formatDate(inc.created_at)}</span>
                </div>
                <div class="logro-title">${escapeHtml(inc.titulo)}</div>
                ${inc.barri ? `<div class="logro-comment"><i class="ri-map-pin-line"></i> ${escapeHtml(inc.barri)}</div>` : ''}
                ${fotoHtml}
            </div>`;
        }).join('');
    },

    // ===========================================
    // LÓGICA DE ESTADÍSTICAS PÚBLICAS
    // ===========================================

    loadStats: async function() {
        // La destrucción se realiza en cada función de renderizado de gráfico, 
        // pero mantenemos la lógica de limpieza de referencias aquí por seguridad.
        Object.keys(this.chartInstances).forEach(key => {
            if (this.chartInstances[key] && typeof this.chartInstances[key].destroy === 'function') {
                this.chartInstances[key].destroy();
            }
        });
        this.chartInstances = {};

        const statsLoading = document.getElementById('stats-loading');
        const statsContent = document.getElementById('stats-content');
        const noStatsMessage = document.getElementById('no-stats-message');

        try {
            const res = await fetch('api/index.php?action=public_stats');
            if (!res.ok) throw new Error('API request failed');
            const json = await res.json();

            if (statsLoading) statsLoading.classList.add('hidden');

            if (json.status === 'success' && json.data.total_incidents > 0) {
                this.statsData = json.data;
                if (statsContent) { statsContent.classList.remove('hidden'); statsContent.style.display = ''; }
                if (noStatsMessage) noStatsMessage.classList.add('hidden');
                this.renderStats(this.statsData);
            } else {
                this.statsData = null;
                if (statsContent) { statsContent.classList.add('hidden'); statsContent.style.display = 'none'; }
                if (noStatsMessage) { noStatsMessage.classList.remove('hidden'); noStatsMessage.style.display = ''; }

                let msg = this.i18n[this.lang].stats_empty;
                if (json.status === 'error') {
                     msg += '<br>ERROR DE LA BASE DE DATOS: ' + (json.message || 'Error desconocido.');
                }
                if (noStatsMessage) noStatsMessage.innerHTML = msg;
            }
        } catch(e) {
            if (statsLoading) statsLoading.classList.add('hidden');
            if (statsContent) { statsContent.classList.add('hidden'); statsContent.style.display = 'none'; }
            if (noStatsMessage) {
                noStatsMessage.classList.remove('hidden');
                noStatsMessage.style.display = '';
                noStatsMessage.innerHTML = this.i18n[this.lang].stats_empty + '<br>Error de connexió: ' + escapeHtml(e.message);
            }
        }
    },

    renderStats: function(data) {
        // La destrucción a nivel de instancia se mueve a las funciones de dibujo.
        
        document.getElementById('stat-total').textContent = data.total_incidents;
        document.getElementById('stat-pending').textContent = data.by_status.pendiente || 0;
        document.getElementById('stat-process').textContent = data.by_status.proceso || 0;
        document.getElementById('stat-solved').textContent = data.by_status.resuelto || 0;

        if (data.most_viewed) {
            const mv = data.most_viewed;
            const sec = document.getElementById('most-viewed-section');
            const card = document.getElementById('most-viewed-card');
            if (sec && card) {
                sec.style.display = '';
                card.innerHTML = `<strong>${escapeHtml(mv.titulo)}</strong><br>
                    <small>${escapeHtml(mv.barri || '')} &mdash; ${mv.views || 0} visualitzacions</small>`;
                card.onclick = () => window.location.href = `incident.html?id=${mv.id}`;
            }
        }

        // Timeout para asegurar que el canvas es visible y tiene dimensiones
        setTimeout(() => {
            this.renderCategoryChart(data.by_category);
            this.renderStatusChart(data.by_status);
            this.renderBarriChart(data.by_barri);
        }, 100);
    },

    renderCategoryChart: function(data) { 
        const ctx = document.getElementById('categoryChart')?.getContext('2d');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

        const labels = [this.i18n[this.lang].cat_infra, this.i18n[this.lang].cat_denuncia];
        const chartData = [data.infraestructura || 0, data.denuncia || 0];

        this.chartInstances.categoryChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: this.i18n[this.lang].stats_incidents_total,
                    data: chartData,
                    backgroundColor: ['rgba(0,45,90,0.85)', 'rgba(239,68,68,0.85)'],
                    borderColor: ['rgba(0,45,90,1)', 'rgba(239,68,68,1)'],
                    borderWidth: 1,
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: { beginAtZero: true, ticks: { callback: function(value) { if (value % 1 === 0) { return value; } } } }
                },
                plugins: { legend: { display: false } }
            }
        });
    },

    renderStatusChart: function(data) { 
        const ctx = document.getElementById('statusChart')?.getContext('2d');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

        const labels = [this.i18n[this.lang].status_pendiente, this.i18n[this.lang].status_proceso, this.i18n[this.lang].status_resuelto];
        const chartData = [data.pendiente || 0, data.proceso || 0, data.resuelto || 0];

        this.chartInstances.statusChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    label: this.i18n[this.lang].stats_incidents_total,
                    data: chartData,
                    backgroundColor: ['rgba(245,158,11,0.85)', 'rgba(0,45,90,0.85)', 'rgba(16,185,129,0.85)'],
                    hoverOffset: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { position: 'bottom' } }
            }
        });
    },

    renderBarriChart: function(data) { 
        const ctx = document.getElementById('barriChart')?.getContext('2d');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

        const labels = Object.keys(data);
        const chartData = Object.values(data);

        this.chartInstances.barriChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: labels,
                datasets: [{
                    label: this.i18n[this.lang].stats_incidents_total,
                    data: chartData,
                    backgroundColor: 'rgba(0,45,90,0.85)',
                    borderColor: 'rgba(0,45,90,1)',
                    borderWidth: 1,
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                indexAxis: 'y', 
                scales: {
                    x: { beginAtZero: true, ticks: { callback: function(value) { if (value % 1 === 0) { return value; } } } }
                },
                plugins: { legend: { display: false } }
            }
        });
    },
    
    // ===========================================
    // LÓGICA DE ADMINISTRACIÓN Y AUTH
    // ===========================================
    
    setActiveAdminTab: function(tabName) {
        // Tabs
        document.querySelectorAll('.admin-tab-btn').forEach(btn => btn.classList.remove('active'));
        document.querySelector(`.admin-tab-btn[data-tab="${tabName}"]`)?.classList.add('active');
        
        document.querySelectorAll('.admin-tab-content').forEach(content => content.classList.add('hidden'));
        document.getElementById(`tab-${tabName}-content`)?.classList.remove('hidden');

        this.activeAdminTab = tabName;
        
        if (tabName === 'incidents') {
            this.loadAdminData();
        } else if (tabName === 'stats') {
            this.loadAdminStats();
        } else if (tabName === 'users') {
             this.loadUserManagement(); 
        }
    },

    checkAdminAuth: async function() {
        const loadingScreen = document.getElementById('loading-screen');
        const adminLogin = document.getElementById('admin-login');
        const adminDashboard = document.getElementById('admin-dashboard');
        const tabUsersBtn = document.getElementById('tab-users-btn');
        const loginMessage = document.getElementById('loginMessage');
        const adminUserDisplay = document.getElementById('admin-user-display');

        if (loadingScreen) loadingScreen.style.display = 'flex';

        try {
            const res = await fetch('api/index.php?action=check_auth', { credentials: 'same-origin' });
            const json = await res.json();

            // Capture the CSRF token returned by check_auth (it is always included)
            // and store it in memory — this ensures the token always matches the
            // current live PHP session without an additional get_csrf round-trip.
            if (json.csrf_token) {
                app.csrfToken = json.csrf_token;
            }

            if (json.logged_in) {
                app.adminRole = json.admin_role; 
                
                const isSuperadmin = app.adminRole === 'superadmin';
                if (tabUsersBtn) tabUsersBtn.style.display = isSuperadmin ? '' : 'none';
                
                const username = localStorage.getItem('admin_username') || 'Admin';
                if (adminUserDisplay) adminUserDisplay.textContent = username;
                
                if (adminDashboard) adminDashboard.classList.remove('hidden');
                if (adminLogin) adminLogin.classList.add('hidden');
                
                app.setActiveAdminTab('stats'); 
            } else {
                if (adminDashboard) adminDashboard.classList.add('hidden');
                if (adminLogin) adminLogin.classList.remove('hidden');
                if (loginMessage) loginMessage.textContent = ""; 
            }
        } catch(e) {
            if (loginMessage) loginMessage.textContent = "Error de conexión con la API o error de script.";
            if (adminLogin) adminLogin.classList.remove('hidden');
        } finally {
            if (loadingScreen) loadingScreen.style.display = 'none';
        }
    },

    handleAdminLogin: async function(e) {
        e.preventDefault();
        const form = e.target;
        const btn = form.querySelector('button');
        const originalText = btn.innerHTML;
        const username = form.querySelector('input[name="usuario"]').value;
        const loginMessage = document.getElementById('loginMessage');

        btn.disabled = true;
        btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Entrant...';
        if (loginMessage) loginMessage.textContent = '';

        const doLogin = async (isRetry = false) => {
            // On retry, force-fetch a fresh CSRF token — the previous one was rejected.
            const csrfToken = isRetry ? await app.refreshCsrfToken() : await app.getCsrfToken();

            const formData = new FormData(form);
            formData.set('_csrf_token', csrfToken);

            const res = await fetch('api/index.php?action=login', {
                method: 'POST',
                body: formData,
                credentials: 'same-origin',
            });

            // If the server returns 403 (stale token) and this is the first try,
            // clear the in-memory token and retry once with a fresh one.
            if (res.status === 403 && !isRetry) {
                app.csrfToken = null;
                return doLogin(true);
            }

            const text = await res.text();
            let json;
            try { json = JSON.parse(text); }
            catch { throw new Error(`Error ${res.status}: resposta no vàlida del servidor.`); }

            if (!res.ok) {
                throw new Error(json.message || `Error ${res.status}`);
            }

            return json;
        };

        try {
            const json = await doLogin();

            if (json.status === 'success') {
                localStorage.setItem('admin_username', username);
                app.checkAdminAuth();
            } else {
                if (loginMessage) loginMessage.textContent = json.message || 'Error de autenticació.';
            }
        } catch (err) {
            if (loginMessage) loginMessage.textContent = err.message || 'Error de connexió al servidor.';
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    },

    handleAdminLogout: async function() {
        try { await fetch('api/index.php?action=logout'); } catch (_) { /* always proceed */ }
        localStorage.removeItem('admin_username');
        location.reload();
    },
    
    // --- GESTIÓN DE INCIDENCIAS (FUNCIONALIDAD MEJORADA) ---
    
    loadAdminData: async function() {
        const listContainer = document.getElementById('incident-list');
        // Obtener valores de los filtros dinámicamente
        this.adminFilters.status = document.getElementById('filter-status')?.value || 'all';
        this.adminFilters.category = document.getElementById('filter-category')?.value || 'all';
        this.adminFilters.barri = document.getElementById('filter-barri-admin')?.value || 'all'; 
        this.adminFilters.urgency = document.getElementById('filter-urgency')?.value || 'all';
        this.adminFilters.search = document.getElementById('filter-search')?.value.toLowerCase() || '';
        
        if (listContainer) {
            listContainer.innerHTML = `<p id="list-message" class="text-center" style="padding: 20px; color: var(--text-light);">${app.i18n[app.lang].admin_list_loading}</p>`;
        }

        try {
            const res = await fetch(`api/index.php?action=admin_data`);
            const json = await res.json();

            if (json.status === 'success') {
                app.adminIncidents = json.data;
                app.populateAdminFilterBarrios(); 
                app.renderAdminList(); 
            } else {
                if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color: var(--danger);">Error carregant dades: ${json.message}</p>`;
            }
        } catch(e) {
            if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color: var(--danger);">Error de connexió al servidor: ${e.message}</p>`;
        }
    },
    
    populateAdminFilterBarrios: function() {
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
    },

    renderAdminList: function() {
        const listContainer = document.getElementById('incident-list');
        if (!listContainer) return;

        listContainer.innerHTML = '';
        const filters = this.adminFilters;
        
        let filteredData = app.adminIncidents.filter(inc => {
            const matchesStatus = filters.status === 'all' || inc.estado === filters.status;
            const matchesCategory = filters.category === 'all' || inc.categoria === filters.category;
            const matchesBarri   = filters.barri   === 'all' || inc.barri    === filters.barri;
            const matchesUrgency = filters.urgency === 'all' || inc.urgencia === filters.urgency;

            const matchesSearch = filters.search === '' ||
                                  (inc.titulo ?? '').toLowerCase().includes(filters.search) ||
                                  (inc.descripcion ?? '').toLowerCase().includes(filters.search);

            return matchesStatus && matchesCategory && matchesBarri && matchesUrgency && matchesSearch;
        });
        
        if (filteredData.length === 0) {
            listContainer.innerHTML = `<p class="text-center" style="padding: 20px; color: var(--text-light);">${app.i18n[app.lang].admin_list_empty}</p>`;
            return;
        }
        
        // Vista de Escritorio: Tabla (MEJORADA)
        const tableHTML = `
            <div class="table-wrapper desktop-table-view">
                <table class="incident-table">
                    <thead>
                        <tr>
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
                            // CORRECCIÓ: Robustesa per inc.estado
                            const statusLabel = app.i18n[app.lang][`status_${inc.estado}`] || 'Estat Desconegut';
                            const categoryLabel = inc.categoria === 'infraestructura' ? app.i18n[app.lang].cat_infra : app.i18n[app.lang].cat_denuncia;
                            const formattedDate = app.formatDate(inc.created_at);
                            const shortDesc = (inc.descripcion ?? '').substring(0, 50) + '...';
                            const urgencyLabel = app.i18n[app.lang][`urg_${inc.urgencia}`] || inc.urgencia || 'Baixa';

                            return `
                                <tr class="status-${inc.estado}" onclick="app.openDetailPanel(${inc.id})">
                                    <td>#${inc.id}<br><small>${formattedDate.split(',')[0]}</small></td>
                                    <td><strong>${inc.titulo}</strong><br><small>${shortDesc}</small></td>
                                    <td>${inc.direccion || 'Desconeguda'}<br><small>${inc.barri} (D${inc.districte || '?'})</small></td>
                                    <td>${categoryLabel}<br><small>${inc.tipo}</small></td>
                                    <td><span class="urgency-pill urgency-${inc.urgencia}">${urgencyLabel.toUpperCase()}</span></td>
                                    <td>${inc.votos}</td>
                                    <td class="status-cell">
                                        <span class="card-status status-${inc.estado}">${statusLabel.toUpperCase()}</span>
                                    </td>
                                    <td><button class="btn-sm btn-primary">Detalls</button></td>
                                </tr>
                            `;
                        }).join('')}
                    </tbody>
                </table>
            </div>
        `;
        
        // Vista Móvil: Tarjetas (MEJORADA)
        const cardHTML = filteredData.map(inc => {
            const statusLabel = app.i18n[app.lang][`status_${inc.estado}`] || 'Estat Desconegut';
            const categoryLabel = inc.categoria === 'infraestructura' ? app.i18n[app.lang].cat_infra : app.i18n[app.lang].cat_denuncia;
            const formattedDate = app.formatDate(inc.created_at);
            const urgencyLabel = app.i18n[app.lang][`urg_${inc.urgencia}`] || inc.urgencia || 'Baixa';

            return `
                <div class="incident-card-admin status-${inc.estado} mobile-card-view" onclick="app.openDetailPanel(${inc.id})">
                    <div class="card-header-admin" style="display:flex; justify-content:space-between; align-items:center;">
                        <span class="card-status status-${inc.estado}">${statusLabel.toUpperCase()}</span>
                        <div style="display:flex; gap:10px; align-items:center;">
                            <span class="card-category text-muted">${categoryLabel}</span>
                            <span class="urgency-pill urgency-${inc.urgencia}">${urgencyLabel.toUpperCase()}</span>
                        </div>
                    </div>
                    <h4 class="card-title-admin" style="margin: 10px 0 5px 0; font-size:1.1rem;">${inc.titulo} <small style="color:var(--text-secondary); font-weight:400;">(#${inc.id})</small></h4>
                    <p class="card-location-admin text-muted" style="margin-bottom: 5px;"><i class="ri-map-pin-line"></i> ${inc.barri || 'Sense Barri'}</p>
                    <p class="card-meta-admin text-muted" style="font-size:0.8rem;"><i class="ri-calendar-line"></i> ${formattedDate}</p>
                    <div class="card-votes-admin" style="position: absolute; top: 15px; right: 15px; font-weight:700; color:var(--text-secondary);">
                        <i class="ri-thumb-up-fill"></i> ${inc.votos}
                    </div>
                </div>
            `;
        }).join('');
        
        listContainer.innerHTML = tableHTML + cardHTML;
    },

    // FUNCIÓN MEJORADA: Incluye el mapa de detalle y la nueva estructura
    openDetailPanel: function(id) {
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
        
        const urgencyLabel = app.i18n[app.lang][`urg_${incident.urgencia}`] || incident.urgencia;
        
        // --- LÓGICA DE TRUNCAMIENTO DE DESCRIPCIÓN ---
        const MAX_DESC_LENGTH = 200;
        const description = incident.descripcion || '';
        const needsTruncation = description.length > MAX_DESC_LENGTH;
        const shortDescription = description.substring(0, MAX_DESC_LENGTH) + '...';
        
        const toggleButtonHtml = needsTruncation ? `
            <button id="desc-toggle-btn-${incident.id}" 
                    onclick="app.toggleDescription(${incident.id})" 
                    style="background: none; border: none; color: var(--primary); font-weight: 600; cursor: pointer; padding: 5px 0; margin-top: 10px; display: flex; align-items: center; gap: 5px; font-size: 0.95rem;">
                <i class="ri-arrow-down-s-line"></i> ${app.i18n[app.lang].detail_read_more}
            </button>
        ` : '';

        const descriptionHtml = `
            <div style="margin-top: 15px;">
                <div class="detail-description-text">
                    <strong>${app.i18n[app.lang].detail_description}:</strong>
                    ${needsTruncation ? 
                        // Render truncated text initially visible, and full text hidden
                        `<span id="short-desc-${incident.id}">${shortDescription}</span>
                        <span id="full-desc-${incident.id}" class="hidden">${description}</span>`
                        : 
                        // Render full text if short
                        `${description}`
                    }
                </div>
                ${toggleButtonHtml}
            </div>
        `;
        // --- FIN LÓGICA DE TRUNCAMIENTO ---

        if (content) content.innerHTML = `
            <div class="detail-header-admin status-${escapeHtml(incident.estado)}">
                <span class="detail-status-pill status-${escapeHtml(incident.estado)}">${escapeHtml(statusLabel)}</span>
                <span class="detail-id text-muted" style="float:right;">ID: ${incident.id}</span>
                <h2 class="detail-title-admin" style="font-size:1.5rem; margin-top: 10px; margin-bottom: 0;">${escapeHtml(incident.titulo)}</h2>
                <p class="detail-date"><i class="ri-calendar-line"></i> ${escapeHtml(app.formatDate(incident.created_at))}</p>
            </div>
            
            <div id="detailMap" class="detail-map-container"></div>
            
            <div class="detail-section">
                <h3><i class="ri-map-pin-line"></i> ${app.i18n[app.lang].detail_section_location}</h3>
                <p><strong>${app.i18n[app.lang].detail_address}:</strong> ${escapeHtml(incident.direccion || 'Desconeguda')}</p>
                <p><strong>${app.i18n[app.lang].detail_district}:</strong> ${escapeHtml(incident.barri)} (D${escapeHtml(incident.districte || '?')})</p>
                <p class="text-muted" style="font-size:0.85rem;"><strong>${app.i18n[app.lang].detail_coords}:</strong> ${incident.lat.toFixed(6)}, ${incident.lng.toFixed(6)}</p>
                <a href="https://www.google.com/maps/search/?api=1&query=${incident.lat},${incident.lng}" target="_blank" class="btn-sm btn-info detail-map-link">
                    <i class="ri-direction-line"></i> Ver en Google Maps
                </a>
            </div>

            <div class="detail-section">
                <h3><i class="ri-list-check"></i> ${app.i18n[app.lang].detail_section_details}</h3>
                <div class="detail-info-grid">
                    <p><strong>${app.i18n[app.lang].detail_urgency_level}:</strong> <span class="urgency-pill urgency-${escapeHtml(incident.urgencia)}">${escapeHtml(urgencyLabel.toUpperCase())}</span></p>
                    <p><strong>${app.i18n[app.lang].detail_type_problem}:</strong> ${escapeHtml(categoryLabel)} - ${escapeHtml(incident.tipo)}</p>
                    <p style="grid-column: 1 / span 2;"><strong>${app.i18n[app.lang].detail_affects}:</strong> ${escapeHtml(app.i18n[app.lang][`imp_${incident.afectacion}`] || incident.afectacion)}</p>
                </div>
                ${descriptionHtml}
            </div>

            ${incident.foto_url ? `
                <div class="detail-section detail-photo-section">
                    <h3><i class="ri-camera-line"></i> Fotografia</h3>
                    <img src="${escapeHtml(incident.foto_url)}" class="detail-image" alt="Foto de la incidència ${incident.id}">
                    <a href="${escapeHtml(incident.foto_url)}" target="_blank" class="btn-sm btn-info detail-img-link">
                        <i class="ri-zoom-in-line"></i> ${app.i18n[app.lang].detail_img_view}
                    </a>
                </div>
            ` : ''}

            <div class="detail-section">
                <h3><i class="ri-user-line"></i> ${app.i18n[app.lang].detail_section_contact}</h3>
                <p><strong>${app.i18n[app.lang].detail_email}:</strong> ${incident.email || 'No proporcionat'}</p>
                <p><strong>${app.i18n[app.lang].detail_votes}:</strong> ${incident.votos}</p>
            </div>

            <div class="detail-section detail-action-bar">
                <h3><i class="ri-exchange-box-line"></i> ${app.i18n[app.lang].detail_section_actions}</h3>
                <select id="newStatusSelect-${incident.id}" class="select-status status-${incident.estado}" 
                        onchange="this.className='select-status status-'+this.value">
                    ${statusOptions}
                </select>
                <button class="btn-update-status" 
                        onclick="app.handleStatusChange(${incident.id}, document.getElementById('newStatusSelect-${incident.id}').value, this)">
                    ${app.i18n[app.lang].detail_btn_update}
                </button>
            </div>
        `;
        
        if (panel) panel.classList.add('open'); 
        
        // Inicializar el mapa de detalle
        setTimeout(() => {
             app.initDetailMap(incident.lat, incident.lng);
        }, 100); 
    },
    
    // FUNCIÓN NUEVA: Inicializa el mapa pequeño dentro del panel
    initDetailMap: function(lat, lng) {
        const mapElement = document.getElementById('detailMap');
        if (!mapElement) return;

        // Si ya hay un mapa, destrúyelo
        if (app.detailMap) {
            app.detailMap.remove();
        }

        app.detailMap = L.map('detailMap', {
            zoomControl: false,
            dragging: false,
            scrollWheelZoom: false,
            doubleClickZoom: false,
            attributionControl: false
        }).setView([lat, lng], 16);

        L.tileLayer(CARTO_TILE_URL, {
            attribution: '© CARTO', 
            maxZoom: 18
        }).addTo(app.detailMap);
        
        const customIcon = L.divIcon({
            html: '<i class="ri-map-pin-fill" style="font-size:35px; color:#ef4444; filter:drop-shadow(0 2px 3px rgba(0,0,0,0.3)); position:relative; top:-17px;"></i>',
            className: 'custom-pin-detail', iconSize: [35, 35], iconAnchor: [17, 35]
        });

        L.marker([lat, lng], { icon: customIcon }).addTo(app.detailMap);
    },

    closeDetailPanel: function() {
        const panel = document.getElementById('detail-panel');
        if (panel) panel.classList.remove('open');
        
        // Limpiar el mapa de detalle para evitar fugas de memoria
        if (app.detailMap) {
            app.detailMap.remove();
            app.detailMap = null;
        }
    },
    
    handleStatusChange: async function(id, newStatus, btn) {
        const originalText = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> ...';

        const formData = new FormData();
        formData.append('id', id);
        formData.append('estado', newStatus);
        formData.append('_csrf_token', await app.getCsrfToken());

        try {
            const res = await fetch('api/index.php?action=update_status', { method: 'POST', body: formData });
            
            const errorText = await res.text();
            
            if (!res.ok) {
                let message = "Error desconocido al actualizar estado.";
                try {
                    const json = JSON.parse(errorText);
                    message = json.message || `Server Error: ${res.status}`;
                } catch {
                    message = `Error ${res.status}: Fallo de servidor. Revise logs PHP.`;
                }
                ui.showToast(`Error: ${message}`, 'error', 7000);
                return;
            }
            
            ui.showToast("Estat actualitzat correctament!", 'success', 3000);
            app.loadAdminData(); 
            app.closeDetailPanel(); 
        } catch(e) {
            ui.showToast("Error de connexió al servidor.", 'error', 5000);
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    },
    
    // --- GESTIÓN DE ESTADÍSTICAS AVANZADAS (Admin) ---
    
    loadAdminStats: async function() {
        const content = document.getElementById('tab-stats-content');
        
        // La destrucción se realiza en cada función de renderizado de gráfico, 
        Object.keys(this.chartInstances).forEach(key => {
            if (this.chartInstances[key] && typeof this.chartInstances[key].destroy === 'function') {
                this.chartInstances[key].destroy();
            }
        });
        this.chartInstances = {};
        
        if (content) content.innerHTML = `<p class="text-center" style="padding: 50px; color: var(--text-light);">${app.i18n[app.lang].admin_list_loading}</p>`;

        try {
            const res = await fetch('api/index.php?action=admin_stats');
            const errorText = await res.text();
            
            if (!res.ok) {
                if (content) content.innerHTML = `<p class="text-center" style="color: var(--danger); padding: 50px;">Error carregant estadístiques: Fallo de servidor. Detall: ${errorText.substring(0, 150)}...</p>`;
                return;
            }

            const json = JSON.parse(errorText);
            if (json.status === 'success') {
                app.renderAdminStats(json.data);
            } else {
                if (content) content.innerHTML = `<p class="text-center" style="color: var(--danger); padding: 50px;">Error carregant estadístiques: ${json.message}</p>`;
            }
        } catch(e) {
            if (content) content.innerHTML = `<p class="text-center" style="color: var(--danger); padding: 50px;">Error de connexió al servidor: ${e.message}</p>`;
        }
    },
    
    renderAdminStats: function(data) {
        
        const lang = this.lang;
        const i18n = this.i18n[lang];

        const totalResolved = data.urgency_distribution.resuelto || 0;
        const totalPending = (data.urgency_distribution.pendiente || 0) + (data.urgency_distribution.proceso || 0);

        const contentHTML = `
            <section class="info-section">
                <h2><i class="ri-pulse-line"></i> Indicadors Clau</h2>
                <div class="stats-grid">
                    <div class="d-card" style="border-left: 5px solid var(--primary);">
                        <p>${i18n.admin_stats_total}</p>
                        <h3>${data.total_incidents}</h3>
                    </div>
                    <div class="d-card" style="border-left: 5px solid var(--warning);">
                        <p>${i18n.admin_stats_pending}</p>
                        <h3>${totalPending}</h3>
                    </div>
                    <div class="d-card" style="border-left: 5px solid var(--success);">
                        <p>${i18n.admin_stats_resolved}</p>
                        <h3>${totalResolved}</h3>
                    </div>
                    <div class="d-card" style="border-left: 5px solid var(--danger);">
                        <p>${i18n.lbl_urgency} ${i18n.urg_high}</p>
                        <h3>${data.urgency_distribution.alta || 0}</h3>
                    </div>
                </div>
            </section>
            
            <section class="info-section">
                <h2><i class="ri-line-chart-line"></i> Anàlisi de Tendències i Flux Operatiu</h2>
                <div class="chart-duo">
                    <div class="d-card chart-section">
                        <h3>${i18n.admin_stats_weekly_flow}</h3>
                        <div class="chart-container"><canvas id="adminWeeklyFlowChart"></canvas></div>
                    </div>
                    <div class="d-card chart-section">
                        <h3>${i18n.admin_stats_monthly}</h3>
                        <div class="chart-container"><canvas id="adminMonthlyChart"></canvas></div>
                    </div>
                </div>
            </section>

            <section class="info-section">
                <h2><i class="ri-pie-chart-2-line"></i> Anàlisi de Classificació</h2>
                <div class="chart-duo">
                    <div class="d-card chart-section">
                        <h3>${i18n.admin_stats_urgency}</h3>
                        <div class="chart-container"><canvas id="adminUrgencyChart"></canvas></div>
                    </div>
                    <div class="d-card chart-section">
                        <h3>${i18n.admin_stats_afectacion}</h3>
                        <div class="chart-container"><canvas id="adminAfectacionChart"></canvas></div>
                    </div>
                </div>
            </section>
        `;
        
        const content = document.getElementById('tab-stats-content');
        if (content) content.innerHTML = contentHTML;
        
        // Timeout para asegurar que los elementos Canvas están en el DOM antes de dibujar
        setTimeout(() => {
            this.drawWeeklyFlowChart(data.weekly_status_flow, i18n);
            this.drawAdminMonthlyChart(data.monthly_trend, i18n);
            this.drawAdminUrgencyChart(data.urgency_distribution, i18n);
            this.drawAdminAfectacionChart(data.afectacion_distribution, i18n);
        }, 100);
    },
    
    // CHART: Weekly Operational Flow (Line/Bar)
    drawWeeklyFlowChart: function(data, i18n) {
        // Find the canvas element
        const ctx = document.getElementById('adminWeeklyFlowChart');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

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
    },

    // CHART: Admin Monthly Trend (Line)
    drawAdminMonthlyChart: function(data, i18n) {
        const ctx = document.getElementById('adminMonthlyChart');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

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
    },
    
    // CHART: Urgency Distribution (Doughnut)
    drawAdminUrgencyChart: function(data, i18n) {
        const ctx = document.getElementById('adminUrgencyChart');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

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
    },
    
    // CHART: Afectacion Distribution (Doughnut)
    drawAdminAfectacionChart: function(data, i18n) {
        const ctx = document.getElementById('adminAfectacionChart');
        if (!ctx) return;
        
        destroyExistingChart(ctx);

        const labels = [
            i18n.imp_individual, 
            i18n.imp_collective, 
            'Sense especificar' 
        ];
        
        const counts = [
            data.individual || 0, 
            data['col·lectiva'] || 0, // Corregido para usar la clave correcta
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
    },
    
    // --- GESTIÓN DE USUARIOS (MEJORADA) ---
    
    // 1. New Modal Functions
    openCreateAdminModal: function() {
        const form = document.getElementById('adminUserForm');
        form.reset();
        
        document.getElementById('adminUserId').value = '';
        document.getElementById('adminModalTitle').textContent = app.i18n[app.lang].admin_btn_new_user;
        document.getElementById('adminSubmitBtn').textContent = app.i18n[app.lang].admin_btn_new_user;
        
        // Password required and standard placeholder
        document.getElementById('adminPassword').required = true;
        document.getElementById('passwordLabel').textContent = `${app.i18n[app.lang].lbl_password} (${app.i18n[app.lang].ph_password_new})`;
        document.getElementById('adminPassword').placeholder = app.i18n[app.lang].ph_password_new;
        
        app.populateAdminUserForm();
        
        // Set event listener for creation
        form.onsubmit = app.handleCreateAdminSubmit;
        
        document.getElementById('adminUserModal').classList.remove('hidden');
    },

    openEditAdminModal: function(id) {
        const user = app.adminUsers.find(u => u.id == id);
        if (!user) return;
        
        const form = document.getElementById('adminUserForm');
        form.reset(); 
        
        // Populate form fields
        document.getElementById('adminUserId').value = user.id;
        document.getElementById('adminUsername').value = user.usuario;
        
        // Password optional and placeholder change
        document.getElementById('adminPassword').required = false; 
        document.getElementById('adminPassword').value = ''; // Ensure field is empty
        document.getElementById('passwordLabel').textContent = `${app.i18n[app.lang].lbl_password} (${app.i18n[app.lang].ph_password_optional})`;
        document.getElementById('adminPassword').placeholder = app.i18n[app.lang].ph_password_optional;
        
        app.populateAdminUserForm(user.role, user.access_type, user.district_access);
        
        // Set up form for editing mode
        document.getElementById('adminModalTitle').textContent = app.i18n[app.lang].btn_edit_user || "Editar Administrador";
        document.getElementById('adminSubmitBtn').textContent = app.i18n[app.lang].detail_btn_update;
        
        // Set event listener for update
        form.onsubmit = app.handleUpdateAdminSubmit;
        
        document.getElementById('adminUserModal').classList.remove('hidden');
    },

    closeAdminUserModal: function() {
        document.getElementById('adminUserModal').classList.add('hidden');
        // Limpia el mensaje de error del modal si existe
        const msg = document.getElementById('userMessage');
        if (msg) msg.textContent = "";
    },

    populateAdminUserForm: function(selectedRole = 'moderator', selectedAccess = 'all', selectedDistricts = '') {
        const roleSelect = document.getElementById('adminRole');
        const accessSelect = document.getElementById('adminAccessType');
        const districtInput = document.getElementById('adminDistrictAccess');
        const districtContainer = document.getElementById('districtAccessContainer');

        // 1. Populate Roles 
        roleSelect.innerHTML = `
            <option value="superadmin" ${selectedRole === 'superadmin' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_superadmin}</option>
            <option value="admin" ${selectedRole === 'admin' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_admin}</option>
            <option value="moderator" ${selectedRole === 'moderator' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_role_moderator}</option>
        `;
        
        // 2. Populate Access Types 
        accessSelect.innerHTML = `
            <option value="all" ${selectedAccess === 'all' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_all}</option>
            <option value="infraestructura" ${selectedAccess === 'infraestructura' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_infra}</option>
            <option value="denuncia" ${selectedAccess === 'denuncia' ? 'selected' : ''}>${app.i18n[app.lang].admin_user_access_denuncia}</option>
        `;

        // 3. Handle District Access visibility and value
        districtInput.value = selectedDistricts;
        
        const toggleDistrictAccess = () => {
            const currentRole = roleSelect.value;
            
            // Mostrar los distritos si no es solo un moderador simple (que puede ser filtrado solo por tipo)
            // Se muestra para todos ya que los distritos también se pueden usar para filtrar 'all'
            if (currentRole === 'superadmin' || currentRole === 'admin' || currentRole === 'moderator') {
                 districtContainer.classList.remove('hidden');
            } else {
                 districtContainer.classList.add('hidden');
            }
        };
        
        roleSelect.onchange = toggleDistrictAccess;
        accessSelect.onchange = toggleDistrictAccess;
        toggleDistrictAccess(); 
        
        // Set selected values if editing
        roleSelect.value = selectedRole;
        accessSelect.value = selectedAccess;
    },

    handleCreateAdminSubmit: async function(e) {
        e.preventDefault();
        const form = e.target;
        const btn = document.getElementById('adminSubmitBtn');
        const msg = document.getElementById('userMessage');
        const originalText = btn.innerHTML;
        
        msg.textContent = "";
        btn.disabled = true;
        btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Creando...';

        try {
            const formData = new FormData(form);
            formData.delete('id'); 

            // ** VALIDACIÓN LOCAL PARA EVITAR 400 **
            const usuario = formData.get('usuario');
            const password = formData.get('password');
            if (!usuario || usuario.trim() === '' || !password || password.length < 8) {
                 throw new Error("Validation Error: Usuario (email) y contraseña (mínimo 8 caracteres) son obligatorios.");
            }
            // ** FIN VALIDACIÓN **
            
            const res = await fetch('api/index.php?action=create_admin', { method: 'POST', body: formData });
            
            const jsonText = await res.text();
            let json;
            try {
                json = JSON.parse(jsonText);
            } catch (err) {
                throw new Error(`Server Error (${res.status}): ${jsonText.substring(0, 50)}...`);
            }

            if (json.status === 'success') {
                ui.showToast(json.message, 'success', 3000);
                app.closeAdminUserModal();
                app.loadUserManagement();
            } else {
                if (msg) msg.textContent = json.message || "Error desconocido al crear usuario.";
                throw new Error(json.message);
            }
        } catch(err) {
            ui.showToast("Error: " + (err.message || "Error al conectar con la API."), 'error', 5000);
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    },

    handleUpdateAdminSubmit: async function(e) {
        e.preventDefault();
        const form = e.target;
        const btn = document.getElementById('adminSubmitBtn');
        const msg = document.getElementById('userMessage');
        const originalText = btn.innerHTML;
        
        msg.textContent = "";
        btn.disabled = true;
        btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i> Actualizando...';

        try {
            const formData = new FormData(form);
            
            // If the password field is empty, remove it from formData so the backend doesn't try to update it to an empty hash
            if (formData.get('password') === '') {
                formData.delete('password');
            } else if (formData.has('password') && formData.get('password').length < 8) {
                 throw new Error("Validation Error: La nueva contraseña debe tener al menos 8 caracteres.");
            }
            
            const res = await fetch('api/index.php?action=update_admin', { method: 'POST', body: formData });
            const jsonText = await res.text();
            let json;
            try {
                json = JSON.parse(jsonText);
            } catch (err) {
                 throw new Error(`Server Error (${res.status}): ${jsonText.substring(0, 50)}...`);
            }
            
            if (json.status === 'success') {
                ui.showToast(json.message, 'success', 3000);
                app.closeAdminUserModal();
                app.loadUserManagement();
            } else {
                 if (msg) msg.textContent = json.message || "Error desconocido al actualizar usuario.";
                throw new Error(json.message);
            }
        } catch(err) {
            ui.showToast("Error: " + (err.message || "Error al conectar con la API."), 'error', 5000);
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    },


    loadUserManagement: async function() {
        const listContainer = document.getElementById('admin-users-list');
        const createUserBtn = document.getElementById('createUserBtn');
        
        if (listContainer) {
            listContainer.innerHTML = `<p class="text-center" style="padding: 20px; color: var(--text-light);">${app.i18n[app.lang].admin_list_loading}</p>`;
        }
        
        // Comprobación de rol (la API también comprueba esto)
        if (app.adminRole !== 'superadmin') {
             if (listContainer) listContainer.innerHTML = `<p class="text-center" style="padding: 20px; color: var(--danger);">Permisos insuficients. Només Superadmin pot gestionar usuaris.</p>`;
             if(createUserBtn) createUserBtn.style.display = 'none';
             return;
        }

        try {
            const res = await fetch('api/index.php?action=get_admins');
            const json = await res.json();
            
            if (json.status === 'success') {
                app.adminUsers = json.data;
                app.renderUserList();
            } else {
                if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color: var(--danger);">Error carregant usuaris: ${json.message}</p>`;
            }
        } catch(e) {
            if (listContainer) listContainer.innerHTML = `<p class="text-center" style="color: var(--danger);">Error de connexió al servidor: ${e.message}</p>`;
        }
    },
    
    renderUserList: function() {
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
                            
                            // Lógica de seguridad Front-end
                            const isCurrentUser = user.usuario === currentUsername; 
                            const isOnlySuperadmin = user.role === 'superadmin' && app.adminUsers.filter(u => u.role === 'superadmin').length === 1;

                            const canEdit = isSuperadmin;
                            const canDelete = isSuperadmin && !isCurrentUser && !(user.role === 'superadmin' && isOnlySuperadmin);

                            const editBtn = canEdit ? 
                                `<button class="btn-sm btn-info" title="${app.i18n[app.lang].btn_edit_user}" onclick="event.stopPropagation(); app.openEditAdminModal(${user.id})">
                                    <i class="ri-edit-line"></i>
                                </button>` : 
                                `<button class="btn-sm btn-info" disabled title="No tienes permisos para editar." style="opacity:0.5; cursor: not-allowed;">
                                    <i class="ri-edit-line"></i>
                                </button>`;


                            const deleteBtn = canDelete ? 
                                `<button class="btn-sm btn-del" onclick="event.stopPropagation(); app.handleDeleteAdmin(${user.id}, this)">
                                    <i class="ri-delete-bin-line"></i>
                                </button>` : 
                                `<button class="btn-sm btn-del" disabled title="${isCurrentUser ? 'No puedes eliminar tu propio usuario.' : isOnlySuperadmin ? 'No puedes eliminar el único Superadmin.' : 'Permisos insuficientes.'}" style="opacity:0.5; cursor: not-allowed;">
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
        
        // Ensure the New User button visibility is correct after rendering
        const createUserBtn = document.getElementById('createUserBtn');
        if(createUserBtn) createUserBtn.style.display = isSuperadmin ? 'inline-block' : 'none';
    },
    
    handleDeleteAdmin: async function(id, btn) {
        if (!confirm(app.i18n[app.lang].users_delete_confirm)) {
            return;
        }

        const originalText = btn.innerHTML;
        btn.disabled = true;
        btn.innerHTML = '<i class="ri-loader-4-line ri-spin"></i>';

        try {
            const formData = new FormData();
            formData.append('id', id);

            const res = await fetch('api/index.php?action=delete_admin', { method: 'POST', body: formData });
            
            const errorText = await res.text();
            
            if (!res.ok) {
                let message = app.i18n[app.lang].users_delete_error;
                try {
                    const json = JSON.parse(errorText);
                    message = json.message || message;
                } catch {
                    message = `Error ${res.status}: Fallo de servidor.`;
                }
                ui.showToast(message, 'error', 5000);
                return;
            }
            
            ui.showToast("Usuari eliminat correctament.", 'success', 3000);
            app.loadUserManagement();
            
        } catch(e) {
            ui.showToast("Error de connexió al servidor.", 'error', 5000);
        } finally {
            btn.innerHTML = originalText;
            btn.disabled = false;
        }
    }
};

// Validació inline de camps de formulari
app.validateField = function(input) {
    let msg = input.parentElement.querySelector('.field-message');
    if (!msg) {
        msg = document.createElement('p');
        msg.className = 'field-message';
        input.after(msg);
    }
    if (!input.checkValidity()) {
        input.classList.add('field-error');
        input.classList.remove('field-valid');
        msg.className = 'field-message error';
        msg.textContent = input.validationMessage;
    } else if (input.value.trim()) {
        input.classList.remove('field-error');
        input.classList.add('field-valid');
        msg.className = 'field-message success';
        msg.textContent = '';
    } else {
        input.classList.remove('field-error', 'field-valid');
        msg.className = 'field-message';
        msg.textContent = '';
    }
};

// GESTOR DE INTERFAZ (UI)
const ui = {
    showToast: (message, type = 'info', duration = 4000) => {
        const container = document.getElementById('toast-container');
        if (!container) return;

        // Max 3 simultaneous toasts — remove oldest
        while (container.children.length >= 3) container.firstChild?.remove();

        const icons = {
            success: 'ri-check-double-line',
            error:   'ri-close-circle-line',
            warning: 'ri-alert-line',
            info:    'ri-information-line',
        };

        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerHTML = `
    <div class="toast-inner">
        <i class="toast-icon ${icons[type] || icons.info}"></i>
        <span>${escapeHtml(String(message))}</span>
    </div>
    <div class="toast-progress" style="animation-duration:${duration}ms"></div>
`;
        toast.addEventListener('click', () => { toast.classList.remove('show'); setTimeout(() => toast.remove(), 400); });

        container.appendChild(toast);
        setTimeout(() => toast.classList.add('show'), 50);
        setTimeout(() => { toast.classList.remove('show'); setTimeout(() => toast.remove(), 400); }, duration);
    },

    toggleHeatmap: async () => {
        if (!app.map) return;
        const btn = document.getElementById('heatmap-toggle');

        if (!app.heatmapActive) {
            if (!window.L?.HeatLayer) {
                await new Promise((resolve, reject) => {
                    const s = document.createElement('script');
                    s.src = 'https://cdn.jsdelivr.net/npm/leaflet.heat@0.2.0/dist/leaflet-heat.js';
                    s.onload = resolve; s.onerror = reject;
                    document.head.appendChild(s);
                });
            }
            const points = app.allIncidents.map(i => [
                i.lat, i.lng, Math.min(1.0, 0.3 + (i.votos || 0) * 0.1)
            ]);
            app.heatLayer = L.heatLayer(points, { radius: 25, blur: 15, maxZoom: 17 });
            if (app.markers) app.markers.remove();
            app.heatLayer.addTo(app.map);
            app.heatmapActive = true;
            if (btn) btn.textContent = app.i18n[app.lang].heatmap_off || '📍 Marcadors';
        } else {
            if (app.heatLayer)  { app.heatLayer.remove(); app.heatLayer = null; }
            if (app.markers)    { app.map.addLayer(app.markers); }
            app.heatmapActive = false;
            if (btn) btn.textContent = app.i18n[app.lang].heatmap_on || '🔥 Calor';
        }
    },

    loadApp: async () => {
        await app.loadIncidents(); 
        if (app.map) {
             app.map.invalidateSize();
        }
    },
    
    startReportFlow: () => {
        // Resetear estat del wizard
        app.wizardMap = null;
        app._pickerCalledFromStep = 0;

        // Netejar categoria seleccionada
        document.querySelectorAll('.cat-grid-btn').forEach(b => {
            b.classList.remove('selected');
            b.setAttribute('aria-pressed', 'false');
        });
        const catH = document.getElementById('cat-hidden');
        if (catH) catH.value = 'infraestructura';
        const tipoH = document.getElementById('tipo-hidden');
        if (tipoH) tipoH.value = '';
        const titH = document.getElementById('titulo-hidden');
        if (titH) titH.value = '';

        // Netejar preview de foto anterior
        const imgBox = document.getElementById('img-preview');
        if (imgBox) { imgBox.style.backgroundImage = ''; imgBox.classList.add('hidden'); }
        const photoZone = document.getElementById('photo-zone');
        if (photoZone) photoZone.classList.remove('hidden');
        const fotoInput = document.getElementById('foto-input');
        if (fotoInput) fotoInput.value = '';

        app.updateFormProgress(1);
        const fabContainer = document.querySelector('.nav-fab-container');
        if (fabContainer) { fabContainer.style.opacity = '0'; fabContainer.style.pointerEvents = 'none'; }

        // Activar el picker al mapa principal (l'usuari tria la ubicació primer)
        ui.pickLocationMode();
    },

    closePanel: () => {
        const panel = document.getElementById('slide-panel');
        if (panel) {
            panel.classList.remove('open');
            panel.classList.add('closed');
            panel.setAttribute('inert', '');
        }
        const fabContainer = document.querySelector('.nav-fab-container');
        if (fabContainer) { fabContainer.style.opacity = '1'; fabContainer.style.pointerEvents = ''; }
        document.getElementById('map-picker-ui')?.classList.add('hidden');

        // Netejar el picker del mapa
        clearTimeout(app._pickerGeoTimer);
        app._pickerGeoTimer = null;
        app._pickerCalledFromStep = 0;
        if (app.centerMarker && app.map) {
            app.map.removeLayer(app.centerMarker);
            app.centerMarker = null;
            app.map.off('move');
            app.map.off('moveend');
        }
        // Return focus to the FAB that triggered the dialog
        document.getElementById('fab-nueva')?.focus();
    },

    togglePanel: () => {
        const panel = document.getElementById('slide-panel');
        if (panel) {
            if (panel.classList.contains('open')) {
                ui.closePanel();
            } else {
                ui.startReportFlow();
            }
        }
    },

    pickLocationMode: () => {
        // Tancar el panel si estava obert (però no netejar el centerMarker si ja existeix)
        const panel = document.getElementById('slide-panel');
        if (panel && panel.classList.contains('open')) {
            panel.classList.remove('open');
            panel.classList.add('closed');
            panel.setAttribute('inert', '');
        }

        document.getElementById('map-picker-ui')?.classList.remove('hidden');

        const pickerStatusMsg = document.getElementById('picker-status-msg');
        if (pickerStatusMsg) pickerStatusMsg.textContent = app.i18n[app.lang].picker_msg;

        // Geolocalització automàtica (només la primera vegada, sense centerMarker previ)
        if (navigator.geolocation && app.map && !app.centerMarker) {
            if (pickerStatusMsg) pickerStatusMsg.textContent = app.i18n[app.lang].loc_searching;
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    app.map.panTo([position.coords.latitude, position.coords.longitude], { duration: 1.0 });
                    if (pickerStatusMsg) pickerStatusMsg.textContent = app.i18n[app.lang].picker_msg;
                },
                () => {
                    if (pickerStatusMsg) pickerStatusMsg.textContent = app.i18n[app.lang].picker_msg;
                },
                { enableHighAccuracy: true, timeout: 5000, maximumAge: 0 }
            );
        }

        // Crear el marcador central si no existeix
        if (!app.centerMarker && app.map) {
            const icon = L.divIcon({
                html: '<i class="ri-map-pin-fill" style="font-size:40px; color:#002D5A; filter:drop-shadow(0 4px 8px rgba(0,0,0,0.35)); position:relative; top:-20px;"></i>',
                className: 'custom-pin',
                iconSize: [40, 40],
                iconAnchor: [20, 40]
            });
            app.centerMarker = L.marker(app.map.getCenter(), { icon, zIndexOffset: 1000 }).addTo(app.map);
            app.map.on('move', () => app.centerMarker.setLatLng(app.map.getCenter()));
        }

        // Geocodificació inversa en temps real (debounced 800ms) quan el mapa s'atura
        app.map.off('moveend');
        app.map.on('moveend', () => {
            clearTimeout(app._pickerGeoTimer);
            app._pickerGeoTimer = setTimeout(async () => {
                const center = app.map.getCenter();
                const addrDisplay = document.getElementById('picker-address-display');
                if (addrDisplay) {
                    addrDisplay.querySelector('span').textContent = app.i18n[app.lang].loc_searching;
                }
                await app.fetchAddress(center.lat, center.lng);
                if (addrDisplay) {
                    const addr = document.getElementById('addr_input')?.value;
                    const cp = document.getElementById('cp_input')?.value;
                    const barri = document.getElementById('barri_select')?.value;
                    const parts = [addr, barri, cp ? `(${cp})` : ''].filter(Boolean);
                    addrDisplay.querySelector('span').textContent = parts.join(', ') || app.i18n[app.lang].loc_unknown;
                }
            }, 800);
        });

        // Disparar geocodificació per a la posició actual
        app.map.fire('moveend');
    },
    confirmLocation: () => {
        if (!app.map) return;
        const c = app.map.getCenter();
        document.getElementById('lat_input').value = c.lat.toFixed(7);
        document.getElementById('lng_input').value = c.lng.toFixed(7);

        // Netejar el picker
        clearTimeout(app._pickerGeoTimer);
        app._pickerGeoTimer = null;
        if (app.centerMarker) {
            app.map.removeLayer(app.centerMarker);
            app.centerMarker = null;
            app.map.off('move');
            app.map.off('moveend');
        }
        document.getElementById('map-picker-ui')?.classList.add('hidden');

        // Determinar quin pas obrir: si s'ha cridat des del pas 2 (canvi d'ubicació), tornar al pas 2
        const returnStep = (app._pickerCalledFromStep === 2) ? 2 : 1;
        app._pickerCalledFromStep = 0;

        // Obrir el panel al pas corresponent
        const panel = document.getElementById('slide-panel');
        if (panel) {
            panel.classList.remove('closed');
            panel.classList.add('open');
            panel.removeAttribute('inert');
        }
        app.goWizardStep(returnStep);

        // Obtenir l'adreça definitiva i actualitzar la display
        app.fetchAddress(c.lat, c.lng)
            .then(() => app._updateWizardAddressDisplay())
            .catch(() => {});
    },
    previewImage: (input) => {
        const box = document.getElementById('img-preview');
        const file = input.files?.[0];
        if (!file) return;

        // Mostrar previsualització
        if (box) {
            const reader = new FileReader();
            reader.onload = (e) => {
                box.style.backgroundImage = `url(${e.target.result})`;
                box.classList.remove('hidden');
            };
            reader.readAsDataURL(file);
        }

        // Extreure coordenades GPS dels metadades EXIF
        if (typeof EXIF !== 'undefined') {
            EXIF.getData(file, function() {
                const lat    = EXIF.getTag(this, 'GPSLatitude');
                const latRef = EXIF.getTag(this, 'GPSLatitudeRef');
                const lng    = EXIF.getTag(this, 'GPSLongitude');
                const lngRef = EXIF.getTag(this, 'GPSLongitudeRef');

                if (lat && lng && latRef && lngRef) {
                    const latitude  = app._dmsToDecimal(lat,  latRef);
                    const longitude = app._dmsToDecimal(lng,  lngRef);

                    // Actualitzar camps ocults de coordenades
                    const latIn = document.getElementById('lat_input');
                    const lngIn = document.getElementById('lng_input');
                    if (latIn) latIn.value = latitude.toFixed(7);
                    if (lngIn) lngIn.value = longitude.toFixed(7);

                    // Geocodificació inversa i actualitzar display d'adreça
                    app.fetchAddress(latitude, longitude)
                        .then(() => app._updateWizardAddressDisplay())
                        .catch(() => {});

                    ui.showToast('📍 Ubicació detectada des de la foto', 'success', 4000);
                }
            });
        }
    }
};

document.addEventListener('DOMContentLoaded', () => app.init());