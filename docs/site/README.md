# Product website

GitHub Pages publishes `main:/docs` with `.nojekyll`. The homepage is `docs/index.html`; styles, language switching, and the app icon are in this directory. Screenshots reuse `docs/images/`.

The static site has no analytics, login form, payment processing, or dependency on a developer-operated backend. The copy button copies fictional demonstration digits only.

## Update the web guides

Edit the source Markdown guides, then regenerate and commit the HTML:

```bash
python3 -m pip install Markdown==3.9
python3 scripts/build-site.py
```

Generated pages:

- `docs/guide.html` / `docs/guide.en.html`
- `docs/install.html` / `docs/install.en.html`

To preview from the repository root:

```bash
python3 -m http.server 8765 --directory docs
```

Use relative asset paths so the site works under `/card-generator/`. Download links always point to the latest GitHub Release asset, while guide links stay on this website.
