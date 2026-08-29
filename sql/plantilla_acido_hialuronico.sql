-- ============================================================
-- Plantilla de consentimiento: Ácido Hialurónico (relleno dérmico)
-- Basada en el formulario real de AIVIMED + puntos legales agregados.
-- Ejecutar en el SQL Editor de Supabase.
-- ============================================================
set search_path to bienestar;

update servicios
set consentimiento_template = $txt$CONSENTIMIENTO INFORMADO — RELLENO DÉRMICO CON ÁCIDO HIALURÓNICO
AIVIMED — Salud Integral

Paciente: {nombre}
RUT: {rut}
Fecha: {fecha}    Hora: ____________
Profesional tratante: ____________________
Producto / Lote / Vencimiento: ____________________
Zona(s) a tratar: ____________________

Yo, {nombre}, RUT {rut}, por medio de la presente autorizo de manera libre y voluntaria al profesional tratante a realizar el procedimiento de relleno dérmico con {procedimiento}, y reconozco haber sido informado/a sobre lo que consiste someterse a dicho procedimiento en los siguientes puntos:

1. El objetivo de la técnica es conseguir un relleno dérmico en la(s) zona(s) indicada(s) más arriba.

2. Se trata de un procedimiento estético mínimamente invasivo que puede romper la epidermis y producir heridas.

3. Declaro haber informado al profesional sobre cualquier enfermedad de la piel, alergias, problemas de coagulación, uso de anticoagulantes, embarazo, lactancia, enfermedades autoinmunes, infección activa en la zona u otra condición relevante antes de realizarme el implante de ácido hialurónico.

4. El tratamiento consiste en inyectar una sustancia sintética, biocompatible y biodegradable, para conseguir el relleno dérmico. La duración del efecto es variable de persona a persona, generalmente de varios meses.

5. Se puede repetir el tratamiento o inyectar una pequeña dosis para retoque, siempre que sea necesario y con un intervalo a criterio del profesional.

6. Soy consciente de que existe variabilidad individual en la respuesta a cualquier tratamiento y comprendo que, pese a la adecuada elección y correcta realización, pueden presentarse efectos no deseados como hinchazón, enrojecimiento, dolor, escozor o algún tipo de reacción alérgica, que puede ser algo más duradera cuando la implantación es en los labios. También pueden aparecer equimosis (moretones) que desaparecen espontáneamente en algunos días. Excepcionalmente, y en raras ocasiones, puede aparecer reacción tardía, granulomas, abscesos o necrosis.

7. Se me advierte que, después del implante, debo mantener la zona siempre limpia, hidratada y desinfectada; evitar la exposición solar y los baños de vapor, y no masajear la zona. En caso de exposición solar, deberé cubrir toda la zona con productos de pantalla total.

8. Entiendo que no se garantizan resultados específicos, ya que dependen de las características individuales de cada paciente.

9. He comprendido las explicaciones que se me han facilitado en un lenguaje claro y sencillo, y he podido realizar todas las observaciones que he requerido, las cuales se me han explicado y aclarado en su totalidad. Por ello, manifiesto que estoy satisfecho/a con la información recibida, comprendiendo el alcance y los riesgos del tratamiento, y en tales condiciones acepto que se me realice el tratamiento de relleno con ácido hialurónico.

10. Declaro que la información entregada sobre mi estado de salud es veraz y completa, y me comprometo a seguir las indicaciones pre y post procedimiento y a asistir a los controles que se me indiquen.

11. Autorizo el registro fotográfico o audiovisual del procedimiento, incluyendo la zona tratada, con fines clínicos, de seguimiento y educativos, y autorizo el tratamiento de mis datos personales conforme a la Ley N° 19.628 sobre Protección de la Vida Privada, con fines exclusivamente relacionados con mi atención en salud.

12. AUTORIZACIÓN PUBLICITARIA (OPCIONAL — marque una opción): adicional y separadamente, autorizo el uso de mis imágenes con fines publicitarios o de difusión en las redes sociales de AIVIMED.
    [  ] SÍ autorizo el uso publicitario        [  ] NO autorizo el uso publicitario

13. Declaro conocer que puedo revocar este consentimiento en cualquier momento antes de la realización del procedimiento, sin que ello afecte la calidad ni la continuidad de mi atención.

En consecuencia, autorizo la realización del procedimiento mencionado, aceptando los riesgos inherentes al mismo.


Firma del paciente: ____________________    RUT: {rut}

Firma del profesional: ____________________

Fecha: {fecha}$txt$
where nombre = 'Ácido hialurónico';

reset search_path;
