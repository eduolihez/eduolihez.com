/**
 * Parte un texto en frases para pintarlo como lista de logros (Experience.astro).
 * Corta tras . ! ? solo si lo siguiente empieza en mayuscula o comillas, asi
 * "N1/N2" o "Python." dentro de una frase no se rompen. Sin texto -> [].
 */
export function splitSentences(text: string): string[] {
  return text
    .trim()
    .split(/(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÀÈÒÜÇÑ"'¿¡])/u)
    .map((s) => s.trim())
    .filter(Boolean);
}
