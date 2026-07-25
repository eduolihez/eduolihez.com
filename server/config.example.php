<?php
/**
 * PLANTILLA DE CONFIGURACION
 * ---------------------------------------------------------------------------
 * 1. Copia este archivo a "config.php" (en la misma carpeta).
 * 2. Rellena tus credenciales reales de la base de datos de CDMON.
 * 3. NUNCA subas config.php a un repositorio publico (esta en .gitignore).
 *
 * En CDMON obtienes DB_HOST/DB_NAME/DB_USER/DB_PASS al crear la base de
 * datos MySQL desde el panel de control.
 */

return [
    // --- Base de datos MySQL/MariaDB ---
    'db' => [
        'host'    => 'localhost',            // En CDMON suele ser 'localhost'
        'name'    => 'TU_BASE_DE_DATOS',     // p.ej. 1234567_portfolio
        'user'    => 'TU_USUARIO_DB',
        'pass'    => 'TU_PASSWORD_DB',
        'charset' => 'utf8mb4',
    ],

    // --- Notificaciones por email del formulario de contacto ---
    'mail' => [
        'enabled' => true,
        'to'      => 'eduardo@eduolihez.com',   // donde recibiras los avisos
        'from'    => 'no-reply@eduolihez.com', // remitente (usa tu dominio)
        'subject_prefix' => '[Portfolio] ',
    ],

    // --- Seguridad ---
    'security' => [
        // Origen permitido para las llamadas del frontend.
        // Si el sitio y el API estan en el MISMO dominio, dejalo vacio ('')
        // y no se enviaran cabeceras CORS (no hacen falta).
        'allowed_origin' => '',

        // Anti-spam del formulario: maximo de mensajes por IP y ventana (min).
        'contact_max_per_window' => 5,
        'contact_window_minutes' => 60,

        // Sal para hashear IPs en la analitica (privacidad / GDPR).
        // Cambiala por una cadena larga y aleatoria propia.
        'ip_salt' => 'CAMBIA_ESTO_por_una_cadena_larga_y_aleatoria_1234567890',

        // ¿Estas detras de un proxy/CDN de CONFIANZA (p.ej. Cloudflare)?
        // - false (por defecto): se usa la IP real de la conexion (REMOTE_ADDR).
        //   Es lo SEGURO en hosting normal: nadie puede falsear su IP.
        // - true: SOLO si TODO tu trafico pasa por Cloudflare. Entonces se lee
        //   la IP del visitante desde CF-Connecting-IP. Ver CLOUDFLARE.md.
        'trust_proxy' => false,

        // Login del panel: bloqueo por fuerza bruta.
        'login_max_attempts'   => 5,   // intentos fallidos permitidos...
        'login_lockout_minutes' => 15, // ...antes de bloquear esta ventana (min)

        // Caducidad de la sesion del panel.
        'session_idle_minutes' => 120, // cierra tras 2 h sin actividad
        'session_max_hours'    => 12,  // duracion maxima absoluta

        // Analitica: maximo de visitas registradas por visitante y minuto.
        // Frena que un bot infle la tabla `visits` cambiando de ruta.
        'visit_max_per_minute' => 30,
    ],

    // --- Cloudflare Turnstile (captcha invisible del formulario) ---
    // OPCIONAL. Se activa solo si rellenas ambas claves. Ver CLOUDFLARE.md.
    // Si las dejas vacias, el formulario funciona igual (honeypot + rate-limit).
    'turnstile' => [
        'site_key'   => '',  // clave publica (tambien en src/config.ts)
        'secret_key' => '',  // clave secreta (SOLO aqui, nunca en el frontend)
    ],

    // --- Subida de imagenes desde el panel ---
    'uploads' => [
        // Carpeta fisica donde se guardan (debe existir y tener permisos de
        // escritura). Relativa a la raiz web. Se sirve como /uploads/...
        'dir'         => __DIR__ . '/uploads',
        'url_base'    => '/uploads',
        'max_bytes'     => 3 * 1024 * 1024, // 3 MB
        'max_dimension' => 6000,            // px maximos por lado
        'allowed_ext'   => ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    ],

    // Zona horaria para las fechas del panel y de la base de datos.
    'timezone' => 'Europe/Madrid',

    // Poner a true SOLO mientras depuras (muestra errores). En produccion: false.
    'debug' => false,
];
