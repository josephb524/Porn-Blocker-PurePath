# App Store Connect localization — wave 1

Paste into App Store Connect → App → (language) for each locale. Limits
checked: name ≤ 30, subtitle ≤ 30, keywords ≤ 100 characters. Keywords
are comma-separated with no spaces after commas and skip words already in
the name/subtitle (Apple indexes those anyway).

### Why these names (researched 2026-09-27)

Apple **blocks App Store searches containing "porn" / "porno" / "pornô" /
"nsfw"** — they return zero apps in every storefront ("porn blocker", "quit
porn", "bloqueador de porno", "dejar el porno", "porno aufhören", …). The old
names ("Porn Blocker: PurePath", "Bloqueador de Porno") therefore earned no
search traffic; the app ranked in the US top 12 only for "pornblocker" (#8)
and "purepath" (#2). So each language now gets a store name built from
searchable phrases, taken from Apple's own search suggestions and checked to
return blocker/recovery apps. Popularity scores (Apple Search Ads) were not
available; revisit with App Store Connect search impressions after launch.

- **Works in phrases only:** "pornografía"/"pornografia" and German "pornos"
  ("dejar pornografía", "vício em pornografia", "pornos blockieren").
- **English:** adult content blocker, adult blocker, content blocker, block
  adult content, website blocker, block websites, quit pmo, quit lust,
  overcome lust, quit masturbation, semen retention, addiction/relapse tracker.
- **Spanish:** bloqueador (de contenido / de sitios / adultos), bloquear
  sitios/páginas, dejar lujuria, dejar pornografía, dejar adicciones.
- **Portuguese:** bloqueador de sites adultos (top suggestion), bloquear sites
  adultos, parar pornografia, luxúria, vício em pornografia, largar vícios.
- **German:** pornos blockieren, webseiten blockieren, website blocker,
  sexsucht, sucht/suchtfrei, erwachseneninhalte, jugendschutz, kindersicherung.

Rules followed: a word counts once across name + subtitle + keywords (no
repeats); words combine into phrases only within one localization; keywords
are written without accents (search ignores them). "nofap" is a registered
trademark (NoFap LLC) — it is kept **only** in the keyword field, by choice;
never put it in a name or subtitle. If App Review objects to it, delete it.

**Home-screen / Safari extension name** (guideline 2.3.8 wants it to resemble
the store name): English "Adult Blocker", Spanish and Portuguese "Bloqueador
Adulto", German "Porno-Blocker". Set in the app's `InfoPlist.xcstrings`; the
new names ship with the next binary, so submit the metadata with that build.

**Support URL (every language):** https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
It's the hosted privacy page, which has the contact email. Apple only requires
that the support URL leads to a way to contact you.

Also translate the two subscriptions (Subscriptions → each product →
App Store Localization): display name + description.

---

## English (U.S.) — and English (U.K.)

Previous: Porn Blocker: PurePath / "Adult Content Filter & Streaks" /
`nofap,quit,recovery,accountability,safe,browser,parental,addiction,habit,nsfw,sober,relapse,tracker`.

**Name:** Adult Content Blocker・Quit PMO
**Subtitle:** Block Websites, Overcome Lust
**Keywords:** nofap,pornblocker,site,website,masturbation,semen,retention,sex,addiction,relapse,recovery,tracker

Dropped from the old keywords: nsfw (blocked search), sober and habit (alcohol
and generic habit apps own those), parental (Family Link etc.), safe + browser
(Brave and DuckDuckGo own "safe browser"), accountability (generic habit apps).

Paste the same set into **English (U.K.)** too: the UK store searches it, and
so do Mexico, Spain, Brazil and Germany. In the existing English description,
replace "Porn Blocker: PurePath" / "PurePath" with "Adult Blocker".

If App Store Connect says a name is taken, swap the separator (・ → " - ").

**Promotional text:**
Take back control. Block adult content in Safari, talk to your recovery buddy when an urge hits, and build your streak one day at a time.

---

## Spanish (es-MX and es-ES)

**Name:** Bloqueador de Contenido Adulto
**Subtitle:** Bloquear sitios, dejar lujuria
**Keywords:** nofap,pornografia,paginas,web,adultos,adicciones,masturbacion,racha,control,parental,safari,habitos

Use the same text in **both** Spanish (Mexico) and Spanish (Spain) — they are separate localizations in App Store Connect and each store only indexes its own. Spanish (Mexico) is also indexed in the **US** store.

**Promotional text:**
Recupera el control. Bloquea contenido para adultos en Safari, habla con tu compañero de apoyo cuando llegue un impulso y construye tu racha día a día.

**Description:**
Bloqueador Adulto te ayuda a dejar el porno y a mantenerte limpio.

• Bloquea millones de sitios para adultos en Safari con una extensión de bloqueo de contenido que funciona en tu dispositivo.
• Navegador seguro integrado que bloquea sitios para adultos, difumina imágenes inapropiadas y activa la búsqueda segura.
• Chat con tu compañero: apoyo empático y sin juicios, disponible cada vez que llegue un impulso.
• Seguimiento de rachas, metas y recordatorios diarios.
• Lista de bloqueo personalizable: añade tus propias palabras clave y sitios web, o permite sitios de confianza.
• Privado: el bloqueo se hace en tu dispositivo y tus conversaciones se quedan en él.

Suscripción: las funciones de bloqueo y el chat requieren una suscripción de renovación automática (mensual o anual). El pago se carga a tu Apple ID al confirmar la compra. La suscripción se renueva automáticamente a menos que la canceles al menos 24 horas antes del final del período actual. Puedes gestionarla o cancelarla en Ajustes → Apple ID → Suscripciones.

Política de privacidad: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Términos de uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions:** Anual — "Protección completa y chat de apoyo, facturado cada año." · Mensual — "Protección completa y chat de apoyo, facturado cada mes."

---

## Portuguese (Brazil)

**Name:** Bloqueador de Sites Adultos
**Subtitle:** Parar pornografia e luxúria
**Keywords:** nofap,conteudo,bloquear,largar,vicio,vicios,controle,parental,masturbacao,sequencia,habitos,adulto

Portuguese (Brazil) is also indexed in the **US** store.

**Promotional text:**
Retome o controle. Bloqueie conteúdo adulto no Safari, converse com seu parceiro de apoio quando a vontade bater e construa sua sequência dia após dia.

**Description:**
O Bloqueador Adulto ajuda você a largar o pornô e a continuar limpo.

• Bloqueia milhões de sites adultos no Safari com uma extensão de bloqueio de conteúdo que funciona no seu dispositivo.
• Navegador seguro integrado que bloqueia sites adultos, desfoca imagens impróprias e ativa a pesquisa segura.
• Chat com parceiro: apoio empático e sem julgamentos, disponível sempre que a vontade bater.
• Acompanhamento de sequências, marcos e lembretes diários.
• Lista de bloqueio personalizável: adicione suas próprias palavras-chave e sites, ou libere sites confiáveis.
• Privado: o bloqueio acontece no seu dispositivo e as conversas ficam nele.

Assinatura: os recursos de bloqueio e o chat exigem uma assinatura com renovação automática (mensal ou anual). O pagamento é cobrado no seu Apple ID na confirmação da compra. A assinatura é renovada automaticamente, a menos que seja cancelada pelo menos 24 horas antes do fim do período atual. Gerencie ou cancele em Ajustes → Apple ID → Assinaturas.

Política de Privacidade: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Termos de Uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions:** Anual — "Proteção completa e chat de apoio, cobrado anualmente." · Mensal — "Proteção completa e chat de apoio, cobrado mensalmente."

---

## German

**Name:** Pornos & Webseiten blockieren
**Subtitle:** Website Blocker gegen Sexsucht
**Keywords:** nofap,sucht,suchtfrei,erwachseneninhalte,pornografie,jugendschutz,kindersicherung,streak,rückfall

**Promotional text:**
Hol dir die Kontrolle zurück. Blockiere Inhalte für Erwachsene in Safari, sprich mit deinem Buddy, wenn das Verlangen kommt, und baue deine Serie Tag für Tag auf.

**Description:**
Porno-Blocker hilft dir, mit Pornos aufzuhören und clean zu bleiben.

• Blockiert Millionen Seiten für Erwachsene in Safari – mit einer Inhaltsblocker-Erweiterung, die auf deinem Gerät läuft.
• Integrierter sicherer Browser, der Seiten für Erwachsene blockiert, unangemessene Bilder unscharf macht und SafeSearch erzwingt.
• Buddy-Chat: einfühlsame Unterstützung ohne Urteil, jederzeit da, wenn das Verlangen kommt.
• Serien-Tracking, Meilensteine und tägliche Erinnerungen.
• Anpassbare Sperrliste: eigene Stichwörter und Websites hinzufügen oder vertrauenswürdige Seiten zulassen.
• Privat: Die Blockierung läuft auf deinem Gerät, deine Unterhaltungen bleiben dort.

Abo: Die Blockierfunktionen und der Chat erfordern ein sich automatisch verlängerndes Abo (monatlich oder jährlich). Die Zahlung wird bei Kaufbestätigung über deine Apple-ID abgerechnet. Das Abo verlängert sich automatisch, sofern es nicht spätestens 24 Stunden vor Ende des aktuellen Zeitraums gekündigt wird. Verwalten oder kündigen kannst du es unter Einstellungen → Apple-ID → Abonnements.

Datenschutzerklärung: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions:** Jährlich — "Vollständiger Schutz und Buddy-Chat, jährliche Abrechnung." · Monatlich — "Vollständiger Schutz und Buddy-Chat, monatliche Abrechnung."
