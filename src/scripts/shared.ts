/**
 * shared.ts - Utilidades comunes a las islas dinamicas (blog, proyectos,
 * certificaciones). Antes vivian triplicadas (safeUrl, fetchWithRetry,
 * setState) casi al caracter en blog.ts/projects.ts/certifications.ts;
 * cualquier cambio futuro (esquema de URL permitido, backoff de reintentos)
 * exigia tocar 2-3 sitios en sincronia. Ahora hay una sola fuente de verdad.
 */

// --- Seguridad (S3): solo se aceptan URLs de esquema seguro ---
// Incluye mailto: (proyectos/certificaciones ya lo aceptaban; blog.ts no,
// pero blog.ts solo lo usa para imagenes de portada, donde un mailto: nunca
// llegaria a cargar nada -- unificar no abre ningun hueco nuevo).
//
// Nota de paridad: esto acepta http:// ademas de https://, a diferencia de
// validate_public_url() en server/lib/validate.php (solo https://). Es
// intencional en direcciones distintas: el backend valida lo que un ADMIN
// escribe a mano (fuerza https, coherente con que todo el sitio fuerza TLS);
// esto valida datos que YA estan en la API publica (enlaces a terceros como
// GitHub/Credly, donde exigir https podria ocultar un enlace real). No hay
// un tipo compartido entre PHP y TS que fuerce que ambas reglas evolucionen
// juntas -- si cambias el esquema aceptado aqui, revisa tambien el otro lado.
export function safeUrl(url: unknown): string {
  if (typeof url !== 'string') return '';
  const u = url.trim();

  // Bypass de "empieza por /" (auditoria de seguridad del 2026-08-25, dos
  // rondas -- ver shared.test.ts para el porque de cada caso):
  //
  // 1) Los navegadores tratan "\" como "/" al parsear una URL de esquema
  //    especial (http/https/ws/wss/ftp/file) -- compatibilidad heredada de
  //    IE, parte del propio estandar WHATWG URL. "/\evil.example/x" EMPIEZA
  //    por "/" (pasaria un check ingenuo) pero el navegador lo resuelve como
  //    "//evil.example/x": protocolo-relativo a un dominio externo.
  // 2) El parser WHATWG tambien QUITA cualquier tabulador, salto de linea o
  //    retorno de carro (\t \n \r) de CUALQUIER posicion de la URL -- no
  //    solo al principio o al final -- antes de interpretarla. Por eso
  //    "/\t/evil.example/x" (una tabulacion real entre las dos barras) no
  //    contiene "\" literal ni empieza por "//" tal cual, pero el navegador
  //    la reduce a "//evil.example/x" igual que el caso 1.
  //
  // Se corta ANTES de mirar el esquema.
  if (u.includes('\\') || /^\/\//.test(u) || /[\t\n\r]/.test(u)) return '';

  if (/^(https?:\/\/|mailto:|\/)/i.test(u)) return u;
  return '';
}

/**
 * Panel de estado (carga/vacio/error). El CSS decide el icono y si aparece
 * el boton de reintento a partir de `data-state` (ver StatusPanel.astro).
 */
export function setStatusPanel(
  status: HTMLElement | null,
  statusText: HTMLElement | null,
  state: 'loading' | 'empty' | 'error',
  text: string,
): void {
  if (statusText) statusText.textContent = text;
  if (status) {
    status.setAttribute('data-state', state);
    status.classList.remove('hidden');
  }
}

/**
 * fetch() con reintentos y backoff exponencial (x1.5 por intento).
 *
 * BUG HISTORICO (arreglado aqui): la version original encadenaba
 * `.then().catch()` en cada nivel de recursion. Cuando el intento mas
 * profundo agotaba SUS reintentos y rechazaba, ese rechazo subia por cada
 * `.then()` padre -- y el `.catch()` de CADA nivel volvia a comprobar SU
 * propio `retries` (el valor original de esa llamada, no el ya gastado) y
 * reintentaba OTRA VEZ desde ahi. Con retries=3 eso significaba muchos mas
 * intentos reales de los 3 previstos, y un fallo total tardaba bastante mas
 * de lo que sugeria leer el codigo (detectado escribiendo tests con
 * temporizadores reales: tardaban tanto que hubo que pasar a
 * vi.useFakeTimers()).
 *
 * Aqui SOLO hay un `.catch()` por nivel (el de `run`), y `attempt()` no se
 * llama a si misma nunca -- la recursion vive unicamente en el `.catch()` de
 * `run`, asi que un fallo total hace como mucho `retries + 1` intentos, ni
 * uno mas.
 */
export function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  retries = 3,
  delay = 500,
): Promise<unknown> {
  function attempt(): Promise<unknown> {
    return fetch(url, options).then((res) => {
      if (!res.ok) throw new Error('HTTP ' + res.status);
      return res.json();
    });
  }

  function run(remaining: number, currentDelay: number): Promise<unknown> {
    return attempt().catch((err) => {
      if (remaining > 0) {
        return new Promise((resolve) => setTimeout(resolve, currentDelay)).then(() =>
          run(remaining - 1, currentDelay * 1.5),
        );
      }
      throw err;
    });
  }

  return run(retries, delay);
}
