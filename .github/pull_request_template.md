## Why

<!-- The problem this solves, for whom, and what happened before it (an error, a wrong day, a value the changeset refused). -->

Fixes #<!-- the issue; see CONTRIBUTING.md for when a pull request needs one -->

## What

<!-- The change, in a few lines. -->

## How it was tested

<!-- The tests added, and what you ran by hand (the browsers, locales and time zones). -->

## Checklist

- [ ] One change: anything unrelated is in its own pull request.
- [ ] A bug fix has a test that fails on `main` and passes here.
- [ ] `mix format --check-formatted`, `mix compile --warnings-as-errors`, `mix credo --strict`, `mix docs`, `mix test` and `mix dialyzer` pass.
- [ ] `npm run typecheck` (in `assets/`) and `mix test.js` pass, for a change to `assets/`.
- [ ] `mix test.e2e` passes, for a change the browser sees.
- [ ] The guides and the `[Unreleased]` section of `CHANGELOG.md` are updated, for a change a user can see.
- [ ] Says so here if it changes the public API, or what a picker posts or does today.
- [ ] No changes to the version (the maintainers keep it).
