# Contributing to Koyomi

Thank you for helping. This page says what to open (an issue, a pull
request, or a security report), what a pull request needs, and what the
maintainers keep for themselves. How to build the bundle, run the
development server and run the tests is in the README, under
[Development](README.md#development).

## Questions, bugs and ideas

- **A bug.** Open an issue with the bug report form. The smallest picker
  that shows it (the component, its attributes and rules, and the field
  of the schema) is the most useful thing you can give, with the locale,
  the time zone and the browser.
- **An idea or a change of behaviour.** Open an issue with the feature
  request form, and say the problem before the solution.
- **A security problem.** Do not open an issue. See
  [SECURITY.md](SECURITY.md).

Search the open and closed issues first: the idea may already be planned,
or turned down for a reason given there. The known gaps are in
[BACKLOG.md](BACKLOG.md), and the known limits in the
[Known limits](guides/limits.md) guide.

## When a pull request needs an issue first

Open an issue, and agree on the change there, before a pull request that:

- adds a picker, an attribute, a rule, a preset, an Ecto type or a
  language of the words parser;
- changes what a picker posts, what a rule accepts, what a type casts, or
  the public API;
- changes the events and values between the hook and the LiveView;
- adds a dependency, in `mix.exs` or in `assets/`;
- touches many files, or needs a design decision.

A pull request does not need an issue when it is small and its reason is
plain from the diff: a typo, a broken link, a wrong sentence in a guide,
a holiday on the wrong day, or a bug fix with a test that fails without
it. When in doubt, open the issue: a short discussion costs less than a
pull request that is not merged.

A pull request with an issue says so: `Fixes #123` or `Closes #123`.

## A pull request

- **One change.** A fix, the guide for an unrelated case and a README
  edit are three pull requests. Each is reviewed, reverted and released
  on its own.
- **Why, not only what.** The description says the problem the change
  solves, for whom, and what happened before it: an error, a wrong day,
  a value the changeset refused. Say why a number was chosen when the
  change adds one.
- **Tests.** A bug fix has a test that fails on `main` and passes with
  the fix. A feature has tests of what it does, and of its errors. A rule
  that both the browser and the server check is tested on both sides.
- **Docs.** A change a user can see updates the guide it belongs to and
  the `[Unreleased]` section of [CHANGELOG.md](CHANGELOG.md).
- **The checks pass.** CI runs them; run them first:

  ```sh
  mix format --check-formatted
  mix compile --warnings-as-errors
  mix credo --strict
  mix docs
  mix test
  mix dialyzer
  ```

  The package compiles against the four files of the bundle in
  `priv/static`: run `mix koyomi.build` once first, as the README says.
  `mix precommit` runs most of the checks at once (it formats instead of
  checking the format). CI also runs the tests with the oldest Elixir,
  Phoenix and LiveView that Koyomi supports.

  A change to `assets/` also runs:

  ```sh
  (cd assets && npm run typecheck)
  mix test.js
  ```

  and a change the browser sees runs `mix test.e2e`, in Chromium,
  Firefox and WebKit.

The pull request template has these as a checklist.

## What the maintainers keep

- **Releases.** The version in `mix.exs` and `package.json`, the release
  headings of the changelog and the tags are changed by the maintainers,
  at a release.

## Style

Match the code around your change: its naming, its comments and the way
its guides are written. `mix format` and `mix credo --strict` settle the
rest.

## License

By contributing, you agree that your contribution is released under the
MIT License of the project (see [LICENSE](LICENSE)).
