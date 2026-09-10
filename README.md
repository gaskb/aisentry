# AiSentry

App per la barra menu di macOS che mostra, in un colpo d'occhio, quanto hai consumato dei tuoi piani/API di AI: Claude, OpenAI e Grok per ora, con un'architettura pensata per aggiungerne altri.

## Perché

Nessuno di questi servizi pubblica un endpoint semplice con "la tua percentuale di utilizzo": alcuni la mostrano solo nella loro web app (Claude, Grok), altri solo tramite un'API ufficiale pensata per la fatturazione (OpenAI). AiSentry normalizza tutto in un'unica vista, interrogando periodicamente ogni provider e mostrando la percentuale peggiore nella barra menu.

## Provider supportati

| Provider | Cosa misura | Fonte | Stabilità |
|---|---|---|---|
| Claude (chat) | Quota sessione (5h) + settimanale del piano Pro/Max | Endpoint non documentato di claude.ai, cookie di sessione | Buona (JSON pulito, ma non ufficiale) |
| Claude API | Spesa mensile vs. limite configurato su platform.claude.com | Endpoint non documentato, cookie di sessione | Buona |
| Grok (chat) | Messaggi rimanenti nella finestra corrente | Endpoint non documentato di grok.com, cookie di sessione | Buona |
| OpenAI API | Spesa mensile vs. budget impostato a mano | **API ufficiale documentata** (Costs API), Admin API key | Alta |
| Gemini (chat) | Utilizzo corrente + limite settimanale del piano AI Plus/Pro/Ultra | Protocollo interno "batchexecute" di Google (rpcid `jSf9Qc`), cookie di sessione | **Sperimentale** — vedi sotto |

Ogni fonte basata su un endpoint non documentato (cioè tutte tranne OpenAI) può smettere di funzionare senza preavviso se il provider cambia la propria web app. Le credenziali (cookie/API key) sono salvate nel Keychain di macOS, mai in chiaro su disco.

**Su Gemini (chat) in particolare**: il token anti-CSRF, il session id e il build label che la richiesta richiede sono tutti letti dinamicamente dall'HTML della pagina (`Sources/AiSentry/Core/GoogleBatchExecute.swift`) invece che hardcoded, quindi non si rompe a ogni deploy di Google come temuto inizialmente. Resta "sperimentale" per un motivo diverso: la semantica esatta della risposta (in che unità sono "limite"/"usato") è stata dedotta da un solo campione con utilizzo a zero, non confermata su un valore reale diverso da zero.

### Non ancora supportati

- **ChatGPT (chat)**: la funzione di "limiti di utilizzo" esiste nel backend di OpenAI ma è disattivata per il piano Free; va ripresa con un account Plus/Pro per scoprire l'endpoint reale.
- **Google AI Studio (API)**: stessa famiglia di protocollo RPC di Gemini chat, ma da verificare se Google espone lo stesso dato tramite un'API ufficiale più stabile (Cloud Quotas API / Service Usage API) prima di implementarlo via scraping.
- **Grok API** (console.x.ai): il dato di utilizzo è incorporato nello stream Next.js RSC della pagina, non un endpoint JSON separato; da verificare se x.ai pubblica un'API ufficiale alternativa.

## Come funziona

- Swift + SwiftUI, `MenuBarExtra` (macOS 14+), stessa impostazione di [PingSentry](https://gitlab.gaskb.net/root/pingsentry).
- Ogni provider implementa il protocollo `UsageSource` (`Sources/AiSentry/Core/UsageModels.swift`): dichiara i campi che gli servono (cookie, API key, ID organizzazione, budget) e restituisce una lista di `UsageMetric` (percentuale + dettaglio testuale).
- `UsageMonitor` interroga tutte le fonti abilitate in parallelo a intervalli regolari (default 10 minuti, configurabile) e tiene lo stato per la UI.
- Le Impostazioni generano automaticamente un form per ogni provider a partire dai campi richiesti — aggiungere un nuovo provider non tocca la UI, basta un nuovo file in `Providers/` che conforma `UsageSource`.

## Configurare un provider

Per ognuno serve copiare un cookie di sessione (o una API key) dagli Strumenti di sviluppo del browser. Non è elegante, ma è l'unico modo per leggere dati che il provider non espone via API pubblica:

1. Apri le Impostazioni del sito nel browser (es. claude.ai → Impostazioni → Utilizzo).
2. Apri gli Strumenti di sviluppo → scheda Network, ricarica la pagina.
3. Trova la richiesta indicata nella tabella qui sopra (es. `.../usage` per Claude), tasto destro → Copy → Copy request headers (o simile).
4. Incolla l'intero valore dell'header `Cookie` nel campo corrispondente nelle Impostazioni di AiSentry.
5. Per Claude, l'ID organizzazione è visibile nell'URL della stessa richiesta (`/api/organizations/<questo>/usage`).

Il cookie scade periodicamente (dipende dal provider): quando una fonte inizia a dare errore, ripeti la procedura.

Per OpenAI serve invece una **Admin API key** vera e propria, da creare su platform.openai.com → Settings → Admin keys (richiede il ruolo owner dell'organizzazione).

## Installazione

Non notarizzata (nessun account Apple Developer ID configurato) e non ancora pubblicata come release scaricabile — per ora si costruisce ed installa localmente:

```bash
./Scripts/build_dmg.sh
```

Apre `dist/AiSentry-<versione>.dmg`; monta l'immagine e trascina AiSentry.app in Applications, oppure direttamente:

```bash
cp -R dist/AiSentry.app /Applications/
```

Al primo avvio da Finder/Launchpad, macOS segnala l'app come da sviluppatore non identificato: tasto destro su AiSentry in Applications → **Apri** → conferma nella finestra di dialogo. Serve una volta sola. Da lì in poi si apre normalmente con un doppio click, senza bisogno di lanciarla da terminale.

## Sviluppo

```bash
swift build
swift run
```

`swift run` è comodo per iterare rapidamente, ma lanciata così l'app non riceve mai il focus da tastiera se il processo che la avvia (terminale, tool di automazione) non è considerato "in primo piano" da macOS — i click sui campi arrivano, la tastiera no. Per un test realistico usa il bundle `.app` installato con `build_dmg.sh`/`build_app.sh` invece di `swift run`.

Per costruire solo il bundle `.app` (senza impacchettarlo in un DMG):

```bash
./Scripts/build_app.sh
```

## Licenza

[MIT](LICENSE) — do whatever you want with it, just keep the copyright notice.

AiSentry è gratis. Se ti torna utile, sentiti libero di [offrirmi un caffè ☕](https://ko-fi.com/gaskb).
