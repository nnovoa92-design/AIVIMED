-- ============================================================
-- Catálogo real AIVIMED: categorías, servicios, descripciones y precios
-- Ejecutar en el SQL Editor de Supabase (schema bienestar)
-- No borra nada existente: desactiva el catálogo placeholder
-- y agrega las categorías/servicios reales.
-- ============================================================
set search_path to bienestar;

-- Desactivar catálogo placeholder anterior (no se borra, queda en histórico)
update servicios set activo = false;

-- ------------------------------------------------------------
-- Categorías reales
-- ------------------------------------------------------------
insert into categorias_servicios (nombre, orden) values
  ('Estética Avanzada y Regenerativa', 1),
  ('Estética y Cuidado Facial', 2),
  ('Depilación Láser', 3),
  ('Bienestar y Enfermería', 4),
  ('Nutrición', 5)
on conflict (nombre) do nothing;

-- ------------------------------------------------------------
-- I. ESTÉTICA AVANZADA Y REGENERATIVA
-- ------------------------------------------------------------
insert into servicios (categoria_id, nombre, descripcion, precio, requiere_consentimiento)
select c.id, s.nombre, s.descripcion, s.precio::numeric, s.req::boolean
from (values
  ('Sueroterapia - Pack 1 (Vegan + 5HTP + Oligoelementos)',
   'Administración endovenosa de vitaminas, minerales, antioxidantes y aminoácidos seleccionados según necesidades del paciente. Apoya funciones metabólicas, hidratación y bienestar integral. Previa evaluación clínica y técnica estéril.',
   69990, true),
  ('Sueroterapia - Pack 2 Antienvejecimiento (Glutatión + Vitamina C)',
   'Medicina ortomolecular orientada a antienvejecimiento. Administración endovenosa bajo protocolo clínico, control de signos vitales y registro.',
   59990, true),
  ('Sueroterapia - Pack 3 Antiobesidad / Plan Verano (Complejo B + Vit. C + Sulfato de Magnesio + Veganactina Complex)',
   'Pack orientado a apoyo metabólico y reducción de adiposidad. Administración endovenosa bajo evaluación previa y técnica estéril.',
   119990, true),
  ('Sueroterapia - Pack 4 Energizante (Vit. C + Glutatión + Complejo B + Sulfato de Magnesio + Oligocomplex + Carnacin Plus)',
   'Pack energizante para disminuir fatiga física y mental. Administración endovenosa bajo protocolo clínico y control de signos vitales.',
   119990, true),
  ('Sueroterapia - Pack 5 (Vitamina C + Oligocomplex)',
   'Pack de hidratación y antioxidantes. Administración endovenosa bajo evaluación previa y técnica estéril.',
   59990, true),
  ('Plasma Rico en Plaquetas (PRP) + Vitamina C',
   'Tratamiento autólogo: obtención de muestra de sangre venosa, centrifugación para concentrar plaquetas y aplicación facial, capilar o corporal con fines regenerativos. Estimula colágeno y reparación tisular. Bajo asepsia, técnica estéril y consentimiento informado.',
   74990, true),
  ('Mesoterapia',
   'Microinyecciones intradérmicas de principios activos, vitaminas, minerales o fármacos para mejorar la calidad de la piel y revitalizar tejidos. Técnica controlada, profundidad y dosis según protocolo.',
   null, true),
  ('Bioestimuladores de Colágeno',
   'Aplicación de sustancias biocompatibles para estimular la producción natural de colágeno. Mejora firmeza, elasticidad y densidad cutánea de forma progresiva. Evaluación clínica previa y técnica estéril.',
   null, true),
  ('Hidrolipoclasia',
   'Procedimiento no quirúrgico de reducción de adiposidad localizada y remodelación corporal mediante infiltración controlada y activación mecánica. Evaluación previa y técnica estéril.',
   null, true),
  ('Hilos Revitalizantes',
   'Técnica mínimamente invasiva con hilos reabsorbibles para estimular colágeno y aportar efecto tensor progresivo. Técnica estéril y evaluación previa.',
   null, true),
  ('Aplicación de Toxina Botulínica',
   'Disminución de líneas de expresión dinámicas mediante relajación controlada de grupos musculares específicos. Evaluación clínica, dosificación y consentimiento informado.',
   null, true),
  ('Rellenos Dérmicos',
   'Materiales biocompatibles para restaurar volumen, suavizar surcos y mejorar contornos faciales. Evaluación previa, técnica estéril y registro clínico.',
   null, true),
  ('Rinomodelación',
   'Procedimiento no quirúrgico para mejorar forma, proyección y perfil nasal mediante técnicas de relleno. Evaluación previa y protocolos clínicos establecidos.',
   null, true),
  ('Armonización Facial',
   'Conjunto de procedimientos estéticos para equilibrar proporciones del rostro y realzar rasgos faciales con resultado natural. Evaluación integral y planificación personalizada.',
   null, true)
) as s(nombre, descripcion, precio, req)
join categorias_servicios c on c.nombre = 'Estética Avanzada y Regenerativa'
on conflict do nothing;

-- ------------------------------------------------------------
-- II. ESTÉTICA Y CUIDADO FACIAL
-- ------------------------------------------------------------
insert into servicios (categoria_id, nombre, descripcion, precio, requiere_consentimiento)
select c.id, s.nombre, s.descripcion, s.precio::numeric, s.req::boolean
from (values
  ('Pink Glow + Limpieza Facial Simple',
   'Procedimiento facial orientado a mejorar luminosidad, hidratación y vitalidad de la piel. Combina activos específicos con limpieza facial simple. Evaluación previa del tipo de piel.',
   79990, false),
  ('Pink Glow + Limpieza Facial Simple (paquete x3 sesiones)',
   'Mismo procedimiento que Pink Glow + Limpieza Facial Simple, en paquete de 3 sesiones.',
   119990, false),
  ('Dermapen',
   'Micropunción controlada que estimula la regeneración natural de la piel mediante microcanales. Mejora textura, firmeza, cicatrices, poros y líneas finas. Dispositivos certificados y técnica estéril.',
   null, false),
  ('BB Glow',
   'Aplicación superficial de principios activos cosméticos para mejorar tono, luminosidad e hidratación de la piel. Técnica profesional y productos certificados.',
   null, false),
  ('BB Lips',
   'Hidratación profunda y revitalización de labios, mejora del color natural y textura labial. Evaluación previa y productos específicos.',
   null, false),
  ('Limpieza Facial Simple',
   'Higiene cutánea básica: elimina impurezas superficiales, exceso de sebo, maquillaje y contaminación ambiental. Favorece oxigenación de la piel.',
   29990, false),
  ('Limpieza Facial Profunda',
   'Eliminación profunda de impurezas, comedones, células muertas y exceso de sebo. Favorece renovación celular y previene lesiones acneicas.',
   39990, false),
  ('Limpieza Facial con Oxigenoterapia',
   'Limpieza facial profunda combinada con oxigenoterapia para potenciar oxigenación y revitalización cutánea.',
   69990, false),
  ('Limpieza Facial con Oxigenoterapia (paquete x3 sesiones)',
   'Mismo tratamiento de limpieza facial con oxigenoterapia, en paquete de 3 sesiones.',
   210990, false),
  ('Facial Premium (Oxigenoterapia + Ozonoterapia + Alta Frecuencia + Aparatología + Vitamina C)',
   'Tratamiento facial completo que combina oxigenoterapia, ozonoterapia, alta frecuencia, aparatología y vitamina C para una revitalización integral de la piel.',
   129990, false),
  ('Facial Premium (paquete x3 sesiones)',
   'Mismo tratamiento Facial Premium con oxigenoterapia, ozonoterapia, alta frecuencia, aparatología y vitamina C, en paquete de 3 sesiones.',
   329990, false),
  ('Tratamiento de Acrocordones',
   'Eliminación segura de lesiones cutáneas benignas tipo fibromas blandos. Técnica estéril y evaluación previa de la lesión.',
   null, true)
) as s(nombre, descripcion, precio, req)
join categorias_servicios c on c.nombre = 'Estética y Cuidado Facial'
on conflict do nothing;

-- ------------------------------------------------------------
-- DEPILACIÓN LÁSER (por zona)
-- ------------------------------------------------------------
insert into servicios (categoria_id, nombre, descripcion, precio, requiere_consentimiento)
select c.id, s.nombre, s.descripcion, s.precio::numeric, s.req::boolean
from (values
  ('Depilación Láser - Zona Pequeña (1 sesión)',
   'Bozo, mentón, frente, entrecejo, mejillas, patillas, orejas, nariz, dedos o pezón. Reducción progresiva del vello mediante tecnología láser.',
   10000, false),
  ('Depilación Láser - Zona Pequeña (paquete x6 sesiones)',
   'Bozo, mentón, frente, entrecejo, mejillas, patillas, orejas, nariz, dedos o pezón. Paquete de 6 sesiones.',
   50000, false),
  ('Depilación Láser - Zona Mediana (1 sesión)',
   'Medio rostro, cuello, axilas, línea alba o rebaje simple.',
   15000, false),
  ('Depilación Láser - Zona Mediana (paquete x6 sesiones)',
   'Medio rostro, cuello, axilas, línea alba o rebaje simple. Paquete de 6 sesiones.',
   75000, false),
  ('Depilación Láser - Zona Grande (1 sesión)',
   'Rostro completo, medio brazo, media espalda, glúteos o media pierna.',
   20000, false),
  ('Depilación Láser - Zona Grande (paquete x6 sesiones)',
   'Rostro completo, medio brazo, media espalda, glúteos o media pierna. Paquete de 6 sesiones.',
   100000, false),
  ('Depilación Láser - Zona Extra Grande (1 sesión)',
   'Espalda, abdomen, pierna completa o brazos completos.',
   30000, false),
  ('Depilación Láser - Zona Extra Grande (paquete x6 sesiones)',
   'Espalda, abdomen, pierna completa o brazos completos. Paquete de 6 sesiones.',
   150000, false)
) as s(nombre, descripcion, precio, req)
join categorias_servicios c on c.nombre = 'Depilación Láser'
on conflict do nothing;

-- ------------------------------------------------------------
-- III. BIENESTAR Y ENFERMERÍA
-- ------------------------------------------------------------
insert into servicios (categoria_id, nombre, descripcion, precio, requiere_consentimiento)
select c.id, s.nombre, s.descripcion, s.precio::numeric, s.req::boolean
from (values
  ('Masaje Localizado',
   'Masaje de relajación, drenaje linfático y activación de la circulación. Duración 30-45 minutos.',
   34990, false),
  ('Masaje Localizado (paquete x3 sesiones)',
   'Masaje de relajación, drenaje linfático y activación de la circulación, en paquete de 3 sesiones.',
   84990, false),
  ('Masaje Craneal Champi',
   'Técnica de origen oriental en cuero cabelludo, cuello, rostro y hombros. Promueve relajación profunda y bienestar integral.',
   24990, false),
  ('Masaje Craneal Champi (paquete x3 sesiones)',
   'Masaje craneal Champi en paquete de 3 sesiones.',
   64990, false),
  ('Masaje Descontracturante',
   'Técnica terapéutica para aliviar contracturas musculares y mejorar la movilidad. Localizado o cuerpo completo, 30 minutos.',
   24990, false),
  ('Masaje Descontracturante (paquete x3 sesiones)',
   'Masaje descontracturante en paquete de 3 sesiones.',
   39990, false),
  ('Paquetizado Relajación Completa',
   'Masaje craneal, cuello, brazos, manos, piernas, pies y espalda en una sola sesión integral.',
   54990, false),
  ('Postura de Aros',
   'Perforación segura del lóbulo auricular mediante sistemas certificados y técnica estéril. Incluye indicaciones posteriores.',
   39990, true),
  ('Curaciones Simples y Avanzadas',
   'Manejo de heridas agudas o crónicas: quirúrgicas, traumáticas, úlceras o quemaduras. Evaluación, limpieza, apósitos y seguimiento. Disponible en box o a domicilio.',
   null, false),
  ('Administración de Medicamentos',
   'Aplicación segura de fármacos por distintas vías de administración, previa indicación profesional. Verificación de medicamento, dosis y paciente correcto.',
   null, false)
) as s(nombre, descripcion, precio, req)
join categorias_servicios c on c.nombre = 'Bienestar y Enfermería'
on conflict do nothing;

-- ------------------------------------------------------------
-- NUTRICIÓN
-- ------------------------------------------------------------
insert into servicios (categoria_id, nombre, descripcion, precio, requiere_consentimiento)
select c.id, s.nombre, s.descripcion, s.precio::numeric, s.req::boolean
from (values
  ('Evaluación Nutricional y Análisis de Composición Corporal',
   'Atención nutricional integral e individualizada a cargo de nutricionista certificada. Incluye análisis por bioimpedancia (InBody, Ingrid), anamnesis nutricional, definición de objetivos y plan de alimentación personalizado.',
   null, false)
) as s(nombre, descripcion, precio, req)
join categorias_servicios c on c.nombre = 'Nutrición'
on conflict do nothing;
