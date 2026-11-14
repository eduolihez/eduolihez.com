/**
 * Decide si una pagina lleva el nodo ProfilePage en su JSON-LD.
 *
 * Google reserva ProfilePage para paginas cuyo tema principal es una persona.
 * Por defecto solo las portadas (es/en/ca); cualquier otra pagina (posts,
 * proyectos, "sobre esta web") no debe declararlo. Una pagina de perfil
 * concreta, como la de analista SOC, lo activa con `profile: true`.
 */
export function shouldEmitProfilePage(
  profile: boolean | undefined,
  path: string,
  homePath: string,
): boolean {
  return profile ?? path === homePath;
}
