# Security

## Reporting a vulnerability

Do not open a public issue for a security problem. Report it privately
through GitHub: [Report a vulnerability](https://github.com/hattoriai/koyomi/security/advisories/new).

Say what an attacker can do, and how: the picker, the type, the rule or
the event, and the steps or the payload. We answer within a week, agree
on a fix and a date, and credit you in the advisory unless you ask us
not to.

## Supported versions

Security fixes are made to the latest release. Koyomi is before 1.0, so
a fix is not backported to an earlier minor version.

## What is in scope

Koyomi's values reach your server as form params, and its hook sends
events to your LiveView; any person can craft both. A problem is in
scope when such a value or event can:

- pass `Koyomi.Changeset` or a Koyomi Ecto type although it breaks the
  rules given to it (a day out of bounds, a disabled day, a range that is
  too long);
- crash the LiveView or the process that casts it, or make the server do
  unbounded work: a range, a list of days, a recurrence rule or a
  `koyomi:days` request that is too large;
- run script in the page through what a picker shows, such as day labels
  and descriptions or translated messages.

What a person may choose is decided by the app: the rules a changeset
checks and the day content a LiveView returns are the app's job. What
the browser disables is a convenience, not a check: the server's rules
are the check (see the Rules guide).
