# AiSentry

*[Italiano sotto / Italian below](#aisentry-italiano)*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS: 14+](https://img.shields.io/badge/macOS-14%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)

A lightweight macOS menu bar app that shows, at a single glance, how much you have consumed of your AI plans and APIs: Claude, OpenAI, Gemini, and Grok, designed with a modular architecture to easily add more.

---

## Why

None of these AI providers expose a simple endpoint saying "your current usage percentage": some only show it within their web interface (Claude, Grok), others only via billing-specific APIs (OpenAI Costs API), and others via internal RPC calls (Gemini).

**AiSentry** unifies all these into a single dashboard. It periodically polls each configured provider and displays the highest (most constrained) consumption percentage directly in your macOS menu bar.

## Supported Providers

| Provider | Metric Measured | Source | Stability |
|---|---|---|---|
| **Claude (chat)** | Session quota (5h) + weekly quota for Pro/Max plans | claude.ai undocumented endpoint, session cookie | Good (clean JSON, unofficial) |
| **Claude API** | Monthly spending vs. limit configured on platform.claude.com | Undocumented endpoint, session cookie | Good |
| **Grok (chat)** | Remaining messages in the current window | grok.com undocumented endpoint, session cookie | Good |
| **OpenAI API** | Monthly spending vs. custom user budget | **Official documented API** (Costs API), Admin API key | High |
| **Gemini (chat)** | Current usage + weekly quota for AI Plus/Pro/Ultra | Google internal "batchexecute" RPC (`jSf9Qc`), session cookie | **Experimental** (see below) |

> ⚠️ Any source based on an undocumented web endpoint may break without warning if the provider alters their frontend. All credentials (cookies/API keys) are securely stored in the **macOS Keychain**, never saved in plain text on disk.

### Notes on Gemini (chat)
Anti-CSRF tokens, session IDs (`f.sid`), and build labels are parsed dynamically from the page HTML (`Sources/AiSentry/Core/GoogleBatchExecute.swift`) rather than hardcoded, ensuring resilience across Google frontend deployments.

### Not Yet Supported
- **ChatGPT (chat)**: Usage limit endpoints exist in OpenAI's backend but are inactive on Free tiers.
- **Google AI Studio (API)**: Investigating Cloud Quotas API / Service Usage API before attempting web scraping.
- **Grok API (console.x.ai)**: Usage figures are currently embedded in the Next.js React Server Component (RSC) stream rather than a clean JSON endpoint.

## How It Works

- **Swift + SwiftUI**, using native `MenuBarExtra` (macOS 14+).
- Every provider conforms to the `UsageSource` protocol (`Sources/AiSentry/Core/UsageModels.swift`): declares required credential fields (cookie, API key, org ID, budget) and returns a list of `UsageMetric` (percentage + textual details).
- `UsageMonitor` queries all active sources in parallel at regular intervals (default: 10 minutes, user-configurable) and maintains reactive state for the UI.
- The Settings window dynamically renders configuration forms based on each provider's declared requirements—adding a new provider requires zero UI changes, simply adding a new `UsageSource` file under `Sources/AiSentry/Providers/`.

## Configuring a Provider

For web-based sources, copy the session cookie (or API key) using your browser's Developer Tools:

1. Open the provider's web settings (e.g., `claude.ai` → Settings → Usage).
2. Open Developer Tools (`Cmd + Option + I`) → **Network** tab, then reload the page.
3. Locate the usage request (e.g., `.../usage` for Claude), right-click → **Copy** → **Copy request headers** (or copy the `Cookie` header directly).
4. Paste the value into the corresponding field in AiSentry Settings.
5. For Claude, the organization ID is found directly in the URL of that request (`/api/organizations/<org_id>/usage`).

*(Session cookies expire periodically based on the provider's policy. If a source reports an authentication error, refresh the cookie using the steps above.)*

For **OpenAI API**, generate an **Admin API Key** under `platform.openai.com` → Settings → Admin keys (requires organization owner permissions).

## Installation

```bash
./Scripts/build_dmg.sh
```

This generates `dist/AiSentry-<version>.dmg`. Mount the disk image and drag **AiSentry.app** to your `/Applications` folder, or install directly via terminal:

```bash
cp -R dist/AiSentry.app /Applications/
```

> **First Launch on macOS:** Because this app is ad-hoc signed and not notarized through a paid Apple Developer ID, macOS Gatekeeper may flag it on first launch. Right-click (or Control-click) **AiSentry.app** in `/Applications` → **Open** → confirm in the dialog. This is only required once.

## Development

```bash
swift build
swift run
```

To build only the `.app` bundle without DMG packaging:
```bash
./Scripts/build_app.sh
```

## License

[MIT](LICENSE) — free for personal and commercial use.

AiSentry is free and open-source. If you find it helpful, feel free to [buy me a coffee on Ko-fi](https://ko-fi.com/gaskb) ☕!

---

<br>

<a name="aisentry-italiano"></a>
# AiSentry (Italiano)

App per la barra menu di macOS che mostra, in un colpo d'occhio, quanto hai consumato dei tuoi piani/API di AI: Claude, OpenAI, Gemini e Grok per ora, con un'architettura modulare pensata per aggiungerne altri.

## Perché

Nessuno di questi servizi pubblica un endpoint semplice con "la tua percentuale di utilizzo": alcuni la mostrano solo nella loro web app (Claude, Grok), altri solo tramite un'API ufficiale pensata per la fatturazione (OpenAI Costs API), altri tramite chiamate interne RPC (Gemini).

**AiSentry** normalizza tutto in un'unica vista: interroga periodicamente ogni provider e mostra la percentuale peggiore (più vicina al limite) direttamente nella barra menu di macOS.

## Provider supportati

| Provider | Cosa misura | Fonte | Stabilità |
|---|---|---|---|
| **Claude (chat)** | Quota sessione (5h) + settimanale del piano Pro/Max | Endpoint non documentato di claude.ai, cookie di sessione | Buona (JSON pulito, non ufficiale) |
| **Claude API** | Spesa mensile vs. limite configurato su platform.claude.com | Endpoint non documentato, cookie di sessione | Buona |
| **Grok (chat)** | Messaggi rimanenti nella finestra corrente | Endpoint non documentato di grok.com, cookie di sessione | Buona |
| **OpenAI API** | Spesa mensile vs. budget impostato a mano | **API ufficiale documentata** (Costs API), Admin API key | Alta |
| **Gemini (chat)** | Utilizzo corrente + limite settimanale del piano AI Plus/Pro/Ultra | Protocollo interno "batchexecute" di Google (rpcid `jSf9Qc`), cookie di sessione | **Sperimentale** (vedi sotto) |

> ⚠️ Ogni fonte basata su un endpoint non documentato può smettere di funzionare senza preavviso se il provider cambia la propria web app. Le credenziali (cookie/API key) sono salvate in modo sicuro nel **Keychain di macOS**, mai in chiaro su disco.

### Note su Gemini (chat)
Il token anti-CSRF, il session ID (`f.sid`) e il build label sono letti dinamicamente dall'HTML della pagina (`Sources/AiSentry/Core/GoogleBatchExecute.swift`) invece che hardcoded, evitando rotture a ogni nuovo deploy di Google.

### Non ancora supportati
- **ChatGPT (chat)**: la funzione di "limiti di utilizzo" esiste nel backend di OpenAI ma è disattivata per il piano Free; va ripresa con un account Plus/Pro per scoprire l'endpoint reale.
- **Google AI Studio (API)**: da verificare se Google espone lo stesso dato tramite un'API ufficiale più stabile (Cloud Quotas API / Service Usage API) prima di implementarlo via scraping.
- **Grok API (console.x.ai)**: il dato di utilizzo è incorporato nello stream Next.js RSC della pagina, non un endpoint JSON separato.

## Come funziona

- **Swift + SwiftUI**, con `MenuBarExtra` nativo (macOS 14+).
- Ogni provider implementa il protocollo `UsageSource` (`Sources/AiSentry/Core/UsageModels.swift`): dichiara i campi che gli servono (cookie, API key, ID organizzazione, budget) e restituisce una lista di `UsageMetric` (percentuale + dettaglio testuale).
- `UsageMonitor` interroga tutte le fonti abilitate in parallelo a intervalli regolari (default 10 minuti, configurabile) e tiene lo stato per la UI.
- Le Impostazioni generano automaticamente un form per ogni provider a partire dai campi richiesti: aggiungere un nuovo provider non tocca la UI, basta un nuovo file in `Sources/AiSentry/Providers/` che conforma `UsageSource`.

## Configurare un provider

Per le fonti web serve copiare un cookie di sessione (o una API key) dagli Strumenti di sviluppo del browser:

1. Apri le Impostazioni del sito nel browser (es. claude.ai → Impostazioni → Utilizzo).
2. Apri gli Strumenti di sviluppo (`Cmd + Option + I`) → scheda **Network**, ricarica la pagina.
3. Trova la richiesta indicata nella tabella (es. `.../usage` per Claude), tasto destro → **Copy** → **Copy request headers** (o copia direttamente il valore dell'header `Cookie`).
4. Incolla il valore nel campo corrispondente nelle Impostazioni di AiSentry.
5. Per Claude, l'ID organizzazione è visibile nell'URL della stessa richiesta (`/api/organizations/<questo>/usage`).

*(I cookie scadono periodicamente: quando una fonte inizia a dare errore di autenticazione, ripeti la procedura).*

Per **OpenAI API** serve invece una **Admin API key** vera e propria, da creare su `platform.openai.com` → Settings → Admin keys (richiede il ruolo owner dell'organizzazione).

## Installazione

```bash
./Scripts/build_dmg.sh
```

Apre `dist/AiSentry-<versione>.dmg`: monta l'immagine e trascina **AiSentry.app** in Applicazioni, oppure direttamente da terminale:

```bash
cp -R dist/AiSentry.app /Applications/
```

> **Primo avvio su macOS:** Non essendo firmata con un account Apple Developer ID a pagamento, al primo avvio macOS segnala l'app come proveniente da sviluppatore non identificato. Tasto destro su **AiSentry.app** in Applicazioni → **Apri** → conferma nella finestra di dialogo (necessario solo la prima volta).

## Sviluppo

```bash
swift build
swift run
```

Per costruire solo il bundle `.app` (senza impacchettarlo in un DMG):
```bash
./Scripts/build_app.sh
```

## Licenza

[MIT](LICENSE) — fanne quello che vuoi, basta mantenere la nota di copyright.

AiSentry è gratis e open-source. Se ti torna utile, sentiti libero di [offrirmi un caffè su Ko-fi](https://ko-fi.com/gaskb) ☕!
