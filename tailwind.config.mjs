/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,md,mdx}'],
  darkMode: 'class', // el sitio es oscuro por defecto (clase "dark" en <html>)
  theme: {
    extend: {
      colors: {
        // Paleta oscura minimalista orientada a ciberseguridad.
        // Acento verde/cian "terminal" sobre fondo casi negro.
        bg: {
          DEFAULT: '#0a0e14', // fondo principal
          soft: '#0f141c', // fondo de secciones alternas
          card: '#141a24', // tarjetas
          border: '#1f2733', // bordes sutiles
        },
        accent: {
          DEFAULT: '#4ade80', // verde principal (CTA, enlaces)
          hover: '#22c55e',
          soft: '#134e2a', // fondo tenue para badges
          cyan: '#22d3ee', // acento secundario
        },
        text: {
          DEFAULT: '#e6edf3', // texto principal
          muted: '#9aa7b8', // texto secundario
          faint: '#6b7688', // texto terciario / metadatos
        },
      },
      fontFamily: {
        sans: [
          'Inter',
          'system-ui',
          '-apple-system',
          'Segoe UI',
          'Roboto',
          'sans-serif',
        ],
        mono: [
          'JetBrains Mono',
          'ui-monospace',
          'SFMono-Regular',
          'Menlo',
          'monospace',
        ],
      },
      maxWidth: {
        content: '72rem', // ancho maximo del contenido (~1152px)
      },
      keyframes: {
        'fade-up': {
          '0%': { opacity: '0', transform: 'translateY(16px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        'pulse-dot': {
          '0%, 100%': { opacity: '1' },
          '50%': { opacity: '0.4' },
        },
      },
      animation: {
        'fade-up': 'fade-up 0.6s ease-out both',
        'pulse-dot': 'pulse-dot 2s ease-in-out infinite',
      },
    },
  },
  plugins: [],
};
