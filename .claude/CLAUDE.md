# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Lingua

Codice, commenti, README, messaggi di commit, titoli e descrizioni di PR e issue sono **in inglese**, come il resto del repository (il repository è pubblico). Le risposte all'utente sono **in italiano**.

## Come lavorare in questo repo

**Regola numero uno: non si tocca nulla che non sia stato chiesto.** Tutto il resto di questa sezione discende da qui.

- **Scope chiuso**: modifica solo i file e le righe necessari a soddisfare la richiesta. Non riscrivere codice funzionante, non rinominare, non riordinare import, non riformattare righe che non stai già modificando, non aggiungere docstring/commenti/type hint a codice che non c'entra, non "sistemare" file vicini. Se un file non serve al task, resta com'è.
- **Commenti brevi**: se un commento serve davvero (spiega un perché non ovvio), massimo 1-2 righe. Niente blocchi di commento lunghi. Niente riferimenti a issue, PR, task o cronologia della modifica ("issue #NN", "aggiunto per...", "prima era così, ora..."): il commento descrive lo stato attuale del codice, non come ci si è arrivati — quei riferimenti marciscono appena il codice cambia ancora e appartengono al messaggio di commit o alla PR, non al codice. Niente percorsi di file nei commenti: si nomina la cosa (funzione, tipo, comando), non il file in cui sta, che si sposta.
- **Minimo essenziale**: di quello che è stato chiesto, implementa la versione più piccola che funziona; i bug trovati per strada si segnalano a fine lavoro, non si correggono di iniziativa. Prima di dichiarare finito, fai l'autoverifica del diff con la skill `codice-minimale`.
- **Non essere minimale su**: validazione di input ai confini di fiducia, gestione errori che previene perdita di dati, misure di sicurezza, accessibilità di base, qualunque cosa richiesta esplicitamente.
- **Autonomia**: procedi senza chiedere conferma per le modifiche al codice; chiedi solo se due letture del task portano a lavori sostanzialmente diversi.
- **Git**: non committare né pushare a meno che non venga chiesto esplicitamente. Il branch principale è `main` e il lavoro si fa su branch dedicati mergiati via PR. Commit e titoli delle PR seguono Conventional Commits: tipi `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`; scope, obbligatorio nei titoli delle PR, il nome del workflow toccato senza estensione (`pr-title`, `test`, `security`, `security-fix`, `release`, `deploy`), `settings` o `claude` per `.claude/`.

### Quando viene richiesta una nuova feature

Quando viene chiesto esplicitamente un lavoro con commit (una feature, un fix, o altro lavoro strutturato in più passi — resta valido il vincolo del bullet **Git** sopra: solo se richiesto), il flusso — branch, checklist, PR draft, un commit per step, gestione di richieste che ampliano il lavoro, code review pre-ready, PR pronta per la review — è nella skill `pr`; per il formato dei singoli commit vedi la skill `commit`.

## Documentazione del progetto

Il [README.md](../README.md) nella root è l'unica documentazione del repository: input, permessi e comportamento di ogni workflow riutilizzabile, impostazioni dei repository chiamanti, esempi. Quando ti serve capire *cosa fa* un workflow o *perché*, leggi il README (e il workflow), non questo file.

Questo CLAUDE.md è solo una mappa operativa per orientarsi: dove stanno le cose, come si lanciano, quali vincoli rispettare.

## Manutenzione di questo file

**Di default questo file NON si tocca**: non è un changelog. Quando e come aggiornarlo (e quando invece va aggiornato il README di un progetto) è nella skill `documenti`.

## Comandi

```bash
settings/apply.sh <owner>/<repo>  # applica le impostazioni GitHub di settings/ a un repository (gh e jq, da admin)
```

**Test**: non ci sono test locali. Sulle PR girano i workflow `ci-*.yml`, che chiamano i workflow riutilizzabili di questo stesso repository (titolo, controlli di sicurezza con zizmor); le modifiche al comportamento si provano con run reali su un branch temporaneo. Non inventare comandi di test oltre a questi.

## Architettura

- `.github/workflows/<nome>.yml` senza prefisso: i workflow riutilizzabili (`workflow_call`), usati dagli altri repository con un tag `vX.Y.Z`. Contengono tutti i loro script: non caricano nulla da questo repository a un altro ref.
- `.github/workflows/ci-*.yml`: la CI di questo repository, che chiama i workflow riutilizzabili con `./`.
- `settings/`: impostazioni e ruleset GitHub che i workflow si aspettano nei repository chiamanti.
- Il titolo della PR diventa il soggetto del commit squash e decide la versione successiva (`feat` → minor, `!` → major, il resto → patch): il push su `main` crea un tag di staging, la release `vX.Y.Z` è immutabile.
