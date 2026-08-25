# Auftrag für Claude Code auf meinem NixOS-Rechner

Ich arbeite an meinem Fork **github.com/Pascal-SAPUI5/payforme**, einem Fork von
`InteractionEngineer/PayForMe` (iOS-App, SwiftUI, Apache 2.0). Eine Remote-Session
hat dort ein Redesign, einen Statistik-Tab und zwei Bugfixes gebaut. Drei Aufgaben
konnte sie nicht abschließen, weil ihr die Rechte fehlten. Die sollst du erledigen.

**Ich habe keinen Mac.** Xcode ist hier nicht verfügbar, Bauen und Testen laufen
ausschließlich über GitHub Actions. Versuche keine lokalen Xcode-Builds.

## Ausgangslage (Stand des Auftrags)

| | |
|---|---|
| Upstream-Basis-Commit | `0d0267e89d3edf03da836b016375f925eba40125` |
| `main` HEAD | `7a1414d810929e6a10dfe7f005a73df92da5cbd5` |
| Commits auf `main` seit Basis | 10, davon **9 mit Autor `Claude <noreply@anthropic.com>`** |
| `fix/preserve-bill-category-on-update` | `91f3f04`, Autor bereits Pascal, **unsigniert** |
| `fix/locale-aware-amounts-and-dates` | `481833c`, Autor bereits Pascal, **unsigniert** |

CI ist grün: Build und Tests laufen auf jedem Push nach `main` über
`.github/workflows/ios.yml`.

## Meine Identität

```
Name:  Pascal Wachowski
Mail:  186315683+Pascal-SAPUI5@users.noreply.github.com
```

Die noreply-Adresse ist bei meinem GitHub-Konto automatisch verifiziert. Verwende
**nicht** meine private Mailadresse — sie soll nicht in eine öffentliche
Commit-Historie.

---

## Aufgabe 1 — Autorenschaft auf `main` korrigieren

**Warum blockiert:** Umschreiben publizierter Historie plus Force-Push wurde in der
Remote-Session vom Sicherheits-Classifier abgelehnt.

**Was zu tun ist:** Die 9 Commits mit Autor `Claude` auf mich umschreiben. Der
Basis-Commit `0d0267e` gehört upstream und darf **nicht** angefasst werden — deshalb
die Range-Angabe.

```bash
nix-shell -p git openssh
git clone https://github.com/Pascal-SAPUI5/payforme && cd payforme

git filter-branch -f --env-filter '
if [ "$GIT_AUTHOR_EMAIL" = "noreply@anthropic.com" ]; then
  export GIT_AUTHOR_NAME="Pascal Wachowski"
  export GIT_AUTHOR_EMAIL="186315683+Pascal-SAPUI5@users.noreply.github.com"
fi
if [ "$GIT_COMMITTER_EMAIL" = "noreply@anthropic.com" ]; then
  export GIT_COMMITTER_NAME="Pascal Wachowski"
  export GIT_COMMITTER_EMAIL="186315683+Pascal-SAPUI5@users.noreply.github.com"
fi' -- 0d0267e..HEAD
```

**Vor dem Push prüfen — der Inhalt darf sich nicht ändern:**

```bash
git diff 7a1414d HEAD --stat        # muss LEER sein
git log --format='%an' 0d0267e..HEAD | sort -u   # nur "Pascal Wachowski"
git rev-parse 0d0267e^{commit}      # Basis muss unverändert existieren
```

Erst wenn der Diff leer ist:

```bash
git push --force-with-lease origin main
```

**Nebenwirkungen, die erwartet sind:** Alle SHAs ab `53b2fe0` ändern sich. Der
CI-Lauf zu `b03ab51` verwaist. Der Force-Push löst einen neuen Lauf aus — der muss
grün werden, sonst hat das Umschreiben etwas kaputtgemacht.

Der `Co-Authored-By: Claude Opus 5`-Trailer bleibt in allen Commit-Messages stehen.
Das ist Absicht: Ich verantworte den Beitrag, das Werkzeug ist genannt.

---

## Aufgabe 2 — Commits signieren, damit GitHub „Verified" zeigt

**Warum blockiert:** Die Remote-Session konnte nur mit dem Claude-Code-Schlüssel
signieren. Sobald ich als Autor eingetragen war, passten Schlüssel und Identität
nicht mehr zusammen und GitHub zeigte „Unverified". Für eine gültige Signatur
braucht es meinen Schlüssel — der liegt nur hier.

**Voraussetzung:** Ein SSH-Schlüssel, dessen **öffentlicher** Teil bei GitHub unter
*Settings → SSH and GPG keys* als **Key type: Signing Key** hinterlegt ist (nicht
als Authentication Key — das ist der übliche Fehler).

```bash
# falls noch keiner existiert
ssh-keygen -t ed25519 -C "pascal@nixos"
cat ~/.ssh/id_ed25519.pub     # bei GitHub als SIGNING KEY eintragen

git config gpg.format ssh
git config user.signingkey ~/.ssh/id_ed25519.pub
git config commit.gpgsign true
```

Dann die beiden PR-Branches neu signieren:

```bash
for b in fix/preserve-bill-category-on-update fix/locale-aware-amounts-and-dates; do
  git checkout "$b"
  git commit --amend --no-edit -S
  git push --force-with-lease origin "$b"
done
```

**Wenn für Aufgabe 1 ohnehin umgeschrieben wird**, setze `commit.gpgsign true`
vorher — dann werden die neu erzeugten `main`-Commits gleich mit meinem Schlüssel
signiert und Aufgabe 2 erledigt sich für `main` mit.

**Einschätzung, die ich teile:** Der Haken auf meinem Branch überlebt den Merge
ohnehin nicht — GitHub signiert den entstehenden Commit beim Merge mit seinem
eigenen Schlüssel. Wenn es Zeit kostet, ist das die unwichtigste der drei Aufgaben.

---

## Aufgabe 3 — Pull Request nach upstream

**Warum blockiert:** Die Remote-Session war auf `pascal-sapui5/payforme` beschränkt
und bekam bei `InteractionEngineer/PayForMe` ein `Access denied`.

Zuerst den kleinen Bugfix, allein:

```bash
gh pr create \
  --repo InteractionEngineer/PayForMe \
  --base main \
  --head Pascal-SAPUI5:fix/preserve-bill-category-on-update \
  --title "Keep a bill's category and payment mode when it is updated" \
  --body-file pr-body.md
```

Den Text für `pr-body.md` habe ich als `PR-1-category-preservation.md` vorliegen —
alles unterhalb der Zeile `# Beschreibung`. Für den zweiten PR gilt dasselbe mit
`PR-2-locale-formatting.md` und Branch `fix/locale-aware-amounts-and-dates`.

**Nicht beide gleichzeitig.** Erst wenn PR 1 angenommen ist, den zweiten
hinterherschicken.

---

## Was du NICHT tun sollst

- **`project.pbxproj` nicht anfassen**, um Bundle-ID oder `DEVELOPMENT_TEAM` zu
  ändern. Dort stehen `de.mayflower.PayForMe` und Team `22BT3L9N5V` — die gehören
  dem Upstream-Autor. Für meine TestFlight-Builds werden beide Werte in
  `.github/workflows/ios-testflight.yml` per `xcodebuild`-Flag überschrieben. Würde
  man sie im Projekt ändern, landete das in jedem künftigen Upstream-PR.
- **Den Basis-Commit `0d0267e` nicht umschreiben.** Er gehört upstream.
- **Die PR-Branches nach dem Öffnen des PR nicht force-pushen**, außer auf
  ausdrückliche Bitte eines Reviewers. Sie sitzen bewusst auf Upstream-`main` und
  enthalten **kein** Redesign und **keine** Anhebung des Deployment-Targets.
- **Das Redesign nicht als PR schicken.** Das gehört zuerst in ein Issue zur
  Abstimmung mit dem Maintainer — 3.000 Zeilen plus eine Anhebung von iOS 15 auf 17
  sind eine Entscheidung über seine Nutzerbasis, nicht meine.
- **Keine lokalen Xcode-Builds versuchen.** Kein Mac.

## Reihenfolge

Aufgabe 1, dann prüfen ob CI grün bleibt, dann Aufgabe 3. Aufgabe 2 nur, wenn
Zeit übrig ist.
