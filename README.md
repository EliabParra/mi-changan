# Mi Changan — CS35 Plus Tracker

Personal tracker for the Changan CS35 Plus: mileage logs, reminders, service records and more.

> **Public repo.** Never push real credentials. See the [Secrets policy](#secrets-policy) below.

---

## Secrets policy

> ⚠️ **This is a public repository. Any secret committed here is immediately exposed.**

### Rules

1. **Never commit real credentials.** No Supabase URLs with real project refs, no anon keys, no service role keys, no API tokens — ever.
2. **`.env.json` is local-only.** It is listed in `.gitignore` and must never appear in a commit or PR diff.
3. **Use `.env.json.example` as the template.** Copy it and fill in your real values:

   ```bash
   cp .env.json.example .env.json
   # then edit .env.json with your real Supabase credentials
   ```

4. **CI/CD uses GitHub Secrets.** Upcoming CI workflows will inject credentials at build time via GitHub repository secrets — not via committed files.

### Keys required

| Key | Description |
|-----|-------------|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Public anon key (safe for client, never the service role key) |
| `APP_NAME` | Display name of the app |

These are passed to Flutter via `--dart-define-from-file=.env.json` at build/run time.

---

## Development setup

> Full onboarding guide coming in `docs/onboarding.md` (H1 milestone).

---

## License

MIT
