# App Store Connect localization — wave 1

Paste into App Store Connect → App → (language) for each locale. Limits
checked: name ≤ 30, subtitle ≤ 30, keywords ≤ 100 characters. Keywords
are comma-separated with no spaces after commas and skip words already in
the name/subtitle (Apple indexes those anyway).

### Guideline 1.1 rejection (2026-09-28, version 1.6.1)

App Review rejected the metadata under **1.1 Objectionable Content**, citing
the **description and keywords**. The 1.6.1 keywords added sexual terms
(masturbation, semen, retention, sex; masturbacion/masturbacao; pornografia/
pornografie; "pornblocker") that earlier approved versions never had. Rule from
now on: **no sexual or explicit words in keywords, subtitle or description** —
describe the app as blocking "adult content" / "adult websites". Names that
were accepted for years ("Porn Blocker: PurePath", "Porno-Blocker") weren't
cited, so the store names stay; "Sexsucht" and "pornografia" left the
subtitles as a precaution.

### Revision 2026-10-04 (pushed to 1.6.1 via the API, read back verified)

Source of truth is now `appstore-metadata.json` (one object per locale),
pushed with the App Store Connect API; the per-locale blocks below mirror it.
Locales: en-US, en-GB, es-MX, es-ES, pt-BR, de-DE (en-GB and es-ES are new;
they copy en-US / es-MX, except en-GB's keyword field — see "English (U.K.)
keywords" below). Evidence came from a sweep of Apple's search
autosuggest + iTunes search ranks (no popularity scores):

- **US baseline** (live 1.6 name "Porn Blocker: PurePath"): #22 "adult content
  blocker", #42 "content blocker", #77 "block adult content", unranked for
  most else. Re-run the sweep after 1.6.1 ships to measure the change.
- **en subtitle** "Block Websites, Overcome Lust" → **"Website Blocker & Quit
  Lust"**: "block websites" pulls focus-app intent (Refocus, BlockSite);
  "overcome lust" has 9 competitors in their names. "website blocker" +
  "adult" (name) also forms the suggestion "adult website blocker".
- **Dropped "parental"/"control" keywords everywhere** — Family Link-style apps
  hold 17 of the top 25 for "parental control"; wrong intent.
- **es name** "Bloqueador de Contenido Adulto" → **"Bloqueador Adulto・Dejar
  Vicios"**: Spanish autosuggest has no "contenido adulto" at all; it has
  "dejar vicios", "dejar adicciones", "bloquear páginas", "contador de adicciones".
- **de name** "Pornos & Webseiten blockieren" → **"Adult Blocker・Suchtfrei
  werden"**: "pornos blockieren" has no suggestions (13 results) and is a 1.1
  risk; German autosuggest offers "adult blocker", "website blocker",
  "suchtfrei", "sucht tracker". The German home-screen name followed
  ("Porno-Blocker" → "Adult Blocker", 2.3.8).
- **pt-BR** name/subtitle kept — "bloqueador de sites adultos" is a top-3
  completion of "bloqueador".

### Revision 2026-10-19 (Astro data; pushed to the 1.6.2 draft via the API, read back verified)

The first real popularity / difficulty numbers (Astro, Apple Search Ads scale
5–100; 5 is the floor = below measurement, not zero). 1.6.1's names tripled
downloads in their first week (15 → 42 units, Oct 11–17; Latin America 0 → 8)
— proof that a searchable name beats a blocked one — but almost every phrase
they target sits at the floor even where they rank well: "adult content
blocker" 5 (#11 US), "quit pmo" 5 (#32), "dejar vicios" 5 (#8 MX), "bloqueador
de sites adultos" 5 (#8 BR). This revision adds words with measurable volume a
low-authority app can win, while keeping the top-20 phrases in the name or
subtitle (popularity/difficulty below):

- **en-US / en-GB** → "Lust & Adult Content Blocker" / "Quit Urges & Reboot
  Tracker": urge 28/15, lust 27/42 (UK 27/17), reboot 24/11 (UK 24/9); each
  one's results are quit-porn recovery apps. "Urges" also matches "urge" (the
  UK ranked for "urge" with only "urges" indexed).
- **es-MX / es-ES** → "Bloqueador Adulto・Adicciones" / "Dejar vicios・Contador
  de días": adicciones 41/23 MX (addiction trackers), contador de días 47/43
  MX and 30/23 ES (half sobriety counters, half countdowns).
- **pt-BR** → subtitle "Largar vício・Contador de dias": "vício" singular is
  45/19 (recovery apps) and the plural "vícios" wasn't catching it. Name kept.
- **de-DE**: name and subtitle kept ("website blocker" 33/23, "sucht tracker"
  22/17). Keyword field drops "serie" (TV-series results: HBO Max, drama apps)
  and "counter" (tally counters) for "abstinenz".
- Keyword fields add "purepath" (the old brand: popularity 6, unranked since
  the rename), and in the US "dopamine detox" 20/17 and "habit breaker" 19/41.
- Still out: anything with "porn"/"porno" (zero results — rechecked
  2026-10-19), "no nut" (slang; 1.1 risk), "accountability partner" (gym and
  habit apps).
- Baseline for measuring: Astro tracks ~360 keywords for this app across
  us/gb/mx/es/br/de as of 2026-10-19. Compare ranks and per-territory units
  2–3 weeks after 1.6.2 is live. Authority is the ceiling: 2 US ratings, and
  #113 for "quit lust" while it sat in the subtitle.
- Pushed: name, subtitle and keywords only. The description's new purchase
  paragraph (Lifetime + Buddy Chat add-on) is in `appstore-metadata.json` but
  **not yet in App Store Connect** — push it once those products exist.

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
Adulto", German "Adult Blocker" (was "Porno-Blocker" until 2026-10-04). Set in the app's `InfoPlist.xcstrings`; the
new names ship with the next binary, so submit the metadata with that build.

**Support URL (every language):** https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
It's the hosted privacy page, which has the contact email. Apple only requires
that the support URL leads to a way to contact you.

Subscriptions (yearly `pornBlocker`, monthly `monthlyPornBlocker`) and the
subscription group are localized for es-MX, es-ES, pt-BR, de-DE — entered via
the API 2026-10-04 and read back verified. Apple caps the description at 55
characters. The unused `pornBlockerMonthly` (MISSING_METADATA) was left alone.

**New products, not yet created in App Store Connect** (prices still open).
Lifetime `lifetimePornBlocker` is a non-consumable, Family Sharing off. The
Buddy Chat add-on (`buddyChatYearly`, `buddyChatMonthly`) is its own
subscription group, so it never shows as a cheaper switch from Premium in
Settings → Subscriptions. Drafted names and descriptions:

- **en** — Adult Blocker Lifetime — "Protection for life. Buddy chat not included." · group "Buddy Chat": Buddy Chat Yearly — "Buddy chat for Lifetime members, billed yearly." · Buddy Chat Monthly — "Buddy chat for Lifetime members, billed monthly."
- **es** (es-MX + es-ES) — Bloqueador Adulto De por vida — "Protección de por vida. No incluye el chat." · group "Chat con tu compañero": Chat Anual — "Chat de apoyo para el plan de por vida, cobro anual." · Chat Mensual — "Chat de apoyo para el plan de por vida, cobro mensual."
- **pt-BR** — Bloqueador Adulto Vitalício — "Proteção vitalícia. O chat não está incluído." · group "Chat com o parceiro": Chat Anual — "Chat de apoio do plano vitalício, cobrado anualmente." · Chat Mensal — "Chat de apoio do plano vitalício, cobrado mensalmente."
- **de** — Adult Blocker Lebenslang — "Schutz auf Lebenszeit. Ohne Buddy-Chat." · group "Buddy-Chat": Buddy-Chat Jährlich — "Buddy-Chat zum Lebenslang-Kauf, jährliche Abrechnung." · Buddy-Chat Monatlich — "Buddy-Chat zum Lebenslang-Kauf, monatliche Abrechnung."

---

## English (U.S.) — and English (U.K.)

Previous: Porn Blocker: PurePath / "Adult Content Filter & Streaks" /
`nofap,quit,recovery,accountability,safe,browser,parental,addiction,habit,nsfw,sober,relapse,tracker`.

1.6.1 (live from 2026-10-12): Adult Content Blocker・Quit PMO / Website
Blocker & Quit Lust /
`nofap,site,safari,relapse,tracker,overcome,addiction,recovery,streak,filter,habit,counter,urge`.

**Name:** Lust & Adult Content Blocker
**Subtitle:** Quit Urges & Reboot Tracker
**Keywords:** nofap,dopamine detox,habit breaker,website,site,block,pmo,purepath,stop,overcome,streak,safari

Dropped from the old keywords: nsfw (blocked search, and explicit), sober
(alcohol apps own it), safe + browser (Brave and DuckDuckGo own "safe
browser"), accountability (generic habit apps).

**English (U.K.)** (own research, UK storefront sweep 2026-10-04; revised 2026-10-19):
**Name / Subtitle:** the same as en-US since 2026-10-19 — UK popularity
favours the same words at lower difficulty (lust 27/17, urge 27/11, reboot
24/9). Until then: "Adult Content Block・Stop Lust" ("quit pmo" is not a UK
suggestion; "adult content block" is the literal UK completion of "adult").
**Keywords:** `nofap,website,block,pmo,purepath,stop,defeat,overcome,streak,counter,relapse,accountability`
(`pmo` keeps "no pmo" (#21) and "quit pmo" reachable; `stop` keeps "stop
lust" (#11). 2026-10-19 dropped `addiction` and `recovery` — floor and
unranked in Astro — and `tracker`/`urges`, now in the subtitle.)
Subtitle, description, promo, What's New and screenshots are the same as
en-US; es-ES likewise copies es-MX's What's New and screenshots. The UK store
indexes only en-GB, and Spain also indexes it alongside es-ES. UK autosuggest
differs from the US: "quit pmo", "safari content blocker" and "adult site
blocker" are **not** UK suggestions, so `safari`/`site` are out. In: "relapse
tracker/counter", "addiction tracker/counter", "streak counter", "stop lust" (name), "defeat
lust", "accountability" (UK completions are Accountable2You / Ever
Accountable, which are porn-accountability apps, so the intent matches). UK
baseline ranks: #43 "adult content blocker", #135 "block adult content", #26
"pornblocker", #5 "purepath".

Replace the whole English
description with the one below (clean wording, no "PurePath").

If App Store Connect says a name is taken, swap the separator (・ → " - ").

**Description:**
Adult Blocker helps you stay away from adult content and build healthier habits, one day at a time.

• Safari content blocker: blocks millions of adult websites, right on your device.
• Safe Browser: a built-in browser that blocks adult sites, blurs inappropriate images and turns on safe search.
• Recovery buddy: an empathetic, judgment-free chat companion whenever an urge hits.
• Streaks and milestones: daily check-ins, goals and reminders to keep you on track.
• Your rules: add your own keywords and websites to block, or allow sites you trust.
• Private: blocking runs on your device and your conversations stay on it.

Purchase options: the Premium subscription (monthly or yearly, auto-renewing) unlocks the blocking features and the buddy chat. The one-time Lifetime purchase unlocks the blocking features with a single payment but does not include the buddy chat; Lifetime owners can add the chat with a separate auto-renewing subscription. Payment is charged to your Apple ID at confirmation of purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel them in Settings → Apple ID → Subscriptions.

Privacy Policy: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Promotional text:**
Take back control. Block adult content in Safari, talk to your recovery buddy when an urge hits, and build your streak one day at a time.

---

## Spanish (es-MX and es-ES)

1.6.1: Bloqueador Adulto・Dejar Vicios / Bloquear páginas y adicciones /
`nofap,contador,sitios,web,safari,lujuria,recaida,racha,filtro,habitos,recuperacion,control,impulsos`.

**Name:** Bloqueador Adulto・Adicciones
**Subtitle:** Dejar vicios・Contador de días
**Keywords (es-MX):** nofap,bloquear,paginas,sitios,web,safari,lujuria,recaida,racha,habitos,recuperacion,impulsos,filtro
**Keywords (es-ES):** nofap,bloquear,paginas,sitios,web,safari,lujuria,recaida,racha,habitos,sobriedad,impulsos,filtro

Use the same name, subtitle and description in **both** Spanish (Mexico) and Spanish (Spain) — they are separate localizations in App Store Connect and each store only indexes its own. The keyword fields differ by one word: Spain gets `sobriedad` (19/13 there) in place of `recuperacion`. Spanish (Mexico) is also indexed in the **US** store.

**Promotional text:**
Recupera el control. Bloquea contenido para adultos en Safari, habla con tu compañero de apoyo cuando llegue un impulso y construye tu racha día a día.

**Description:**
Bloqueador Adulto te ayuda a alejarte del contenido para adultos y a construir hábitos más sanos, día a día.

• Bloquea millones de sitios para adultos en Safari con una extensión de bloqueo de contenido que funciona en tu dispositivo.
• Navegador seguro integrado que bloquea sitios para adultos, difumina imágenes inapropiadas y activa la búsqueda segura.
• Chat con tu compañero: apoyo empático y sin juicios, disponible cada vez que llegue un impulso.
• Seguimiento de rachas, metas y recordatorios diarios.
• Lista de bloqueo personalizable: añade tus propias palabras clave y sitios web, o permite sitios de confianza.
• Privado: el bloqueo se hace en tu dispositivo y tus conversaciones se quedan en él.

Opciones de compra: la suscripción Premium (mensual o anual, de renovación automática) desbloquea las funciones de bloqueo y el chat. La compra única de por vida desbloquea las funciones de bloqueo con un solo pago, pero no incluye el chat; quien la tenga puede añadir el chat con una suscripción aparte de renovación automática. El pago se carga a tu Apple ID al confirmar la compra. Las suscripciones se renuevan automáticamente a menos que las canceles al menos 24 horas antes del final del período actual. Puedes gestionarlas o cancelarlas en Ajustes → Apple ID → Suscripciones.

Política de privacidad: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Términos de uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions** (es-MX + es-ES; group "Bloqueador Adulto"): Bloqueador Adulto Anual — "Protección completa y chat de apoyo, cobro anual." · Bloqueador Adulto Mensual — "Protección completa y chat de apoyo, cobro mensual."

---

## Portuguese (Brazil)

1.6.1: Bloqueador de Sites Adultos / Bloquear sites e largar vícios /
`nofap,contador,conteudo,filtro,sequencia,habitos,recaida,recuperacao,safari,navegador,impulso`.

**Name:** Bloqueador de Sites Adultos
**Subtitle:** Largar vício・Contador de dias
**Keywords:** nofap,bloquear,conteudo,filtro,habitos,recaida,recuperacao,safari,navegador,impulso,luxuria,vicios
(`vicios` keeps the plural phrases reachable — "largar vicios" #32,
"contador de vicios" #33 — now that the subtitle is singular.)

Portuguese (Brazil) is also indexed in the **US** store.

**Promotional text:**
Retome o controle. Bloqueie conteúdo adulto no Safari, converse com seu parceiro de apoio quando a vontade bater e construa sua sequência dia após dia.

**Description:**
O Bloqueador Adulto ajuda você a ficar longe de conteúdo adulto e a criar hábitos mais saudáveis, dia após dia.

• Bloqueia milhões de sites adultos no Safari com uma extensão de bloqueio de conteúdo que funciona no seu dispositivo.
• Navegador seguro integrado que bloqueia sites adultos, desfoca imagens impróprias e ativa a pesquisa segura.
• Chat com parceiro: apoio empático e sem julgamentos, disponível sempre que a vontade bater.
• Acompanhamento de sequências, marcos e lembretes diários.
• Lista de bloqueio personalizável: adicione suas próprias palavras-chave e sites, ou libere sites confiáveis.
• Privado: o bloqueio acontece no seu dispositivo e as conversas ficam nele.

Opções de compra: a assinatura Premium (mensal ou anual, com renovação automática) desbloqueia os recursos de bloqueio e o chat. A compra única vitalícia desbloqueia os recursos de bloqueio com um só pagamento, mas não inclui o chat; quem a tiver pode adicionar o chat com uma assinatura à parte, com renovação automática. O pagamento é cobrado no seu Apple ID na confirmação da compra. As assinaturas são renovadas automaticamente, a menos que sejam canceladas pelo menos 24 horas antes do fim do período atual. Gerencie ou cancele em Ajustes → Apple ID → Assinaturas.

Política de Privacidade: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Termos de Uso: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions** (group "Bloqueador Adulto"): Bloqueador Adulto Anual — "Proteção completa e chat de apoio, cobrado anualmente." · Bloqueador Adulto Mensal — "Proteção completa e chat de apoio, cobrado mensalmente."

---

## German

**Name:** Adult Blocker・Suchtfrei werden
**Subtitle:** Website Blocker, Sucht Tracker
**Keywords:** nofap,beenden,filter,safari,rückfall,erwachseneninhalte,inhalte,gewohnheiten,verlangen,abstinenz
(2026-10-19: `serie` and `counter` out — TV-series and tally-counter results.)

**Promotional text:**
Hol dir die Kontrolle zurück. Blockiere Inhalte für Erwachsene in Safari, sprich mit deinem Buddy, wenn das Verlangen kommt, und baue deine Serie Tag für Tag auf.

**Description:**
Mit dieser App hältst du Inhalte für Erwachsene fern und baust gesündere Gewohnheiten auf – Tag für Tag.

• Blockiert Millionen Seiten für Erwachsene in Safari – mit einer Inhaltsblocker-Erweiterung, die auf deinem Gerät läuft.
• Integrierter sicherer Browser, der Seiten für Erwachsene blockiert, unangemessene Bilder unscharf macht und SafeSearch erzwingt.
• Buddy-Chat: einfühlsame Unterstützung ohne Urteil, jederzeit da, wenn das Verlangen kommt.
• Serien-Tracking, Meilensteine und tägliche Erinnerungen.
• Anpassbare Sperrliste: eigene Stichwörter und Websites hinzufügen oder vertrauenswürdige Seiten zulassen.
• Privat: Die Blockierung läuft auf deinem Gerät, deine Unterhaltungen bleiben dort.

Kaufoptionen: Das Premium-Abo (monatlich oder jährlich, verlängert sich automatisch) schaltet die Blockierfunktionen und den Chat frei. Der einmalige Lebenslang-Kauf schaltet die Blockierfunktionen mit einer einzigen Zahlung frei, enthält aber nicht den Chat; wer ihn besitzt, kann den Chat mit einem separaten, sich automatisch verlängernden Abo hinzufügen. Die Zahlung wird bei Kaufbestätigung über deine Apple-ID abgerechnet. Abos verlängern sich automatisch, sofern sie nicht spätestens 24 Stunden vor Ende des aktuellen Zeitraums gekündigt werden. Verwalten oder kündigen kannst du sie unter Einstellungen → Apple-ID → Abonnements.

Datenschutzerklärung: https://josephb524.github.io/Porn-Blocker-Pure-Path-Privacy/
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**Subscriptions** (group "Adult Blocker"): Adult Blocker Jährlich — "Voller Schutz und Buddy-Chat, jährliche Abrechnung." · Adult Blocker Monatlich — "Voller Schutz und Buddy-Chat, monatliche Abrechnung."
