# Eduardo Olivares Hernández - Portfolio Profesional

Este repositorio contiene el código fuente de mi sitio web y portfolio profesional de ciberseguridad y sistemas, accesible públicamente en [eduolihez.com](https://eduolihez.com).

El sitio web está diseñado con un enfoque moderno, minimalista y de alto rendimiento, optimizado para ser rápido, seguro y adaptado a dispositivos móviles.

## 🧱 Arquitectura y Stack Tecnológico

El proyecto está estructurado en dos partes principales, garantizando una separación limpia entre la presentación estática y la administración de contenidos:

### Frontend
- **Astro 5**: Generación de sitio estático (SSG), lo que permite que las páginas web se carguen casi instantáneamente al no depender de ejecución en el servidor para las vistas principales.
- **Tailwind CSS**: Estilos responsivos con un diseño oscuro pulido y moderno adaptado a la temática de ciberseguridad.
- **TypeScript & JavaScript (Vanilla)**: Lógica interactiva en cliente (animaciones de entrada, filtrado dinámico de contenido, etc.).
- **Soporte Trilingüe nativo**: Traducción completa al español (`/`), inglés (`/en/`) y catalán (`/ca/`).

### Backend (Gestión interna)
- **PHP 8 (PDO)**: Un panel de administración propio (`/admin`) desarrollado a medida para gestionar el contenido dinámico del portfolio (proyectos, certificaciones), gestionar mensajes recibidos y monitorizar las analíticas del sitio.
- **Base de Datos MySQL / MariaDB**: Almacenamiento estructurado del contenido dinámico y logs de seguridad.
- **Formspree**: Sistema de contacto seguro de respaldo para recepción de emails.
- **Analítica de Privacidad**: Analíticas integradas propias que registran visitas generales hasheando la dirección IP (GDPR friendly), evitando el uso de cookies de seguimiento o scripts de terceros (como Google Analytics).

## 📂 Estructura del Repositorio

- `src/`: Componentes, layouts, datos estáticos y lógica de internacionalización de la aplicación web en Astro.
- `public/`: Recursos estáticos de la web, imágenes, favicons y archivos de soporte.
- `server/`: Backend en PHP que contiene la API para cargar datos dinámicamente y el panel de administración seguro `/admin`.
- `database/`: Esquemas SQL para la base de datos MySQL (estructura y migraciones).
- `LICENSE`: Licencia MIT del proyecto.

## 🔒 Características de Seguridad

El backend incluye medidas de seguridad avanzadas e integradas para garantizar la integridad del sitio:
- **Protección contra Fuerza Bruta**: Bloqueo automático de logins fallidos de forma temporal.
- **CSRF (Cross-Site Request Forgery)**: Implementación de tokens de seguridad en todas las solicitudes del panel de administración.
- **Seguridad en Base de Datos**: Uso estricto de consultas preparadas (PDO) contra ataques de Inyección SQL.
- **Seguridad de Archivos Subidos**: Validación exhaustiva de subida de imágenes (comprobación de MIME reales, dimensiones máximas, y deshabilitación de ejecución en directorios de subida).
- **Cabeceras de Seguridad y CSP**: Content Security Policy estricta y cabeceras configuradas mediante `.htaccess`.

## 💼 Perfil Profesional
Soy analista de seguridad orientado a operaciones del Blue Team (análisis de logs, detección de amenazas, respuesta a incidentes y automatización). Puedes encontrar más información detallada y contactar conmigo a través de mi sitio web o en mi perfil de LinkedIn.

---
Licencia del código fuente: [MIT License](LICENSE).
