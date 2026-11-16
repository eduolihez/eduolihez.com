/**
 * contactReason.ts - Motivo del formulario de contacto (M5). El backend no
 * cambia: el motivo se antepone al asunto como [Oferta] / [Proyecto]; "Otro"
 * no anade nada. Sin JS el formulario ni siquiera envia, asi que no cambia nada.
 */

export type ContactReason = 'job' | 'project' | 'other';

/** Longitud maxima del asunto (maxlength del input y del backend). */
export const SUBJECT_MAX = 150;

const TAGS: Record<ContactReason, string> = {
  job: '[Oferta]',
  project: '[Proyecto]',
  other: '',
};

/** Etiqueta del motivo; valor desconocido = sin etiqueta (equivale a "Otro"). */
export function reasonTag(reason: string): string {
  return Object.hasOwn(TAGS, reason) ? TAGS[reason as ContactReason] : '';
}

/** Asunto final: "[Oferta] asunto". Con asunto vacio, solo la etiqueta. */
export function applyReason(subject: string, reason: string): string {
  const tag = reasonTag(reason);
  return (tag ? `${tag} ${subject}` : subject).trim().slice(0, SUBJECT_MAX);
}
