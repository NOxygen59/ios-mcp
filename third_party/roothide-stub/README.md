# roothide.h (stub)

Copie des en-têtes de https://github.com/roothide/headers (`roothide.h`, `roothide/stub.h`, `roothide/roothide.h`).

Le Theos officiel ne fournit pas `roothide.h`. Pour les builds **rootful** et **rootless**, `build.sh`
ajoute ce dossier aux chemins d'inclusion : le stub redirige `jbroot()` / `rootfs()` vers `libroot`,
déjà fourni par Theos. Pour un build **roothide**, il faut le Theos de roothide
(https://github.com/roothide/theos), qui fournit la vraie `libroothide`.
