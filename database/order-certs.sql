-- ===========================================================================
--  PATCH: Reordenar Certificaciones
--  Portfolio Eduardo Olivares
--  Fecha: 2026-07-25
--
--  INSTRUCCIONES (CDMON):
--    phpMyAdmin -> tu base de datos -> pestaña "Importar" -> este archivo.
-- ===========================================================================

-- 1) Desplazar temporalmente todas las certificaciones existentes
UPDATE `certifications` SET `sort_order` = `sort_order` + 50;

-- 2) Asignar orden de prioridad (1 al 6) a las más valiosas
UPDATE `certifications` SET `sort_order` = 1 WHERE `name` = 'Fortinet NSE' AND `issuer` = 'Fortinet';
UPDATE `certifications` SET `sort_order` = 2 WHERE `name` = 'Microsoft Certified: Azure AI Fundamentals' AND `issuer` = 'Microsoft';
UPDATE `certifications` SET `sort_order` = 3 WHERE `name` = 'Trend Micro Vision One Platform - Advanced' AND `issuer` = 'Trend Micro';
UPDATE `certifications` SET `sort_order` = 4 WHERE `name` = 'TryHackMe Pre-Security' AND `issuer` = 'TryHackMe';
UPDATE `certifications` SET `sort_order` = 5 WHERE `name` = 'Introducción a la Ciberseguridad' AND `issuer` = 'Cisco Networking Academy';
UPDATE `certifications` SET `sort_order` = 6 WHERE `name` = 'Introduction to Modern AI' AND `issuer` = 'Cisco Networking Academy';

-- 3) Poner el resto en el orden siguiente
UPDATE `certifications` SET `sort_order` = 7 WHERE `name` = 'Fundamentos profesionales en ciberseguridad' AND `issuer` = 'Microsoft / LinkedIn';
UPDATE `certifications` SET `sort_order` = 8 WHERE `name` = 'Microsoft Copilot para Seguridad' AND `issuer` = 'LinkedIn';
UPDATE `certifications` SET `sort_order` = 9 WHERE `name` = 'Iniciación al Desarrollo con IA' AND `issuer` = 'Google / Santander';
UPDATE `certifications` SET `sort_order` = 10 WHERE `name` = 'Domina la IA con Gemini' AND `issuer` = 'Google / Santander';
UPDATE `certifications` SET `sort_order` = 11 WHERE `name` = 'First Certificate in English (B2)' AND `issuer` = 'Cambridge English';
UPDATE `certifications` SET `sort_order` = 12 WHERE `name` = 'IC3 Digital Literacy GS6 Level 1' AND `issuer` = 'Certiport';
UPDATE `certifications` SET `sort_order` = 13 WHERE `name` = 'Python' AND `issuer` = 'OpenBootcamp';
UPDATE `certifications` SET `sort_order` = 14 WHERE `name` = 'Reglas de la IA: cómo usarla sin correr riesgos legales' AND `issuer` = 'LinkedIn';
UPDATE `certifications` SET `sort_order` = 15 WHERE `name` = 'Concienciación en Ciberseguridad: Terminología' AND `issuer` = 'LinkedIn';
UPDATE `certifications` SET `sort_order` = 16 WHERE `name` = 'Fundamentos de Ciberseguridad' AND `issuer` = 'LinkedIn';
UPDATE `certifications` SET `sort_order` = 17 WHERE `name` = 'Panorámica de amenazas a la ciberseguridad' AND `issuer` = 'LinkedIn';

-- 4) Reordenar las de Trend Micro secundarias consecutivamente
SET @new_order := 17;
UPDATE `certifications` 
  SET `sort_order` = (@new_order := @new_order + 1)
  WHERE `issuer` = 'Trend Micro' AND `name` != 'Trend Micro Vision One Platform - Advanced'
  ORDER BY `name` ASC;

-- 5) Ajustar las que queden rezagadas
UPDATE `certifications` SET `sort_order` = 32 WHERE `name` = 'Certificado de Vela - Acceso' AND `issuer` = 'Federació Catalana de Vela';

-- 6) Normalizar el orden general (para limpiar huecos)
SET @r := 0;
UPDATE `certifications` SET `sort_order` = (@r := @r + 1) ORDER BY `sort_order` ASC;
