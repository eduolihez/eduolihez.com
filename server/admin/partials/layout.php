<?php
/**
 * Plantilla comun del panel de administracion.
 *   admin_header($title, $active): abre el HTML + navegacion.
 *   admin_footer(): cierra el HTML.
 * Ademas incluye helpers de presentacion reutilizados por todas las paginas
 * (tarjetas de estadistica, barras, formato de fechas, exportacion CSV segura).
 *
 * El CSS va embebido (tema oscuro) para que el panel sea autonomo: no depende
 * de ningun CDN, lo que encaja con la CSP estricta de auth.php.
 */

// Esta plantilla usa e(), db() y csrf_field(). En la practica las paginas ya
// cargan auth.php antes, pero lo declaramos para que el archivo sea autonomo
// y no dependa del orden de los require. Al ser require_once, no se ejecuta
// dos veces ni reenvia cabeceras.
require_once __DIR__ . '/../auth.php';

function admin_header(string $title, string $active = ''): void
{
    $user = function_exists('current_admin') ? current_admin() : '';

    // Contadores para los "badges" del menu.
    $unread = 0;
    try {
        $unread = (int) db()->query(
            'SELECT COUNT(*) FROM messages WHERE is_read = 0 AND is_archived = 0'
        )->fetchColumn();
    } catch (Throwable $e) {
        // ignora si la tabla o las columnas nuevas aun no existen
    }

    $nav = [
        'index.php'          => ['Panel', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>'],
        'projects.php'       => ['Proyectos', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2 2v2m4 6h.01M5 20h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>'],
        'certifications.php' => ['Certificaciones', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z" /></svg>'],
        'posts.php'          => ['Blog', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 4a2 2 0 012 2v6a2 2 0 01-2 2h-2m-4-6h.01M9 16h.01M9 12h.01M12 12h.01M12 16h.01M16 16h.01M16 12h.01" /></svg>'],
        'messages.php'       => ['Mensajes', $unread > 0 ? (string) $unread : '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>'],
        'analytics.php'      => ['Analítica', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" /></svg>'],
        'security.php'       => ['Seguridad', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" /></svg>'],
        'settings.php'       => ['Ajustes', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" /><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /></svg>'],
        'backup.php'         => ['Backup', '', '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4" /></svg>'],
    ];
    ?>
<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title><?= e($title) ?> · Admin</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #090e16; --soft: #121824; --card: rgba(19, 27, 38, 0.7); --border: rgba(255, 255, 255, 0.08);
    --text: #f3f4f6; --muted: #9ca3af; --faint: #6b7280;
    --accent: #10b981; --accent-hover: #059669; --danger: #f87171;
    --cyan: #06b6d4; --warn: #f59e0b; --violet: #8b5cf6;
    --shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.4), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
    --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--text);
    font-family: 'Inter', system-ui, -apple-system, sans-serif;
    font-size: 14px; line-height: 1.6;
    -webkit-font-smoothing: antialiased;
    overflow-x: hidden;
  }
  
  /* Scrollbar personalizado */
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: var(--bg); }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 99px; }
  ::-webkit-scrollbar-thumb:hover { background: var(--muted); }

  a { color: var(--accent); text-decoration: none; transition: color 0.15s ease; }
  a:hover { color: var(--accent-hover); }

  /* Grid Layout Principal */
  .admin-layout {
    display: grid;
    grid-template-columns: 260px 1fr;
    min-height: 100vh;
  }

  /* Sidebar */
  .sidebar {
    background: #0e1420;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
    height: 100vh;
    position: sticky;
    top: 0;
    padding: 1.5rem;
    overflow-y: auto;
    z-index: 100;
  }

  .sidebar-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2rem;
  }

  .brand {
    font-family: 'JetBrains Mono', monospace;
    font-weight: 700;
    font-size: 1.15rem;
    letter-spacing: -0.04em;
    color: var(--text);
  }
  .brand span { color: var(--accent); }

  .sidebar-menu {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
    flex: 1;
  }

  .menu-item {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.65rem 0.85rem;
    border-radius: 0.5rem;
    color: var(--muted);
    font-weight: 500;
    font-size: 0.88rem;
    transition: all 0.2s ease;
    border: 1px solid transparent;
  }

  .menu-item:hover {
    background: rgba(255, 255, 255, 0.03);
    color: var(--text);
  }

  .menu-item.active {
    background: rgba(16, 185, 129, 0.08);
    color: var(--accent);
    border-color: rgba(16, 185, 129, 0.15);
  }

  .menu-icon {
    display: flex;
    align-items: center;
    justify-content: center;
    color: inherit;
    flex-shrink: 0;
  }

  .menu-label {
    flex-grow: 1;
  }

  .badge-count {
    background: var(--accent);
    color: var(--bg);
    font-size: 0.7rem;
    font-weight: 700;
    border-radius: 99px;
    padding: 0.05rem 0.4rem;
    min-width: 18px;
    text-align: center;
  }

  .sidebar-footer {
    border-top: 1px solid var(--border);
    padding-top: 1rem;
    margin-top: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .user-info {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  .user-info .avatar {
    width: 32px;
    height: 32px;
    border-radius: 0.375rem;
    background: var(--border);
    color: var(--text);
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.75rem;
    font-family: 'JetBrains Mono', monospace;
  }

  .user-info .details {
    display: flex;
    flex-direction: column;
  }

  .user-info .username {
    font-weight: 600;
    font-size: 0.85rem;
    color: var(--text);
  }

  .user-info .role {
    font-size: 0.72rem;
    color: var(--faint);
  }

  .sidebar-actions {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .action-btn {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    padding: 0.5rem 0.75rem;
    border-radius: 0.375rem;
    font-size: 0.8rem;
    color: var(--muted);
    font-weight: 500;
    transition: all 0.2s;
    background: none;
    border: none;
    cursor: pointer;
    width: 100%;
    text-align: left;
  }

  .action-btn:hover {
    background: rgba(255, 255, 255, 0.02);
    color: var(--text);
  }

  .action-btn.danger-text:hover {
    color: var(--danger);
    background: rgba(248, 113, 113, 0.05);
  }

  /* Main Content Wrapper */
  .main-content-wrapper {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
    min-width: 0;
  }

  header.topbar {
    position: sticky;
    top: 0;
    z-index: 90;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 1rem 2rem;
    background: rgba(9, 14, 22, 0.8);
    backdrop-filter: blur(12px);
    border-bottom: 1px solid var(--border);
  }

  .topbar-left {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .topbar-title {
    font-weight: 700;
    font-size: 1.1rem;
    color: var(--text);
  }

  .user-greeting {
    font-size: 0.85rem;
    color: var(--faint);
    font-weight: 500;
  }

  .sidebar-toggle-btn {
    background: none;
    border: none;
    padding: 0.25rem;
    color: var(--text);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .mobile-only {
    display: none;
  }

  .sidebar-overlay {
    display: none;
  }

  main {
    flex-grow: 1;
    padding: 2rem;
    max-width: 1300px;
    width: 100%;
    margin: 0 auto;
  }

  /* Cards premium */
  .card {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 0.75rem;
    padding: 1.5rem;
    margin-bottom: 1.5rem;
    box-shadow: var(--shadow);
    backdrop-filter: blur(8px);
  }

  h1 { font-size: 1.75rem; font-weight: 700; margin: 0 0 1.5rem; letter-spacing: -0.03em; }
  h2 { font-size: 1.25rem; font-weight: 700; margin: 1.5rem 0 1rem; letter-spacing: -0.02em; color: var(--text); }
  h3 { font-size: 0.85rem; font-weight: 600; margin: 0 0 1rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }

  .grid { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); }
  .grid4 { display: grid; gap: 1.5rem; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); }
  
  .stat { 
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1), border-color 0.25s ease;
    position: relative;
    overflow: hidden;
  }
  .stat::before {
    content: ''; position: absolute; top: 0; left: 0; width: 3px; height: 100%;
    background: var(--accent); opacity: 0; transition: opacity 0.25s;
  }
  .stat:hover::before { opacity: 1; }
  .stat:hover { border-color: rgba(255,255,255,0.15); transform: translateY(-4px); }
  .stat .num { 
    font-family: 'JetBrains Mono', monospace; 
    font-size: 2.25rem; 
    font-weight: 700; 
    color: var(--accent); 
    line-height: 1; 
    letter-spacing: -0.04em; 
    display: flex;
    align-items: baseline;
    justify-content: space-between;
  }
  .stat .num.cyan { color: var(--cyan); }
  .stat .num.warn { color: var(--warn); }
  .stat .num.violet { color: var(--violet); }
  .stat .num.danger { color: var(--danger); }
  .stat .lbl { color: var(--muted); font-size: 0.82rem; margin-top: 0.75rem; font-weight: 500; line-height: 1.5; }
  
  .delta { 
    font-size: 0.72rem; font-weight: 700; margin-left: 0.5rem; padding: 0.15rem 0.4rem; 
    border-radius: 0.375rem; vertical-align: middle;
  }
  .delta.up { color: var(--accent); background: rgba(16, 185, 129, 0.12); }
  .delta.down { color: var(--danger); background: rgba(248, 113, 113, 0.12); }
  .delta.flat { color: var(--faint); background: rgba(255, 255, 255, 0.04); }

  /* Tablas */
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 1rem 0.85rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
  th { color: var(--faint); font-weight: 600; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.08em; }
  tr:last-child td { border-bottom: none; }
  tr { transition: background-color 0.15s ease; }
  tr:hover td { background: rgba(255, 255, 255, 0.02); }

  /* Form Controls */
  label { display: block; margin: 1rem 0 0.4rem; font-weight: 600; font-size: 0.85rem; color: var(--text); }
  input[type=text], input[type=email], input[type=password], input[type=url],
  input[type=number], input[type=date], input[type=search], textarea, select {
    width: 100%; padding: 0.7rem 0.9rem; background: rgba(9, 14, 22, 0.7);
    border: 1px solid var(--border); border-radius: 0.5rem; color: var(--text);
    font-size: 0.92rem; font-family: inherit; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  input:focus, textarea:focus, select:focus { 
    outline: none; border-color: var(--accent); 
    box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.15); 
    background: rgba(9, 14, 22, 0.9);
  }
  textarea { resize: vertical; min-height: 120px; }
  
  .row2 { display: grid; gap: 1.5rem; grid-template-columns: 1fr 1fr; }
  .row3 { display: grid; gap: 1.5rem; grid-template-columns: repeat(3, 1fr); }

  /* Botones */
  .btn {
    display: inline-flex; align-items: center; justify-content: center; gap: 0.5rem; cursor: pointer;
    padding: 0.65rem 1.25rem; border-radius: 0.5rem; font-weight: 600; font-size: 0.88rem;
    border: 1px solid transparent; background: var(--accent); color: var(--bg);
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .btn:hover { background: var(--accent-hover); box-shadow: var(--shadow); }
  .btn.ghost { background: transparent; color: var(--text); border-color: var(--border); }
  .btn.ghost:hover { border-color: var(--accent); color: var(--accent); background: rgba(16, 185, 129, 0.03); }
  .btn.danger { background: transparent; color: var(--danger); border-color: rgba(248, 113, 113, 0.35); }
  .btn.danger:hover { background: rgba(248, 113, 113, 0.08); }
  .btn.sm { padding: 0.4rem 0.85rem; font-size: 0.8rem; border-radius: 0.375rem; }
  .btn.icon { padding: 0.4rem 0.55rem; font-size: 0.85rem; border-radius: 0.375rem; }
  .btn[disabled] { opacity: 0.35; pointer-events: none; }

  /* Badges */
  .pill { 
    display: inline-block; padding: 0.15rem 0.5rem; border-radius: 0.375rem; 
    font-size: 0.72rem; font-weight: 600; border: 1px solid var(--border); 
    background: var(--soft); color: var(--muted); 
  }
  .pill.on { color: var(--accent); border-color: rgba(16, 185, 129, 0.25); background: rgba(16, 185, 129, 0.06); }
  .pill.off { color: var(--faint); background: rgba(255, 255, 255, 0.02); }
  .pill.warn { color: var(--warn); border-color: rgba(245, 158, 11, 0.25); background: rgba(245, 158, 11, 0.06); }
  .pill.danger { color: var(--danger); border-color: rgba(248, 113, 113, 0.25); background: rgba(248, 113, 113, 0.06); }

  .actions { display: flex; gap: 0.5rem; flex-wrap: wrap; align-items: center; }
  .flash { padding: 0.85rem 1.25rem; border-radius: 0.5rem; margin-bottom: 1.5rem; font-size: 0.88rem; font-weight: 500; }
  .flash.ok { background: rgba(16, 185, 129, 0.08); color: var(--accent); border: 1px solid rgba(16, 185, 129, 0.15); }
  .flash.err { background: rgba(248, 113, 113, 0.08); color: var(--danger); border: 1px solid rgba(248, 113, 113, 0.15); }
  .flash.warn { background: rgba(245, 158, 11, 0.06); color: var(--warn); border: 1px solid rgba(245, 158, 11, 0.15); }
  .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 1.25rem; margin-bottom: 1.5rem; flex-wrap: wrap; }
  .hint { color: var(--faint); font-size: 0.78rem; margin-top: 0.3rem; line-height: 1.5; }
  
  /* Horizontal bar graphs */
  .bar-wrap { height: 6px; background: rgba(255, 255, 255, 0.04); border-radius: 99px; overflow: hidden; margin-top: 0.4rem; }
  .bar { height: 100%; background: var(--cyan); border-radius: 99px; }
  .bar.green { background: var(--accent); }
  .bar.violet { background: var(--violet); }
  .barline { margin-bottom: 0.85rem; }
  .barline .lab { display: flex; justify-content: space-between; font-size: 0.82rem; gap: 1rem; }
  .barline .lab span:first-child { color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .barline .lab span:last-child { color: var(--faint); white-space: nowrap; font-family: 'JetBrains Mono', monospace; }
  
  /* Vertical bar charts */
  .chart { display: flex; align-items: flex-end; gap: 0.5rem; height: 180px; overflow-x: auto; padding-bottom: 0.25rem; border-bottom: 1px solid var(--border); }
  .chart .col { flex: 1 0 16px; display: flex; flex-direction: column; align-items: center; gap: 0.35rem; min-width: 16px; }
  .chart .bar-v { width: 100%; background: var(--accent); border-radius: 4px 4px 0 0; min-height: 4px; transition: height 0.3s ease, background 0.15s; }
  .chart .bar-v:hover { background: var(--accent-hover); filter: brightness(1.1); cursor: pointer; }
  .chart .tick { color: var(--faint); font-size: 0.62rem; white-space: nowrap; margin-top: 0.2rem; }
  .chart .val { color: var(--faint); font-size: 0.68rem; font-family: 'JetBrains Mono', monospace; }
  
  .tabs { display: flex; gap: 0.35rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
  .tabs a { padding: 0.45rem 1rem; border-radius: 0.5rem; font-size: 0.82rem; font-weight: 500; color: var(--muted); border: 1px solid var(--border); transition: all 0.2s; }
  .tabs a.active { background: rgba(16, 185, 129, 0.08); color: var(--accent); border-color: rgba(16, 185, 129, 0.15); }
  .tabs a:hover { text-decoration: none; color: var(--text); border-color: var(--muted); }
  
  .checkline { display: flex; align-items: flex-start; gap: 0.75rem; margin: 0 0 1.25rem; font-weight: 400; cursor: pointer; }
  .checkline input { width: auto; margin-top: 0.25rem; cursor: pointer; }
  .checkline strong { display: block; font-size: 0.9rem; color: var(--text); }
  .empty { padding: 3rem; color: var(--muted); text-align: center; font-style: italic; }
  .scroll-x { overflow-x: auto; border-radius: 0.5rem; border: 1px solid var(--border); background: var(--card); }
  .nowrap { white-space: nowrap; }

  /* Responsive Sidebar rules */
  @media (max-width: 900px) {
    .admin-layout {
      grid-template-columns: 1fr;
    }
    .sidebar {
      position: fixed;
      left: 0;
      top: 0;
      bottom: 0;
      width: 270px;
      transform: translateX(-100%);
      transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
      box-shadow: 10px 0 25px rgba(0, 0, 0, 0.5);
    }
    .sidebar.open {
      transform: translateX(0);
    }
    .mobile-only {
      display: flex;
    }
    .sidebar-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0, 0, 0, 0.6);
      backdrop-filter: blur(4px);
      z-index: 99;
      display: none;
      transition: opacity 0.25s;
    }
    .sidebar-overlay.open {
      display: block;
    }
    header.topbar {
      padding: 1rem 1.5rem;
    }
    main {
      padding: 1.5rem;
    }
  }
</style>
</head>
<body>
<div class="admin-layout">
  <div id="sidebar-overlay" class="sidebar-overlay"></div>
  
  <aside id="admin-sidebar" class="sidebar">
    <div class="sidebar-header">
      <span class="brand">&gt;_ <span>admin</span></span>
      <button id="sidebar-close-btn" class="sidebar-toggle-btn mobile-only" aria-label="Cerrar menu">
        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
      </button>
    </div>
    
    <nav class="sidebar-menu">
      <?php foreach ($nav as $file => [$label, $badge, $icon]): ?>
        <a href="<?= e($file) ?>" class="menu-item <?= $active === $file ? 'active' : '' ?>">
          <span class="menu-icon"><?= $icon ?></span>
          <span class="menu-label"><?= e($label) ?></span>
          <?php if ($badge !== ''): ?><span class="badge-count"><?= e($badge) ?></span><?php endif; ?>
        </a>
      <?php endforeach; ?>
    </nav>
    
    <div class="sidebar-footer">
      <div class="user-info">
        <div class="avatar"><?= strtoupper(substr($user, 0, 2)) ?></div>
        <div class="details">
          <span class="username"><?= e($user) ?></span>
          <span class="role">Administrador</span>
        </div>
      </div>
      <div class="sidebar-actions">
        <a href="/" target="_blank" rel="noopener" class="action-btn">
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
          Ver web
        </a>
        <form method="post" action="logout.php" style="display:inline; width:100%;">
          <?= csrf_field() ?>
          <button type="submit" class="action-btn danger-text">
            <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
            Cerrar sesion
          </button>
        </form>
      </div>
    </div>
  </aside>
  
  <div class="main-content-wrapper">
    <header class="topbar">
      <div class="topbar-left">
        <button id="sidebar-open-btn" class="sidebar-toggle-btn mobile-only" aria-label="Abrir menu">
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" /></svg>
        </button>
        <span class="topbar-title"><?= e($title) ?></span>
      </div>
      <div class="topbar-right">
        <span class="user-greeting">Consola de Control</span>
      </div>
    </header>
    <main>
<?php
}

function admin_footer(): void
{
    ?>
    </main>
  </div>
</div>

<script>
  document.addEventListener('DOMContentLoaded', () => {
    const openBtn = document.getElementById('sidebar-open-btn');
    const closeBtn = document.getElementById('sidebar-close-btn');
    const overlay = document.getElementById('sidebar-overlay');
    const sidebar = document.getElementById('admin-sidebar');

    const toggleSidebar = (state) => {
      if (sidebar && overlay) {
        sidebar.classList.toggle('open', state);
        overlay.classList.toggle('open', state);
        document.body.style.overflow = state ? 'hidden' : '';
      }
    };

    if (openBtn) openBtn.addEventListener('click', () => toggleSidebar(true));
    if (closeBtn) closeBtn.addEventListener('click', () => toggleSidebar(false));
    if (overlay) overlay.addEventListener('click', () => toggleSidebar(false));
  });
</script>
<script src="assets/admin.js"></script>
</body>
</html>
<?php
}

// ---------------------------------------------------------------------------
// Mensajes flash
// ---------------------------------------------------------------------------

/** Guarda un mensaje flash en sesion para mostrarlo tras un redirect. */
function set_flash(string $type, string $msg): void
{
    $_SESSION['flash'] = ['type' => $type, 'msg' => $msg];
}

/** Imprime y limpia el mensaje flash si existe. */
function show_flash(): void
{
    if (empty($_SESSION['flash'])) {
        return;
    }
    $f = $_SESSION['flash'];
    unset($_SESSION['flash']);
    $cls = in_array($f['type'], ['ok', 'warn'], true) ? $f['type'] : 'err';
    echo '<div class="flash ' . $cls . '">' . e($f['msg']) . '</div>';
}

// ---------------------------------------------------------------------------
// Helpers de presentacion
// ---------------------------------------------------------------------------

/** Tarjeta de estadistica. $color: '' | cyan | warn | violet | danger */
function stat_card(string $value, string $label, string $color = '', string $sub = ''): void
{
    echo '<div class="card stat">'
        . '<div class="num ' . e($color) . '">' . e($value) . '</div>'
        . '<div class="lbl">' . $label
        . ($sub !== '' ? '<br><span class="faint">' . e($sub) . '</span>' : '')
        . '</div></div>';
}

/** Etiqueta de variacion porcentual respecto al periodo anterior. */
function delta_badge(int $now, int $before): string
{
    if ($before === 0) {
        return $now > 0 ? '<span class="delta up">nuevo</span>' : '';
    }
    $pct = round((($now - $before) / $before) * 100);
    $cls = $pct > 0 ? 'up' : ($pct < 0 ? 'down' : 'flat');
    $sig = $pct > 0 ? '+' : '';
    return '<span class="delta ' . $cls . '">' . $sig . $pct . '%</span>';
}

/** Fila de barra horizontal con etiqueta y valor. */
function bar_row(string $label, int $value, int $max, string $color = '', string $suffix = ''): void
{
    $pct = $max > 0 ? max(1, (int) round(($value / $max) * 100)) : 0;
    echo '<div class="barline">'
        . '<div class="lab"><span>' . e($label) . '</span>'
        . '<span>' . number_format($value) . ($suffix !== '' ? ' · ' . e($suffix) : '') . '</span></div>'
        . '<div class="bar-wrap"><div class="bar ' . e($color) . '" style="width:' . $pct . '%"></div></div>'
        . '</div>';
}

/** Fecha corta legible a partir de un DATETIME de MySQL. */
function fdate(?string $sqlDate, string $format = 'd/m/Y H:i'): string
{
    if (!$sqlDate) {
        return '—';
    }
    $ts = strtotime($sqlDate);
    return $ts ? date($format, $ts) : '—';
}

/** "hace 5 min", "hace 2 h", "hace 3 d"... a partir de un DATETIME. */
function ago(?string $sqlDate): string
{
    if (!$sqlDate) {
        return '—';
    }
    $ts = strtotime($sqlDate);
    if (!$ts) {
        return '—';
    }
    $diff = max(0, time() - $ts);
    if ($diff < 60)     return 'hace ' . $diff . ' s';
    if ($diff < 3600)   return 'hace ' . floor($diff / 60) . ' min';
    if ($diff < 86400)  return 'hace ' . floor($diff / 3600) . ' h';
    if ($diff < 2592000) return 'hace ' . floor($diff / 86400) . ' d';
    return date('d/m/Y', $ts);
}

/** Tamano legible a partir de bytes. */
function fbytes(float $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB'];
    $i = 0;
    while ($bytes >= 1024 && $i < count($units) - 1) {
        $bytes /= 1024;
        $i++;
    }
    return round($bytes, $i === 0 ? 0 : 1) . ' ' . $units[$i];
}

// ---------------------------------------------------------------------------
// Exportacion CSV segura
// ---------------------------------------------------------------------------

/**
 * Neutraliza la INYECCION DE FORMULAS en CSV.
 *
 * Excel y LibreOffice ejecutan como formula cualquier celda que empiece por
 * = + - @ (o tab / retorno de carro). Un mensaje de contacto con
 * `=HYPERLINK("http://malo","click")` -o algo peor- se ejecutaria al abrir
 * el CSV exportado. Le anteponemos un apostrofe para que se trate como texto.
 */
function csv_safe($value): string
{
    $v = (string) $value;
    if ($v !== '' && strpbrk($v[0], "=+-@\t\r") !== false) {
        return "'" . $v;
    }
    return $v;
}

/**
 * Envia un CSV como descarga y termina la ejecucion.
 * @param array<int,string>       $headers Cabecera de columnas
 * @param iterable<int,array>     $rows    Filas (arrays de valores)
 */
function csv_download(string $filename, array $headers, iterable $rows): void
{
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    header('X-Content-Type-Options: nosniff');

    $out = fopen('php://output', 'w');
    fwrite($out, "\xEF\xBB\xBF"); // BOM UTF-8 para que Excel lea bien los acentos
    fputcsv($out, $headers);
    foreach ($rows as $row) {
        fputcsv($out, array_map('csv_safe', $row));
    }
    fclose($out);
    exit;
}
