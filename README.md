# php_uploadprogress_guard-builds

Binaires compilés du module [HOSTED-POWER/php_uploadprogress_guard](https://github.com/HOSTED-POWER/php_uploadprogress_guard)
v3.0.2 (commit `61ee07cd7bc7a254becc850ff12ce45eaf1a9d8a`), pour protéger contre PHP2Shell
(CVE-2026-109618, CVE-2026-109619) un PHP qui ne peut pas recevoir le correctif officiel : versions en
fin de vie (7.x, 8.0, 8.1) ou serveurs qu'on ne peut pas mettre à jour tout de suite.

Ce ne sont pas des binaires officiels. Ils ont été compilés depuis les sources du dépôt amont, après
relecture du code. Les binaires précompilés du dépôt amont (`dist/`) n'ont pas été utilisés.

**Le correctif PHP reste la seule protection complète.** Le module est une protection d'attente.

## Ce que fait le module

- Il détache le gestionnaire de progression d'envoi (upload progress) de la session.
- Il force `session.upload_progress.enabled` à 0 et le verrouille au niveau système. Un `.user.ini`, un
  `.htaccess` ou `ini_set()` ne peuvent pas le réactiver.
- Il remplace l'analyseur `multipart/form-data` de PHP par une copie corrigée. Cette copie s'arrête
  avant l'épuisement de la mémoire et répond 413, au lieu de laisser PHP planter.
- Sur un PHP déjà corrigé (8.2.35, 8.3.36, 8.4.27, 8.5.12 ou plus récent), il garde l'analyseur
  d'origine. Le détachement et le verrouillage restent actifs. On peut donc le laisser en place pendant
  la mise à jour de PHP.

## Ce qu'il ne couvre pas

D'après le dépôt amont, le module ne couvre que le chemin multipart, qui ne dépend pas de
l'application. Il ne protège pas contre :

- du code applicatif qui provoque une erreur fatale ou un dépassement mémoire (déclencheur de
  CVE-2026-109619 sous PHP-FPM) ;
- les avertissements de configuration émis avant le début de la requête : `php_value` dans un
  `.htaccess` sous mod_php, `PHP_VALUE` transmis à PHP-FPM par nginx ou `mod_proxy_fcgi` ;
- `fatal_error_backtraces` de PHP 8.5 : le mettre à 0.

En attendant le correctif, garder aussi les conseils de l'avis : `post_max_size` raisonnable, pas de
surcharge de configuration par requête qui émet un avertissement, pas de `RLIMIT_AS` ni `RLIMIT_DATA`.

## Binaires

Tous les fichiers sont pour Linux x86_64, PHP NTS (non thread-safe), le cas des paquets Debian, Ubuntu
(distribution et sury), remi, Plesk, cPanel et des images Docker officielles. Un PHP ZTS demande une
recompilation.

| Fichier | Branche PHP | Zend API | Compilé dans | glibc requise |
|---|---|---|---|---|
| `bin/hp_uploadprogress_guard-7.2.so` | 7.2 | 20170718 | `php:7.2-cli-stretch` (7.2.34) | 2.14 |
| `bin/hp_uploadprogress_guard-7.4.so` | 7.4 | 20190902 | `php:7.4-cli-buster` (7.4.33) | 2.14 |
| `bin/hp_uploadprogress_guard-8.0.so` | 8.0 | 20200930 | `php:8.0-cli-buster` (8.0.30) | 2.14 |
| `bin/hp_uploadprogress_guard-8.1.so` | 8.1 | 20210902 | `php:8.1-cli-buster` (8.1.20) | 2.14 |
| `bin/hp_uploadprogress_guard-8.2.so` | 8.2 | 20220829 | `php:8.2-cli-bullseye` (8.2.29) | 2.14 |
| `bin/hp_uploadprogress_guard-8.3.so` | 8.3 | 20230831 | `php:8.3-cli-bullseye` (8.3.24) | 2.14 |
| `bin/hp_uploadprogress_guard-8.4.so` | 8.4 | 20240924 | `php:8.4-cli-bullseye` (8.4.11) | 2.14 |
| `bin/hp_uploadprogress_guard-8.5.so` | 8.5 | 20250925 | `php:8.5-cli-bookworm` (8.5.11) | 2.14 |

Un fichier se charge sur n'importe quelle version de patch de sa branche : c'est le numéro de Zend API
qui compte, pas la version exacte. Une glibc 2.14 ou plus suffit : Debian 8+, Ubuntu 14.04+, RHEL et
Rocky 7+.

Vérifier les empreintes avant toute installation :

```sh
cd bin && sha256sum -c SHA256SUMS
```

## Installer

Dans les exemples, remplacer `7.4` par la branche visée. Installer le module sur **chaque branche PHP
utilisée** et pour **chaque mode d'exécution** (PHP-FPM, module Apache, CGI).

### 1. Essayer le chargement à blanc

Avant d'activer quoi que ce soit, vérifier que le fichier se charge sans erreur avec le PHP du
serveur :

```sh
LD_BIND_NOW=1 php7.4 -n -d extension="$PWD/bin/hp_uploadprogress_guard-7.4.so" --ri hp_uploadprogress_guard
```

La commande doit afficher l'état du module, sans avertissement. `LD_BIND_NOW=1` force la résolution de
tous les symboles au chargement : un fichier incompatible échoue ici plutôt qu'en production.

### 2a. Debian, Ubuntu (paquets distribution ou sury)

```sh
V=7.4
install -m 0644 bin/hp_uploadprogress_guard-$V.so "$(php$V -n -r 'echo PHP_EXTENSION_DIR;')/hp_uploadprogress_guard.so"
install -m 0644 conf/hp_uploadprogress_guard.ini /etc/php/$V/mods-available/hp_uploadprogress_guard.ini
phpenmod -v $V hp_uploadprogress_guard          # tous les modes ; ou -s fpm, -s apache2
systemctl restart php$V-fpm                     # si PHP-FPM
systemctl restart apache2                       # si mod_php : un rechargement ne suffit pas
```

### 2b. Rocky, RHEL (dépôt remi)

```sh
X=74
PHP=/opt/remi/php$X/root/usr/bin/php
install -m 0644 bin/hp_uploadprogress_guard-7.4.so "$($PHP -n -r 'echo PHP_EXTENSION_DIR;')/hp_uploadprogress_guard.so"
install -m 0644 conf/hp_uploadprogress_guard.ini /etc/opt/remi/php$X/php.d/40-hp_uploadprogress_guard.ini
systemctl restart php$X-php-fpm
```

### 2c. Autre installation (Plesk, PHP compilé à la main…)

Pour chaque binaire PHP (sous Plesk : `/opt/plesk/php/X.Y/bin/php`) :

1. Dossier des extensions : `<php> -n -r 'echo PHP_EXTENSION_DIR;'`. Y copier le fichier de la bonne
   branche sous le nom `hp_uploadprogress_guard.so`.
2. Dossier des `.ini` additionnels : `<php> --ini`, ligne « Scan for additional .ini files in ». Y
   copier `conf/hp_uploadprogress_guard.ini`.
3. Redémarrer le service qui exécute PHP (PHP-FPM de cette version, ou Apache).

## Vérifier

Sur la ligne de commande :

```sh
php7.4 --ri hp_uploadprogress_guard
```

Attendu sur un PHP non corrigé :

```
multipart/form-data handler replaced => yes
running PHP already carries the official fix => no
session.upload_progress handler detached => yes
session.upload_progress.enabled forced to 0 and locked (PHP_INI_SYSTEM) => yes
```

Sur un PHP corrigé, `handler replaced => no` et `already carries the official fix => yes` : c'est
normal, le module laisse l'analyseur d'origine.

La ligne de commande ne prouve pas que le serveur web a chargé le module. Vérifier aussi le processus
qui sert les pages :

```sh
grep -c hp_uploadprogress_guard /proc/$(systemctl show -p MainPID --value php7.4-fpm)/maps   # > 0
grep -c hp_uploadprogress_guard /proc/$(systemctl show -p MainPID --value apache2)/maps      # mod_php
```

Ou par une vraie requête : un fichier PHP temporaire contenant
`<?php echo var_export(ini_get('session.upload_progress.enabled'), true);` doit afficher `'0'`.
Le supprimer aussitôt.

Le README amont indique que `phpinfo()` continue d'afficher `On` : c'était vrai avant la v3. En v3.0.2,
la valeur affichée est bien `Off`.

Contrôler ensuite que les sites répondent et que les envois de fichiers fonctionnent.

## Retirer

```sh
phpdismod -v 7.4 hp_uploadprogress_guard        # Debian, Ubuntu ; ailleurs, supprimer le .ini
systemctl restart php7.4-fpm                    # et apache2 si mod_php
rm "$(php7.4 -n -r 'echo PHP_EXTENSION_DIR;')/hp_uploadprogress_guard.so"
```

## Option : refuser tout multipart

`hp_uploadprogress_guard.mode = block` dans le `.ini` refuse toute requête `multipart/form-data` avant
que PHP lise le corps (415). `hp_uploadprogress_guard.allow_ips` liste les clients exemptés. Tous les
envois de fichiers et formulaires multipart sont coupés : c'est un interrupteur d'urgence pour un
serveur attaqué qui ne peut pas être mis à jour.

## Compilation

- Une compilation par branche, dans l'image Docker officielle Debian la plus ancienne qui porte la
  branche (stretch pour 7.2, buster pour 7.4 à 8.1, bullseye pour 8.2 à 8.4, bookworm pour 8.5).
  `phpize && ./configure && make`, options par défaut. Aucun avertissement du compilateur.
- Script : `scripts/build.sh`. Exemple :
  `scripts/build.sh 7.4 7.4-cli-buster <clone amont>/src ./bin`.
- **Piège** : ne pas compiler dans les images `php:X.Y-cli` par défaut (Debian 13, glibc 2.41). Le
  fichier importe alors `__isoc23_strtoll@GLIBC_2.38` et refuse de se charger sur un système plus
  ancien (`version 'GLIBC_2.38' not found`). Le script contrôle la glibc requise avec `objdump -T` et
  échoue au-delà de 2.14.

## Tests effectués

- **Chargement et fonctionnement**, sur 27 images Docker officielles couvrant les huit branches, de
  7.2.34 à 8.5.11, versions corrigées comprises, avec et sans `LD_BIND_NOW=1`. Envoi multipart avec
  champs imbriqués, caractères accentués et fichier de 100 Ko : `$_POST` et `$_FILES` identiques avec
  et sans module. `ini_get` renvoie `'0'`. Aucune clé de progression n'est écrite en session.
- **Épuisement mémoire** (tests du dépôt amont, `test/oom-test.sh`) sur PHP non corrigé : sans
  module, épuisement mémoire ; avec, réponse 413 et la requête suivante passe. Aucun faux positif sur
  un gros champ légitime.
- **PHP corrigé** (8.2.35, 8.3.36, 8.4.27) : le module s'efface comme prévu. Les mêmes requêtes donnent
  alors un 500 de PHP, plus un 413.
- **Ubuntu 16.04** (glibc 2.23) : PHP 7.2.34, 7.4.15 et 8.0.2 compilés depuis les sources php.net,
  conformes.
- **En production** : PHP 7.2, 7.4 et 8.0 sous PHP-FPM, et 7.4 en mod_php, sur Ubuntu 16.04.
- **Non testé** : 8.5.12 (image amd64 pas encore publiée lors des tests). Le retrait repose sur le
  même code que pour 8.2.35, 8.3.36 et 8.4.27.

## Licence

Le module est publié par Hosted Power sous licence MIT. Le texte de la licence, avec sa mention de
droits d'auteur, est dans `LICENSE`. Ces binaires sont fournis sans garantie, comme le module.
