/**
 * print.ts - Boton "Imprimir / guardar dossier": llama a window.print() desde
 * un script externo (la CSP no permite handlers inline). El PDF lo genera el
 * navegador con la hoja @media print de global.css; no hay nada en servidor.
 */
export function initPrintButtons(root: ParentNode = document, print: () => void = () => window.print()): number {
  const buttons = root.querySelectorAll<HTMLButtonElement>('[data-print]');
  let count = 0;
  buttons.forEach((b) => {
    if (b.dataset.printReady === '1') return;
    b.dataset.printReady = '1';
    count++;
    b.addEventListener('click', () => print());
  });
  return count;
}
