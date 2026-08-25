# Divido für Android

Android-Client für [Nextcloud Cospend](https://github.com/julien-nc/cospend-nc)
und [iHateMoney](https://ihatemoney.org) — das Gegenstück zur iOS-App im
übergeordneten Verzeichnis.

## Aufbau

- **`core`** — Datenmodell, Projekt-ID-Logik und HTTP-Client als reines
  Kotlin/JVM-Modul, ohne Android-Abhängigkeit. Baut und testet auf jedem Rechner
  mit einem JDK, ganz ohne Android SDK oder Emulator.
- **`app`** — Oberfläche in Jetpack Compose, Material 3 mit dynamischer Farbgebung.

Die Trennung ist kein Selbstzweck: Sie hält die Logik dort prüfbar, wo sie
schnell prüfbar ist. `gradle :core:test` läuft in Sekunden und braucht kein SDK.

## Bauen

    gradle :core:test          # Logik, ohne Android SDK
    gradle :app:assembleDebug  # braucht das Android SDK
    gradle :app:bundleRelease  # signierte AAB, siehe unten

## Signierung

Die Release-Signierung liest ausschließlich Umgebungsvariablen, damit weder
Keystore noch Passwort je im Repository landen:

| Variable | Bedeutung |
|---|---|
| `DIVIDO_KEYSTORE_PATH` | Pfad zur `.jks` |
| `DIVIDO_KEYSTORE_PASSWORD` | Passwort des Keystores |
| `DIVIDO_KEY_ALIAS` | Alias, Vorgabe `divido-upload` |

Ohne gesetzte Variablen entsteht ein unsigniertes Release-Bundle, damit ein
einfaches `gradle build` überall funktioniert.

Google signiert die ausgelieferte App über Play App Signing mit einem eigenen
Schlüssel; der Upload-Key hier ist deshalb im Notfall zurücksetzbar.

## Herkunft

Modell und API-Verhalten sind aus der iOS-App portiert, einschließlich dreier
dort behobener Fehler: Kategorie und Zahlungsart überleben eine Bearbeitung,
Kommentare gehen nicht verloren, und ein eingegebener iHateMoney-Projektname
wird in die vom Server erwartete Projekt-ID übersetzt.
