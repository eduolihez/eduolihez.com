-- ============================================================
--  BadaVeu — Dades de Demostració
--  90 incidències repartides al llarg d'un any (juny 2025 – maig 2026)
--  Barris, districtes, urgències i estats variats de Badalona
--  Executar DESPRÉS de tenir la taula `incidencias` creada.
-- ============================================================

USE `badaveu`;

INSERT INTO `incidencias`
    (`titulo`, `descripcion`, `categoria`, `tipo_problema`, `direccion`, `cp`, `lat`, `lng`, `barri`, `districte`, `urgencia`, `afectacion`, `estado`, `email`, `votos`, `views`, `archivado`, `created_at`, `updated_at`)
VALUES

-- ── JUNY 2025 ──────────────────────────────────────────────────────────────
('Vorera trencada davant escola', 'La vorera del Carrer del Mar davant l\'escola primària té diverses lloses aixecades que suposen un perill per als vianants, especialment per als infants.', 'infraestructura', 'Vorera deteriorada', 'Carrer del Mar, 45', '08911', 41.44521, 2.24731, 'Centre', '1', 'alta', 'col·lectiva', 'resuelto', 'maria.garcia@gmail.com', 34, 120, 0, '2025-06-03 08:15:00', '2025-06-18 10:30:00'),

('Il·luminació deficient al parc', 'El parc de la Salut porta tres setmanes sense llums a la zona de jocs infantils. Les famílies no poden utilitzar-lo de nit.', 'infraestructura', 'Il·luminació deficient', 'Rambla de la Salut, 12', '08911', 41.44802, 2.24215, 'La Salut', '1', 'media', 'col·lectiva', 'resuelto', 'joan.puig@hotmail.com', 28, 95, 0, '2025-06-05 19:42:00', '2025-06-25 14:15:00'),

('Pintades a la façana de l\'ajuntament', 'Aparegudes pintades de gran tamany a la façana lateral de l\'ajuntament durant el cap de setmana. Cal netejar-les.', 'denuncia', 'Pintades i vandalisme', 'Plaça de la Vila, 1', '08911', 41.44680, 2.24512, 'Centre', '1', 'media', 'individual', 'resuelto', NULL, 15, 67, 0, '2025-06-08 09:00:00', '2025-06-14 11:00:00'),

('Contenidor d\'escombraries cremat', 'El contenidor de paper del Carrer Guifré ha estat cremat intencionadament. Fa pudor i és un perill.', 'denuncia', 'Abocament il·legal', 'Carrer Guifré, 23', '08912', 41.45123, 2.23456, 'Llefià', '2', 'alta', 'col·lectiva', 'resuelto', 'anna.soler@gmail.com', 42, 155, 0, '2025-06-10 07:30:00', '2025-06-12 16:45:00'),

('Falta de bancs al passeig', 'El Passeig de Badalona al tram entre el carrer Progrés i el carrer Ponent no té cap banc on descansar. Les persones grans ho necessiten.', 'infraestructura', 'Mobiliari urbà', 'Passeig de Badalona, 78', '08911', 41.44350, 2.24890, 'Centre', '1', 'baja', 'col·lectiva', 'proceso', 'roser.martinez@yahoo.es', 19, 48, 0, '2025-06-15 16:20:00', NULL),

('Sorolls excessius de local nocturn', 'El local de música al carrer Francesc Layret fa soroll fins les 4 del matí tots els caps de setmana. Veïns sense dormir.', 'denuncia', 'Sorolls', 'Carrer Francesc Layret, 56', '08911', 41.44600, 2.24300, 'Centre', '1', 'alta', 'col·lectiva', 'pendiente', 'ferran.vila@gmail.com', 67, 210, 0, '2025-06-20 23:15:00', NULL),

('Fuga d\'aigua al carrer', 'Hi ha una fuga d\'aigua important a la cruïlla del Carrer Gran de Sant Andreu amb el Carrer Industria. L\'aigua porta dies sortint.', 'infraestructura', 'Clavegueram', 'Carrer Gran de Sant Andreu, 102', '08912', 41.45210, 2.23100, 'Llefià', '2', 'alta', 'col·lectiva', 'resuelto', NULL, 51, 178, 0, '2025-06-22 11:00:00', '2025-06-24 09:00:00'),

('Gossos sense corretja al parc', 'Reiteradament es veuen propietaris que deixen els gossos sense corretja al parc infantil on juguen nens. Perill de mossegades.', 'denuncia', 'Animal domèstic', 'Parc de Can Solei, s/n', '08913', 41.46100, 2.22800, 'Montigalà', '5', 'media', 'col·lectiva', 'pendiente', 'laia.font@outlook.com', 23, 89, 0, '2025-06-28 10:30:00', NULL),

-- ── JULIOL 2025 ────────────────────────────────────────────────────────────
('Senyalització de trànsit caiguda', 'El senyal de stop a la cruïlla del Carrer Ponent amb l\'Avinguda Martí Pujol ha caigut i representa un perill greu de trànsit.', 'infraestructura', 'Senyalització', 'Avinguda Martí Pujol, 34', '08911', 41.44450, 2.24650, 'Centre', '1', 'alta', 'col·lectiva', 'resuelto', 'pere.catala@gmail.com', 38, 145, 0, '2025-07-02 08:00:00', '2025-07-04 12:00:00'),

('Escossell d\'arbre deteriorat', 'L\'escossell de l\'arbre davant del número 67 del Carrer Progrés està trencat i les arrels surten, fent malbé la vorera.', 'infraestructura', 'Parcs i jardins', 'Carrer del Progrés, 67', '08911', 41.44720, 2.24580, 'La Salut', '1', 'media', 'individual', 'resuelto', NULL, 12, 44, 0, '2025-07-05 14:30:00', '2025-07-22 10:00:00'),

('Abocament il·legal de runa', 'S\'han abocat runes de construcció en un solar municipal al Carrer Sistrells. El volum és considerable i fa mesos que hi és.', 'denuncia', 'Abocament il·legal', 'Carrer Sistrells, 15', '08915', 41.46500, 2.23200, 'Sistrells', '5', 'media', 'col·lectiva', 'proceso', 'marta.valls@gmail.com', 31, 112, 0, '2025-07-08 09:45:00', NULL),

('Jocs del parc infantil trencats', 'El gronxador i el tobogan del parc de la Morera estan trencats des de fa més d\'un mes. Perill per als infants.', 'infraestructura', 'Parcs i jardins', 'Carrer de la Morera, 5', '08914', 41.45800, 2.23600, 'Morera', '4', 'alta', 'col·lectiva', 'resuelto', 'david.roca@hotmail.com', 55, 198, 0, '2025-07-10 17:00:00', '2025-07-25 09:30:00'),

('Ocupació de via pública per terrassa il·legal', 'Una terrassa de bar al Passeig de Badalona ocupa el doble de l\'espai autoritzat, impedint el pas de vianants i cadires de rodes.', 'denuncia', 'Ocupació de via pública', 'Passeig de Badalona, 145', '08911', 41.44280, 2.25100, 'Centre', '1', 'media', 'col·lectiva', 'pendiente', NULL, 27, 88, 0, '2025-07-14 12:00:00', NULL),

('Semàfor espatllat', 'El semàfor de la cruïlla de l\'Avinguda Martí Pujol amb el Carrer Mar porta 3 dies parpellejant en taronja i de nit s\'apaga del tot.', 'infraestructura', 'Senyalització', 'Avinguda Martí Pujol, 88', '08911', 41.44390, 2.24710, 'Centre', '1', 'alta', 'col·lectiva', 'resuelto', 'silvia.mas@gmail.com', 48, 167, 0, '2025-07-18 07:15:00', '2025-07-20 15:00:00'),

('Plaga de rates al carrer', 'Al vespre es veuen rates al voltant dels contenidors del Carrer Sant Roc. Sembla que hi ha un niu proper.', 'denuncia', 'Incivisme', 'Carrer Sant Roc, 34', '08912', 41.45050, 2.23300, 'Sant Roc', '2', 'alta', 'col·lectiva', 'proceso', 'josep.bosch@gmail.com', 73, 245, 0, '2025-07-22 21:00:00', NULL),

('Banc de jardí trencat', 'El banc de fusta del jardí de la Plaça de la Constitució té dues fustes trencades i els cargols surten. Risc de lesions.', 'infraestructura', 'Mobiliari urbà', 'Plaça de la Constitució, s/n', '08911', 41.44580, 2.24420, 'Centre', '1', 'baja', 'individual', 'resuelto', NULL, 8, 32, 0, '2025-07-25 10:00:00', '2025-08-10 11:00:00'),

-- ── AGOST 2025 ─────────────────────────────────────────────────────────────
('Accés per a persones amb mobilitat reduïda bloquejat', 'La rampa d\'accés a la Biblioteca Municipal del Carrer Guifré està bloquejada per obres sense senyalització alternativa per a persones amb mobilitat reduïda.', 'infraestructura', 'Accessibilitat', 'Carrer Guifré, 78', '08912', 41.45180, 2.23500, 'Llefià', '2', 'alta', 'col·lectiva', 'resuelto', 'cristina.oliver@gmail.com', 44, 156, 0, '2025-08-02 09:30:00', '2025-08-08 14:00:00'),

('Pintades racistes a l\'escola', 'Han aparegut pintades amb contingut racista i ofensiu a la paret exterior de l\'escola del Carrer Pomar.', 'denuncia', 'Pintades i vandalisme', 'Carrer Pomar, 12', '08914', 41.45700, 2.23750, 'Pomar', '4', 'alta', 'individual', 'resuelto', 'amadeu.serra@yahoo.es', 89, 312, 0, '2025-08-05 07:00:00', '2025-08-06 10:30:00'),

('Excés de velocitat al carrer residencial', 'El carrer Bufalà és residencial i limitada a 20 km/h però els vehicles circulen a 60 km/h. Cal un radar o un reductor de velocitat.', 'denuncia', 'Incivisme', 'Carrer Bufalà, 23', '08914', 41.45620, 2.23850, 'Bufalà', '4', 'media', 'col·lectiva', 'proceso', 'lidia.camps@hotmail.com', 56, 189, 0, '2025-08-10 16:45:00', NULL),

('Escocell sense tapa', 'L\'escocell al Carrer Nova Lloreda número 44 no té tapa i representa un perill per a vianants, especialment de nit.', 'infraestructura', 'Vorera deteriorada', 'Carrer Nova Lloreda, 44', '08913', 41.45950, 2.22900, 'Nova Lloreda', '3', 'alta', 'individual', 'resuelto', NULL, 21, 78, 0, '2025-08-12 20:00:00', '2025-08-15 09:00:00'),

('Sorolls de música des d\'habitatge', 'Un veí del quart pis al Carrer Artigas posa música a tot volum des de les 10 del matí fins la mitjanit cada dia.', 'denuncia', 'Sorolls', 'Carrer Artigas, 90', '08913', 41.46050, 2.23050, 'Artigas', '3', 'media', 'individual', 'pendiente', 'pep.lluis@gmail.com', 15, 58, 0, '2025-08-18 22:30:00', NULL),

('Font d\'aigua pública no funciona', 'La font d\'aigua potable del Passeig de Badalona (davant del mercat) porta 2 setmanes avariada. Especialment problemàtic a l\'estiu.', 'infraestructura', 'Mobiliari urbà', 'Passeig de Badalona, 200', '08911', 41.44200, 2.25200, 'Centre', '1', 'media', 'col·lectiva', 'resuelto', 'neus.pi@gmail.com', 33, 119, 0, '2025-08-20 11:15:00', '2025-08-28 10:00:00'),

('Poda d\'arbres necessària', 'Les branques dels plataners del Carrer del Mar han crescut fins a tapar els semàfors i les plaques del carrer. Cal poda urgent.', 'infraestructura', 'Parcs i jardins', 'Carrer del Mar, 120', '08911', 41.44490, 2.24800, 'Centre', '1', 'media', 'col·lectiva', 'proceso', NULL, 18, 65, 0, '2025-08-25 09:00:00', NULL),

('Moto aparcada a la vorera', 'Una moto amb matrícula 1234-ABC porta 3 setmanes aparcada a la vorera del Carrer Ponent, impedint el pas de cadires de rodes.', 'denuncia', 'Ocupació de via pública', 'Carrer Ponent, 67', '08911', 41.44700, 2.24100, 'La Salut', '1', 'baja', 'individual', 'resuelto', 'toni.figueras@gmail.com', 9, 37, 0, '2025-08-28 14:00:00', '2025-09-05 12:00:00'),

-- ── SETEMBRE 2025 ──────────────────────────────────────────────────────────
('Claveguera tapada provoca inundació', 'La claveguera del Carrer Sant Roc número 56 queda tapada cada vegada que plou i inunda els baixos dels edificis colindants.', 'infraestructura', 'Clavegueram', 'Carrer Sant Roc, 56', '08912', 41.45080, 2.23250, 'Sant Roc', '2', 'alta', 'col·lectiva', 'proceso', 'elena.nogues@gmail.com', 62, 224, 0, '2025-09-03 16:30:00', NULL),

('Deixalles al solar municipal', 'El solar municipal del Carrer El Remei s\'utilitza com a abocador informal. Hi ha mobles, electrodomèstics i runa.', 'denuncia', 'Abocament il·legal', 'Carrer El Remei, 8', '08912', 41.44950, 2.23400, 'El Remei', '2', 'media', 'col·lectiva', 'resuelto', 'xavier.duran@yahoo.es', 40, 143, 0, '2025-09-08 10:00:00', '2025-09-20 14:30:00'),

('Farola sense llum', 'La farola del Carrer Canyadó davant de la parada d\'autobús no funciona. La zona queda completament fosca a la nit.', 'infraestructura', 'Il·luminació deficient', 'Carrer Canyadó, 33', '08915', 41.46300, 2.23100, 'Canyadó', '5', 'alta', 'individual', 'resuelto', NULL, 25, 92, 0, '2025-09-12 07:45:00', '2025-09-16 11:00:00'),

('Zona de jocs inundada', 'La zona de jocs del parc de Montigalà s\'inunda cada vegada que plou perquè el desguàs no funciona. Els infants no poden jugar.', 'infraestructura', 'Parcs i jardins', 'Parc de Montigalà, s/n', '08915', 41.46450, 2.23300, 'Montigalà', '5', 'media', 'col·lectiva', 'resuelto', 'irene.comas@hotmail.com', 36, 128, 0, '2025-09-15 09:30:00', '2025-09-30 15:00:00'),

('Contenidors desbordats', 'Els contenidors del Carrer Estrella estan desbordats des de fa dies. L\'escombraries s\'acumula a la vorera i fa pudor.', 'denuncia', 'Incivisme', 'Carrer Estrella, 45', '08916', 41.46800, 2.22600, 'Estrella', '6', 'alta', 'col·lectiva', 'resuelto', 'ramon.vidal@gmail.com', 58, 203, 0, '2025-09-18 08:00:00', '2025-09-20 16:00:00'),

('Obstacles a la rampa de discapacitats', 'Motos i bicicletes aparcades bloquegen sistemàticament la rampa per a persones amb discapacitat al Carrer Pomar.', 'denuncia', 'Ocupació de via pública', 'Carrer Pomar, 34', '08914', 41.45680, 2.23800, 'Pomar', '4', 'media', 'col·lectiva', 'pendiente', 'montse.puigdomenech@gmail.com', 44, 157, 0, '2025-09-22 11:00:00', NULL),

('Vandalisme a la marquesina del bus', 'La marquesina de l\'autobús al Carrer Gran de Sant Andreu ha estat vandalizlada. El vidre trencat representa un perill.', 'denuncia', 'Pintades i vandalisme', 'Carrer Gran de Sant Andreu, 200', '08912', 41.45300, 2.23000, 'Llefià', '2', 'media', 'col·lectiva', 'resuelto', NULL, 22, 81, 0, '2025-09-25 14:15:00', '2025-10-03 10:00:00'),

-- ── OCTUBRE 2025 ───────────────────────────────────────────────────────────
('Esquerdes a la calçada', 'La calçada del Carrer Sistrells presenta esquerdes profundes que han causat ja diverses punxades als vehicles. Perill per a motos.', 'infraestructura', 'Vorera deteriorada', 'Carrer Sistrells, 78', '08915', 41.46520, 2.23150, 'Sistrells', '5', 'alta', 'col·lectiva', 'proceso', 'oriol.jimenez@gmail.com', 47, 168, 0, '2025-10-02 09:00:00', NULL),

('Fuites de gas sospitoses', 'Es nota una olor intensa a gas al soterrani del Carrer Artigas. Varis veïns ho han notat i hi ha por d\'accident.', 'denuncia', 'Incivisme', 'Carrer Artigas, 45', '08913', 41.46000, 2.23100, 'Artigas', '3', 'alta', 'col·lectiva', 'resuelto', 'nuria.esteve@hotmail.com', 93, 342, 0, '2025-10-05 23:00:00', '2025-10-06 08:00:00'),

('Porta de l\'escola trencada', 'La porta d\'entrada principal de l\'escola bressol del Carrer La Pau no tanca bé des de fa dues setmanes. Perill per a la seguretat.', 'infraestructura', 'Mobiliari urbà', 'Carrer La Pau, 12', '08913', 41.45900, 2.22950, 'La Pau', '3', 'alta', 'individual', 'resuelto', 'paula.ferrer@gmail.com', 30, 108, 0, '2025-10-08 07:30:00', '2025-10-10 16:00:00'),

('Arbres caiguts bloquegen el pas', 'Una tempesta ha tirat dos arbres del Carrer Coll i Pujol que bloquegen parcialment la calçada. Perill per a vehicles.', 'infraestructura', 'Parcs i jardins', 'Carrer Coll i Pujol, 23', '08911', 41.44650, 2.24350, 'Coll i Pujol', '1', 'alta', 'col·lectiva', 'resuelto', NULL, 71, 256, 0, '2025-10-12 06:00:00', '2025-10-12 14:00:00'),

('Rètol de carrer desaparegut', 'La placa del Carrer Nova Lloreda cantonada amb el Carrer Artigas ha desaparegut. Crea confusió als serveis d\'emergència.', 'infraestructura', 'Senyalització', 'Carrer Nova Lloreda, 1', '08913', 41.45980, 2.22850, 'Nova Lloreda', '3', 'baja', 'col·lectiva', 'resuelto', 'carles.badia@gmail.com', 14, 52, 0, '2025-10-15 10:30:00', '2025-10-28 09:00:00'),

('Abocament de residus perillosos', 'S\'han trobat bidons amb líquids desconeguts i possblement perillosos abocats al solar del Carrer El Remei. Cal anàlisi urgent.', 'denuncia', 'Abocament il·legal', 'Carrer El Remei, 25', '08912', 41.44980, 2.23380, 'El Remei', '2', 'alta', 'col·lectiva', 'resuelto', 'sonia.gomez@gmail.com', 85, 298, 0, '2025-10-18 11:00:00', '2025-10-20 13:00:00'),

('Barana de pont en mal estat', 'La barana del pont sobre la Riera de Canyadó té barrots solts. Una persona podria caure al buit.', 'infraestructura', 'Vorera deteriorada', 'Pont de Canyadó, s/n', '08915', 41.46380, 2.23050, 'Canyadó', '5', 'alta', 'col·lectiva', 'proceso', 'gemma.tort@yahoo.es', 52, 187, 0, '2025-10-22 15:00:00', NULL),

('Sorolls d\'obra fora d\'horari', 'Obres d\'un edifici al Carrer Morera fan soroll des de les 7 del matí fins les 10 de la nit incloent dissabtes i diumenges.', 'denuncia', 'Sorolls', 'Carrer de la Morera, 45', '08914', 41.45820, 2.23580, 'Morera', '4', 'media', 'col·lectiva', 'pendiente', 'alicia.hernandez@hotmail.com', 38, 135, 0, '2025-10-28 07:05:00', NULL),

-- ── NOVEMBRE 2025 ──────────────────────────────────────────────────────────
('Senyal de trànsit vandalizat', 'El senyal de "Zona Escolar" al Carrer Bufalà ha estat pintarrajat fent-lo il·legible. Perill en hora d\'entrada i sortida.', 'denuncia', 'Pintades i vandalisme', 'Carrer Bufalà, 67', '08914', 41.45640, 2.23820, 'Bufalà', '4', 'alta', 'individual', 'resuelto', NULL, 29, 104, 0, '2025-11-03 08:15:00', '2025-11-08 11:30:00'),

('Tapa de claveguera perillosa', 'La tapa de claveguera del Carrer Mar cantonada Carrer Sol sobresurt 5 cm del terra. Ja ha provocat una caiguda d\'una persona gran.', 'infraestructura', 'Clavegueram', 'Carrer del Mar, 234', '08911', 41.44530, 2.24760, 'Centre', '1', 'alta', 'individual', 'resuelto', 'albert.prats@gmail.com', 47, 169, 0, '2025-11-06 10:00:00', '2025-11-10 15:00:00'),

('Zona verda convertida en aparcament', 'La zona verda del Carrer Coll i Pujol sistemàticament s\'utilitza per aparcar vehicles. La gespa i les plantes estan destruïdes.', 'denuncia', 'Ocupació de via pública', 'Carrer Coll i Pujol, 45', '08911', 41.44670, 2.24330, 'Coll i Pujol', '1', 'baja', 'col·lectiva', 'pendiente', 'rosa.compte@gmail.com', 21, 76, 0, '2025-11-10 14:30:00', NULL),

('Pals de llum inclinats', 'Tres pals de llum consecutius al Carrer Estrella estan fortament inclinats. Podrien caure amb vent fort.', 'infraestructura', 'Il·luminació deficient', 'Carrer Estrella, 112', '08916', 41.46820, 2.22550, 'Estrella', '6', 'alta', 'col·lectiva', 'proceso', 'mireia.casas@hotmail.com', 63, 228, 0, '2025-11-14 09:45:00', NULL),

('Graffiti al monument', 'El monument als veterans de la plaça del Barri ha estat vandalizat amb pintures en aerosol. Patrimoni danyat.', 'denuncia', 'Pintades i vandalisme', 'Plaça del Barri, s/n', '08913', 41.45970, 2.22920, 'Nova Lloreda', '3', 'media', 'col·lectiva', 'resuelto', NULL, 32, 117, 0, '2025-11-18 08:00:00', '2025-11-25 14:00:00'),

('Falta de contenidor de vidre', 'Al Carrer Sistrells, tram entre els números 30 i 90, no hi ha cap contenidor de vidre. La gent aboca el vidre als altres contenidors.', 'infraestructura', 'Mobiliari urbà', 'Carrer Sistrells, 60', '08915', 41.46540, 2.23120, 'Sistrells', '5', 'baja', 'col·lectiva', 'pendiente', 'jaume.vilagrasa@gmail.com', 17, 62, 0, '2025-11-22 11:00:00', NULL),

('Gat ferit abandonat al carrer', 'Hi ha un gat aparentment ferit a la vorera del Carrer Artigas. Porta hores sense moure\'s.', 'denuncia', 'Animal domèstic', 'Carrer Artigas, 120', '08913', 41.46080, 2.23020, 'Artigas', '3', 'media', 'individual', 'resuelto', 'mercè.albà@gmail.com', 11, 43, 0, '2025-11-26 16:00:00', '2025-11-26 20:00:00'),

('Vorera massa estreta per a cotxes d\'infants', 'Al Carrer Pomar el pas lliure de la vorera és inferior a 90 cm per culpa de les terrasses de bars. Les persones amb cotxe d\'infant no poden passar.', 'infraestructura', 'Accessibilitat', 'Carrer Pomar, 78', '08914', 41.45720, 2.23720, 'Pomar', '4', 'media', 'col·lectiva', 'proceso', 'berta.plana@yahoo.es', 26, 95, 0, '2025-11-29 10:15:00', NULL),

-- ── DESEMBRE 2025 ──────────────────────────────────────────────────────────
('Il·luminació nadalenca espatllada', 'La meitat de la il·luminació nadalenca del Passeig de Badalona no funciona des del primer dia d\'instal·lació. La zona queda molt fosca.', 'infraestructura', 'Il·luminació deficient', 'Passeig de Badalona, 88', '08911', 41.44310, 2.25050, 'Centre', '1', 'baja', 'col·lectiva', 'resuelto', 'jordi.mas@gmail.com', 20, 74, 0, '2025-12-02 18:00:00', '2025-12-05 10:00:00'),

('Caiguda d\'una branca grossa', 'Una branca de gran tamany ha caigut al Carrer Montigalà i ha danyat dos vehicles aparcats. Cal talar l\'arbre abans que caigui el tronc.', 'infraestructura', 'Parcs i jardins', 'Carrer Montigalà, 34', '08915', 41.46420, 2.23350, 'Montigalà', '5', 'alta', 'col·lectiva', 'resuelto', 'carme.angles@hotmail.com', 55, 197, 0, '2025-12-05 09:00:00', '2025-12-07 14:00:00'),

('Botellot als jardins', 'Cada cap de setmana es fan botellots als jardins del Carrer Canyadó amb molt soroll i deixant ampolles trencades a terra. Perill per als nens.', 'denuncia', 'Incivisme', 'Jardins del Carrer Canyadó, s/n', '08915', 41.46320, 2.23080, 'Canyadó', '5', 'alta', 'col·lectiva', 'pendiente', 'antonio.ruiz@gmail.com', 78, 281, 0, '2025-12-08 09:00:00', NULL),

('Escales sense il·luminació', 'Les escales públiques del Carrer Estrella que pugen cap al parc estan completament fosques a la nit. Risc de caigudes.', 'infraestructura', 'Il·luminació deficient', 'Carrer Estrella, 200', '08916', 41.46850, 2.22500, 'Estrella', '6', 'alta', 'individual', 'resuelto', NULL, 34, 123, 0, '2025-12-12 20:00:00', '2025-12-18 09:00:00'),

('Fuita de gas del sistema de calefacció', 'Olor a gas al Carrer del Mar 78, a la planta baixa. Probable fuita a la instal·lació de calefacció de l\'edifici.', 'infraestructura', 'Clavegueram', 'Carrer del Mar, 78', '08911', 41.44510, 2.24710, 'Centre', '1', 'alta', 'col·lectiva', 'resuelto', 'ingrid.sole@gmail.com', 67, 243, 0, '2025-12-15 14:00:00', '2025-12-15 17:00:00'),

('Rètols del mercat desactualitzats', 'Els rètols d\'horaris del Mercat Municipal del Carrer Guifré mostren horaris antics i confonen els clients.', 'infraestructura', 'Senyalització', 'Carrer Guifré, 100', '08912', 41.45200, 2.23480, 'Llefià', '2', 'baja', 'col·lectiva', 'pendiente', 'eli.garcia@hotmail.com', 6, 25, 0, '2025-12-19 11:30:00', NULL),

('Contaminació acústica per trànsit', 'L\'increment de trànsit al Carrer Gran de Sant Andreu durant les obres del metro fa que el soroll sigui insuportable dia i nit.', 'denuncia', 'Sorolls', 'Carrer Gran de Sant Andreu, 150', '08912', 41.45250, 2.23050, 'Llefià', '2', 'media', 'col·lectiva', 'proceso', 'lluis.ventura@gmail.com', 49, 178, 0, '2025-12-23 08:00:00', NULL),

-- ── GENER 2026 ─────────────────────────────────────────────────────────────
('Vorera gelada i perillosa', 'La vorera del Carrer Morera davant del supermercat és gelada cada matí i ja han caigut dos persones grans aquesta setmana.', 'infraestructura', 'Vorera deteriorada', 'Carrer de la Morera, 89', '08914', 41.45840, 2.23560, 'Morera', '4', 'alta', 'col·lectiva', 'resuelto', 'teresa.font@gmail.com', 41, 149, 0, '2026-01-05 08:30:00', '2026-01-07 11:00:00'),

('Contenidors sense rodes', 'Tres contenidors de rebuig al Carrer Bufalà han perdut les rodes i no es poden moure per a la recollida. L\'escombraries no es recull bé.', 'infraestructura', 'Mobiliari urbà', 'Carrer Bufalà, 45', '08914', 41.45630, 2.23840, 'Bufalà', '4', 'media', 'col·lectiva', 'resuelto', NULL, 19, 70, 0, '2026-01-08 09:00:00', '2026-01-15 14:00:00'),

('Gossos solts a la platja', 'Malgrat la prohibició, propietaris porten els seus gossos a la platja de Badalona sense corretja durant hores punta.', 'denuncia', 'Animal domèstic', 'Platja de Badalona, s/n', '08911', 41.44100, 2.25400, 'Centre', '1', 'baja', 'col·lectiva', 'pendiente', 'susana.molist@yahoo.es', 13, 49, 0, '2026-01-12 10:00:00', NULL),

('Esquerdes als sostres del mercat cobert', 'El sostre del mercat cobert del Carrer Artigas presenta esquerdes importants. Fragments de ciment cauen a les parades.', 'infraestructura', 'Vorera deteriorada', 'Mercat del Carrer Artigas, s/n', '08913', 41.46020, 2.23080, 'Artigas', '3', 'alta', 'col·lectiva', 'proceso', 'oscar.ferrer@gmail.com', 88, 319, 0, '2026-01-15 07:00:00', NULL),

('Nevera abandonada al carrer', 'Una nevera gran ha estat abandonada al carrer Coll i Pujol fa 10 dies. Ocupa la vorera i no passa el servei de recollida de grans residus.', 'denuncia', 'Abocament il·legal', 'Carrer Coll i Pujol, 89', '08911', 41.44680, 2.24300, 'Coll i Pujol', '1', 'media', 'individual', 'resuelto', 'eva.sabate@gmail.com', 7, 28, 0, '2026-01-19 11:00:00', '2026-01-22 15:00:00'),

('Baixada d\'aigüa sense coberta', 'La baixada d\'aigüa del Carrer El Remei ha perdut la coberta i es veu el tub directament. Perill i mala imatge.', 'infraestructura', 'Clavegueram', 'Carrer El Remei, 67', '08912', 41.44960, 2.23420, 'El Remei', '2', 'baja', 'individual', 'pendiente', NULL, 5, 21, 0, '2026-01-23 14:30:00', NULL),

('Pintades xenòfobes al carrer', 'Pintades amb missatges xenòfobs aparegudes a les parets del Carrer Sant Roc. Creen malestar entre els veïns.', 'denuncia', 'Pintades i vandalisme', 'Carrer Sant Roc, 78', '08912', 41.45060, 2.23280, 'Sant Roc', '2', 'alta', 'col·lectiva', 'resuelto', 'gemma.sala@hotmail.com', 76, 274, 0, '2026-01-27 07:30:00', '2026-01-29 10:00:00'),

('Farola apagada davant del CAP', 'La farola exterior del CAP del Carrer Canyadó porta una setmana apagada. Els pacients que surten de nit no veuen bé on van.', 'infraestructura', 'Il·luminació deficient', 'Carrer Canyadó, 89', '08915', 41.46350, 2.23130, 'Canyadó', '5', 'alta', 'individual', 'proceso', 'pilar.mola@gmail.com', 35, 127, 0, '2026-01-30 07:00:00', NULL),

-- ── FEBRER 2026 ────────────────────────────────────────────────────────────
('Runa acumulada al solar', 'Al solar del Carrer Montigalà hi ha molta runa acumulada que sembla provenir d\'obres particulars. Risc de plagues.', 'denuncia', 'Abocament il·legal', 'Carrer Montigalà, 78', '08915', 41.46440, 2.23330, 'Montigalà', '5', 'media', 'col·lectiva', 'resuelto', 'jaume.boix@gmail.com', 28, 101, 0, '2026-02-03 09:30:00', '2026-02-14 12:00:00'),

('Banc del parc incendiat', 'El banc de fusta del parc infantil del Carrer La Pau ha estat incendiat intencionadament. Resta carbonitzat i perillós.', 'denuncia', 'Pintades i vandalisme', 'Carrer La Pau, 56', '08913', 41.45920, 2.22970, 'La Pau', '3', 'alta', 'col·lectiva', 'resuelto', 'rita.puig@yahoo.es', 45, 163, 0, '2026-02-07 06:30:00', '2026-02-10 15:00:00'),

('Dificultat d\'accés al metro', 'L\'ascensor de l\'estació de metro del Carrer Gran de Sant Andreu porta dues setmanes avariat. Les persones amb mobilitat reduïda han de fer una volta de 800 metres.', 'infraestructura', 'Accessibilitat', 'Estació Metro Gran de Sant Andreu', '08912', 41.45270, 2.23020, 'Llefià', '2', 'alta', 'col·lectiva', 'proceso', 'marc.gimenez@gmail.com', 97, 352, 0, '2026-02-10 08:00:00', NULL),

('Soroll de bar fins les 5 del matí', 'Un bar del Carrer Pomar no tanca fins les 5 del matí tots els divendres i dissabtes. La música es sent a tot el carrer.', 'denuncia', 'Sorolls', 'Carrer Pomar, 56', '08914', 41.45700, 2.23760, 'Pomar', '4', 'alta', 'col·lectiva', 'pendiente', 'ana.garcia@hotmail.com', 83, 301, 0, '2026-02-14 04:00:00', NULL),

('Vorera inexistent als afores', 'Al Carrer Sistrells, entre els números 150 i 200, no hi ha vorera i els vianants han de caminar per la calçada amb el risc que implica.', 'infraestructura', 'Vorera deteriorada', 'Carrer Sistrells, 175', '08915', 41.46560, 2.23090, 'Sistrells', '5', 'media', 'col·lectiva', 'proceso', NULL, 31, 113, 0, '2026-02-18 10:30:00', NULL),

('Niu de cotorres als cables elèctrics', 'Un gran niu de cotorres als cables elèctrics del Carrer Estrella provoca talls de llum puntuals i fa molt soroll.', 'infraestructura', 'Parcs i jardins', 'Carrer Estrella, 167', '08916', 41.46830, 2.22520, 'Estrella', '6', 'baja', 'col·lectiva', 'resuelto', 'pau.ferrer@gmail.com', 16, 59, 0, '2026-02-22 09:00:00', '2026-03-08 11:00:00'),

('Buit a la calçada', 'Un buit considerable ha aparegut a la calçada del Carrer Bufalà. Podria enfonsar-se amb el pas de vehicles pesats.', 'infraestructura', 'Vorera deteriorada', 'Carrer Bufalà, 100', '08914', 41.45650, 2.23810, 'Bufalà', '4', 'alta', 'col·lectiva', 'resuelto', 'laura.font@gmail.com', 61, 221, 0, '2026-02-25 11:15:00', '2026-02-27 14:00:00'),

-- ── MARÇ 2026 ──────────────────────────────────────────────────────────────
('Manca de senyalització al carril bici', 'El carril bici del Passeig de Badalona no té senyalització clara als creuaments i provoca conflictes entre bicicletes i vianants.', 'infraestructura', 'Senyalització', 'Passeig de Badalona, 300', '08911', 41.44150, 2.25300, 'Centre', '1', 'media', 'col·lectiva', 'pendiente', 'victor.morera@gmail.com', 39, 141, 0, '2026-03-02 10:00:00', NULL),

('Abocament d\'oli de motor', 'S\'ha abocat oli de motor a la vorera del Carrer Coll i Pujol, creant una taca relliscosa i perillosa per als vianants.', 'denuncia', 'Abocament il·legal', 'Carrer Coll i Pujol, 130', '08911', 41.44700, 2.24270, 'Coll i Pujol', '1', 'alta', 'individual', 'resuelto', 'irma.basora@hotmail.com', 24, 88, 0, '2026-03-05 08:30:00', '2026-03-07 12:00:00'),

('Canonada d\'aigüa trencada', 'Una canonada d\'aigüa ha esclatat al Carrer El Remei i l\'aigüa inunda la calçada i part dels habitatges de planta baixa.', 'infraestructura', 'Clavegueram', 'Carrer El Remei, 100', '08912', 41.44990, 2.23350, 'El Remei', '2', 'alta', 'col·lectiva', 'resuelto', 'alex.compte@gmail.com', 72, 262, 0, '2026-03-08 05:30:00', '2026-03-08 11:00:00'),

('Mobiliari urbà obsolet a la plaça', 'El mobiliari de la Plaça de la Constitució (bancs, papereres, jocs) és molt antic i deteriorat. Cal una renovació urgent.', 'infraestructura', 'Mobiliari urbà', 'Plaça de la Constitució, s/n', '08911', 41.44560, 2.24440, 'Centre', '1', 'media', 'col·lectiva', 'proceso', 'alba.casado@gmail.com', 33, 120, 0, '2026-03-12 11:00:00', NULL),

('Cotxes mal aparcats bloquegen sortida d\'emergència', 'Vehicles aparcats davant de l\'entrada d\'emergència de l\'hospital del Carrer Montigalà impedeixen l\'accés als serveis d\'urgència.', 'denuncia', 'Ocupació de via pública', 'Carrer Montigalà, 200', '08915', 41.46480, 2.23280, 'Montigalà', '5', 'alta', 'col·lectiva', 'proceso', 'natalia.bou@yahoo.es', 91, 334, 0, '2026-03-15 09:00:00', NULL),

('Soroll de camions de repartiment', 'Camions de repartiment al Carrer Artigas fan maniobres i sona la marxa enrere des de les 6 del matí. Veïns despertats cada dia.', 'denuncia', 'Sorolls', 'Carrer Artigas, 200', '08913', 41.46100, 2.22990, 'Artigas', '3', 'media', 'col·lectiva', 'pendiente', 'david.riera@gmail.com', 42, 153, 0, '2026-03-19 06:30:00', NULL),

('Zona de jocs sense sorra', 'La zona de jocs infantils del Carrer Canyadó no té sorra i el terra dur representa risc de lesions greus per caigudes.', 'infraestructura', 'Parcs i jardins', 'Carrer Canyadó, 150', '08915', 41.46310, 2.23160, 'Canyadó', '5', 'media', 'col·lectiva', 'resuelto', 'claudia.mas@hotmail.com', 27, 98, 0, '2026-03-22 10:00:00', '2026-04-05 14:00:00'),

('Pisos turístics amb soroll excessiu', 'Varis pisos del Carrer Passeig de Badalona s\'utilitzen com a pisos turístics il·legals amb festes cada cap de setmana fins l\'alba.', 'denuncia', 'Sorolls', 'Passeig de Badalona, 56', '08911', 41.44320, 2.24980, 'Centre', '1', 'alta', 'col·lectiva', 'pendiente', 'enric.torres@gmail.com', 68, 247, 0, '2026-03-26 01:00:00', NULL),

-- ── ABRIL 2026 ─────────────────────────────────────────────────────────────
('Accés blocat per obres sense senyalització', 'Les obres al Carrer Progrés no disposen de senyalització correcta i els vianants no saben com accedir als establiments.', 'infraestructura', 'Accessibilitat', 'Carrer del Progrés, 120', '08911', 41.44750, 2.24560, 'La Salut', '1', 'media', 'col·lectiva', 'resuelto', 'beatriz.llop@gmail.com', 22, 81, 0, '2026-04-02 09:00:00', '2026-04-15 12:00:00'),

('Pintades a la nova escultura', 'L\'escultura recentment instal·lada a la Plaça de la Salut ha estat vandalizlada amb sprais de colors. Només porta una setmana.', 'denuncia', 'Pintades i vandalisme', 'Plaça de la Salut, s/n', '08911', 41.44820, 2.24190, 'La Salut', '1', 'alta', 'col·lectiva', 'pendiente', NULL, 53, 191, 0, '2026-04-06 07:00:00', NULL),

('Falta paperera reciclatge orgànic', 'Al Carrer Sant Mori de Llefià no hi ha cap contenidor de matèria orgànica. La gent ha de caminar 500 metres per a reciclar.', 'infraestructura', 'Mobiliari urbà', 'Carrer Sant Mori de Llefià, 34', '08916', 41.46700, 2.22700, 'Sant Mori de Llefià', '6', 'baja', 'col·lectiva', 'pendiente', 'helena.roig@gmail.com', 11, 42, 0, '2026-04-09 10:30:00', NULL),

('Vehicles abandonats al carrer', 'Dos turismes sense matrícula ni ITV estan aparcats al Carrer Morera fa més d\'un mes. Probable abandonament.', 'denuncia', 'Ocupació de via pública', 'Carrer de la Morera, 112', '08914', 41.45860, 2.23540, 'Morera', '4', 'media', 'col·lectiva', 'resuelto', 'ivan.calvo@hotmail.com', 18, 66, 0, '2026-04-12 11:00:00', '2026-04-24 15:00:00'),

('Erosió del terreny al parc', 'La pluja intensa ha creat una important erosió al terreny del parc del Barri, deixant la xarxa de rec al descobert.', 'infraestructura', 'Parcs i jardins', 'Parc del Barri de Nova Lloreda', '08913', 41.45990, 2.22910, 'Nova Lloreda', '3', 'media', 'col·lectiva', 'proceso', 'julia.badia@gmail.com', 25, 92, 0, '2026-04-16 09:30:00', NULL),

('Caça il·legal d\'ocells', 'S\'ha detectat una persona posant paranys per a ocells al parc de Montigalà. Activitat il·legal i cruel.', 'denuncia', 'Animal domèstic', 'Parc de Montigalà, sector nord', '08915', 41.46470, 2.23310, 'Montigalà', '5', 'alta', 'individual', 'resuelto', 'ariadna.figueres@gmail.com', 64, 233, 0, '2026-04-19 08:00:00', '2026-04-22 14:00:00'),

('Tanca d\'obra caiguda', 'La tanca que delimita les obres del Carrer Bufalà ha caigut i els vianants entren a la zona d\'obres sense saber-ho.', 'infraestructura', 'Senyalització', 'Carrer Bufalà, 156', '08914', 41.45660, 2.23800, 'Bufalà', '4', 'alta', 'col·lectiva', 'resuelto', 'sergi.martos@gmail.com', 39, 143, 0, '2026-04-23 07:15:00', '2026-04-24 09:00:00'),

('Mosquits al dipòsit d\'aigüa', 'El dipòsit d\'aigüa pluvial del parc del Carrer Pomar té larves de mosquit. Cal tractar-lo abans que s\'estengui la plaga.', 'denuncia', 'Incivisme', 'Parc del Carrer Pomar, s/n', '08914', 41.45740, 2.23730, 'Pomar', '4', 'media', 'col·lectiva', 'pendiente', 'joel.llach@hotmail.com', 30, 109, 0, '2026-04-27 10:00:00', NULL),

-- ── MAIG 2026 ──────────────────────────────────────────────────────────────
('Vorera nova ja trencada', 'La vorera que van reformar al Carrer Canyadó fa dos mesos ja presenta esquerdes i lloses movedisses. Mala execució de l\'obra.', 'infraestructura', 'Vorera deteriorada', 'Carrer Canyadó, 200', '08915', 41.46340, 2.23110, 'Canyadó', '5', 'alta', 'col·lectiva', 'pendiente', 'miriam.bernet@gmail.com', 57, 207, 0, '2026-05-01 09:00:00', NULL),

('Robatori de cobertes de sots', 'Han robat les tapes metàl·liques de sots al Carrer La Pau, deixant forats perillosos a la calçada.', 'denuncia', 'Incivisme', 'Carrer La Pau, 89', '08913', 41.45940, 2.22940, 'La Pau', '3', 'alta', 'col·lectiva', 'proceso', 'neus.armengol@gmail.com', 86, 315, 0, '2026-05-02 07:00:00', NULL),

('Piscina municipal amb fuites', 'La piscina municipal del Carrer Sant Roc presenta fuites importants. El nivell de l\'aigüa baixa visiblement cada dia.', 'infraestructura', 'Clavegueram', 'Carrer Sant Roc, 120', '08912', 41.45100, 2.23220, 'Sant Roc', '2', 'alta', 'col·lectiva', 'pendiente', 'ester.casas@yahoo.es', 44, 161, 0, '2026-05-03 08:30:00', NULL),

('Accés per a cadires de rodes sense rampa', 'La biblioteca pública del Carrer Artigas no disposa de rampa d\'accés per a persones en cadires de rodes. Barreres arquitectòniques.', 'infraestructura', 'Accessibilitat', 'Carrer Artigas, 250', '08913', 41.46120, 2.22960, 'Artigas', '3', 'alta', 'col·lectiva', 'pendiente', 'dolors.vives@gmail.com', 73, 267, 0, '2026-05-04 10:00:00', NULL),

('Fonts del parc sense manteniment', 'Les fonts ornamentals del parc de Montigalà estan verdes i fan pudor. Sembla que fa mesos que no es netegen.', 'infraestructura', 'Parcs i jardins', 'Parc de Montigalà, entrada principal', '08915', 41.46460, 2.23290, 'Montigalà', '5', 'baja', 'col·lectiva', 'pendiente', NULL, 14, 52, 0, '2026-05-05 11:00:00', NULL);

-- ============================================================
--  HISTORIAL per a les incidències resoltes (selecció)
--  Genera un registre de canvi d'estat per a les resoltes
-- ============================================================

INSERT INTO `historial_incidencias`
    (`incidencia_id`, `estado_anterior`, `estado_nuevo`, `comentario_admin`, `admin_usuario`, `fecha`)
SELECT
    i.id,
    'pendiente',
    'resuelto',
    CASE
        WHEN i.urgencia = 'alta'  THEN 'Incidència atesa amb prioritat. Problema resolt satisfactòriament.'
        WHEN i.urgencia = 'media' THEN 'Actuació realitzada. La incidència ha estat resolta.'
        ELSE 'Incidència resolta. Gràcies per la vostra col·laboració ciutadana.'
    END,
    CASE (i.id % 3)
        WHEN 0 THEN 'admin@badaveu.cat'
        WHEN 1 THEN 'gestor1@badaveu.cat'
        ELSE 'gestor2@badaveu.cat'
    END,
    DATE_ADD(i.updated_at, INTERVAL -1 HOUR)
FROM incidencias i
WHERE i.estado = 'resuelto' AND i.updated_at IS NOT NULL;

INSERT INTO `historial_incidencias`
    (`incidencia_id`, `estado_anterior`, `estado_nuevo`, `comentario_admin`, `admin_usuario`, `fecha`)
SELECT
    i.id,
    'pendiente',
    'proceso',
    'Incidència recollida i assignada al departament corresponent. En procés de resolució.',
    CASE (i.id % 2)
        WHEN 0 THEN 'admin@badaveu.cat'
        ELSE 'gestor1@badaveu.cat'
    END,
    DATE_ADD(i.created_at, INTERVAL 2 DAY)
FROM incidencias i
WHERE i.estado = 'proceso';

-- ============================================================
--  Resum d'inserció
-- ============================================================
SELECT
    COUNT(*) AS total_incidencies,
    SUM(estado = 'pendiente') AS pendents,
    SUM(estado = 'proceso')   AS en_proces,
    SUM(estado = 'resuelto')  AS resoltes,
    SUM(urgencia = 'alta')    AS urgencia_alta,
    SUM(urgencia = 'media')   AS urgencia_media,
    SUM(urgencia = 'baja')    AS urgencia_baixa,
    SUM(categoria = 'infraestructura') AS infraestructura,
    SUM(categoria = 'denuncia')        AS denuncia
FROM incidencias;
