# iOS MCP (version française)

[中文](README.md) | [English](README_EN.md) | Français

Fork de [witchan/ios-mcp](https://github.com/witchan/ios-mcp) : un serveur [MCP](https://modelcontextprotocol.io)
qui tourne sur un iPhone/iPad **jailbreaké** et permet à un agent IA (Claude Code, Codex, Cursor…) de piloter
l'appareil : toucher l'écran, lire l'interface, faire des captures, installer/lancer des apps, lire les logs, etc.

## Ce qui change dans ce fork

- **Page Réglages en français** : affichée automatiquement si la langue de l'appareil est le français.
- **Jeton d'accès (nouveau)** : à activer dans *Réglages → iOS MCP → Jeton d'accès*. Une fois activé, toute requête
  (sauf `/health`) doit envoyer `Authorization: Bearer <jeton>` (ou `X-iOS-MCP-Token: <jeton>`).
  Sans ça, n'importe quel appareil sur ton Wi-Fi peut contrôler l'iPad et lancer des commandes shell.
- **Bouton « Copier la commande Claude Code »** : copie la commande `claude mcp add …` prête à coller
  (avec le jeton si l'authentification est activée).
- **OCR sans PaddleOCR** : si le moteur PaddleOCR n'est pas installé, l'OCR passe automatiquement sur Apple Vision.
- **`build.sh` en français**, utilisable sans questions (`./build.sh rootless release`), fonctionne même si le
  chemin du projet contient des espaces, et construit sans PaddleOCR si son runtime est absent.

## Outils disponibles (46)

| Catégorie | Outils |
|---|---|
| Toucher | `tap_screen` `swipe_screen` `long_press` `double_tap` `drag_and_drop` |
| Boutons | `press_home` `press_power` `press_volume_up` `press_volume_down` `toggle_mute` `wake_and_home` |
| Texte | `input_text` `type_text` `press_key` |
| Écran | `screenshot` `get_screen_info` `describe_screen` `get_ui_elements` `get_element_at_point` `tap_element` `wait_for_element` `wait_for_disappear` `ocr_screen` |
| Apps | `launch_app` `kill_app` `list_apps` `list_running_apps` `get_frontmost_app` `get_app_info` `install_app` `uninstall_app` |
| Fichiers | `list_dir` `read_file` `write_file` |
| Logs | `get_syslog` `get_crash_logs` `read_crash_log` |
| Divers | `get_clipboard` `set_clipboard` `get_brightness` `set_brightness` `get_volume` `set_volume` `get_device_info` `open_url` `run_command` |

Les descriptions des outils restent en anglais : elles sont lues par l'IA, pas affichées à l'utilisateur.

## Prérequis

- iPad/iPhone jailbreaké, avec ElleKit/Substrate et PreferenceLoader.

| Jailbreak | iOS | Architecture du paquet |
|---|---|---|
| rootful | 13 – 18 | `iphoneos-arm` |
| rootless (Dopamine, palera1n rootless) | 15 – 18 | `iphoneos-arm64` |
| roothide | 15 – 18 | `iphoneos-arm64e` |

## Compiler

Il faut [Theos](https://theos.dev) (`~/theos` par défaut) :

```bash
./build.sh rootless release
```

Le `.deb` arrive dans `packages/`. Remarques :

- `libzip` pour iOS (nécessaire à `mcp-appinst` et `mcp-roothelper`) est compilée automatiquement au premier build par `scripts/build_libzip_ios.sh` (il faut `cmake` et `ninja`).
- Le build **roothide** nécessite le Theos de roothide (<https://github.com/roothide/theos>).
  Pour rootful/rootless, un stub de `roothide.h` est fourni dans `third_party/roothide-stub`.
- PaddleOCR est optionnel (voir [docs/PADDLEOCR.md](docs/PADDLEOCR.md)) ; sans lui, l'OCR utilise Apple Vision.

## Installer et vérifier

1. Copie le `.deb` sur l'iPad et installe-le (Sileo/Filza), ou :
   `scp packages/*.deb mobile@IP_IPAD:/var/mobile/ && ssh mobile@IP_IPAD sudo dpkg -i /var/mobile/*.deb`
2. Respring.
3. Ouvre `http://IP_IPAD:8090/health` : la réponse doit contenir `"status":"ok"`.

## Brancher Claude Code

Sur l'iPad : *Réglages → iOS MCP* → active **Exiger un jeton d'accès** → **Copier la commande Claude Code**.
Colle la commande dans un terminal sur le Mac ; elle ressemble à :

```bash
claude mcp add --transport http ios-mcp http://IP_IPAD:8090/mcp --header "Authorization: Bearer TON_JETON"
```

Ensuite, dans Claude Code, l'agent peut faire `describe_screen`, `screenshot`, `launch_app`, lire les logs de ton app
avec `get_syslog`, etc. Pour envoyer une IPA depuis le Mac :

```bash
curl -H "Authorization: Bearer TON_JETON" -H "X-Filename: MonApp.ipa" --data-binary @MonApp.ipa http://IP_IPAD:8090/upload_file
```

puis `install_app` avec le chemin renvoyé.

## Sécurité

- Active le jeton d'accès, et utilise le serveur seulement sur un réseau de confiance (pas de HTTPS).
- `run_command`, `read_file`, `write_file` et `/download_file` donnent un accès étendu à l'appareil.
- Quand l'appareil est verrouillé ou l'écran éteint, les outils interactifs sont bloqués.

## Licence

Code du projet sous licence MIT ([LICENSE](LICENSE)), auteur original : **witchan**.
Composants tiers sous leurs propres licences ([THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).
