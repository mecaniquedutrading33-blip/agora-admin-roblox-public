# Hermes Token Drop Tool

Outil Windows pour envoyer des tokens/API keys a Hermes sans jamais les coller dans Discord.

## Contenu du zip

- `Add-HermesToken.ps1` — script PowerShell principal
- `Add-HermesToken.bat` — lanceur double-clic
- `README.md` — ce fichier

## Usage

1. Decompresse le `.zip` sur ton Bureau.
2. Double-clique sur `Add-HermesToken.bat`.
3. Dans le menu PowerShell :
   - `n` = ajouter un nouveau service (ex: `EMERICK_DISCORD_BOT_TOKEN`)
   - `1`, `2`, ... = renvoyer un token pour un service de l'historique
   - `e` = renommer un service
   - `d` = supprimer un service de l'historique
   - `q` = quitter
4. Colle le token quand il est demande (il reste masque a l'ecran).
5. Dis simplement dans Discord : `token envoye pour [NOM_DU_SERVICE]`.

## Securite

- Les tokens ne sont **jamais** sauvegardes sur le disque.
- L'historique local ne contient que les **noms de services** et la date.
- Les tokens transient chiffres en HTTPS vers l'Edge Function Supabase.
- Apres l'envoi, reset ton token cote Discord/GitHub si tu le souhaites.

## Historique local

Fichier : `%USERPROFILE%\.hermes\token-history.json`

Tu peux l'effacer manuellement a tout moment : cela supprimera seulement les noms, pas les tokens.
