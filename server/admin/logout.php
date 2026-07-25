<?php
/**
 * logout.php - Cierra la sesion y vuelve al login.
 * Requiere un token CSRF valido (?token=...) para evitar que un tercero te
 * fuerce el cierre de sesion desde otra web (CSRF de logout, S8).
 */
require_once __DIR__ . '/auth.php';

// Solo POST con token CSRF valido. Un GET no puede cerrar tu sesion, asi que
// el token deja de viajar en la URL (donde acababa en el historial y en los
// logs del servidor).
$expected = $_SESSION['csrf'] ?? '';
$sent     = (string) ($_POST['csrf'] ?? '');

$valid = ($_SERVER['REQUEST_METHOD'] ?? '') === 'POST'
    && is_logged_in()
    && is_string($expected) && $expected !== ''
    && $sent !== ''
    && hash_equals($expected, $sent);

if (!$valid) {
    redirect('login.php');
}

log_activity('logout', 'admin_user', (int) ($_SESSION['admin_id'] ?? 0), 'Cierre de sesion');
logout_user();
redirect('login.php');
