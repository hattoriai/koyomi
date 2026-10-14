import { test } from "node:test";
import assert from "node:assert/strict";

import { parseDate, parseLanguages, type ParseMode, type ParseOptions, type ParseResult } from "../src/parse";
import { formatISO, formatTime, parseISO, timeOf } from "../src/iso";

// Monday 15 March 2027, and Saturday 20 March 2027.
const MONDAY = parseISO("2027-03-15")!;
const SATURDAY = parseISO("2027-03-20")!;

/** A result as text: "2027-03-15", "2027-03-15..2027-03-20", "2027-03-16T09:00", "T09:00", or null. */
function show(result: ParseResult | null): string | null {
  if (!result) return null;
  switch (result.kind) {
    case "date":
      return formatISO(result.day);
    case "range":
      return `${formatISO(result.from)}..${formatISO(result.to)}`;
    case "datetime":
      return `${formatISO(result.day)}T${formatTime(result.time)}`;
    case "time":
      return `T${formatTime(result.time)}`;
  }
}

function read(text: string, locale: string, mode: ParseMode, extra: Partial<ParseOptions> = {}): string | null {
  return show(parseDate(text, { locale, today: MONDAY, mode, ...extra }));
}

type Row = [text: string, expected: string | null];

function table(name: string, locale: string, mode: ParseMode, rows: Row[], extra: Partial<ParseOptions> = {}) {
  test(`${name} (${locale}, ${mode})`, () => {
    for (const [text, expected] of rows) {
      assert.equal(read(text, locale, mode, extra), expected, `${JSON.stringify(text)} in ${locale}, ${mode}`);
    }
  });
}

test("parseLanguages lists the word tables", () => {
  assert.deepEqual([...parseLanguages].sort(), ["de", "en", "es", "fr", "it", "ja", "nl", "pt"]);
});

table("English relative days", "en-GB", "date", [
  ["today", "2027-03-15"],
  ["Today", "2027-03-15"],
  ["  TODAY.  ", "2027-03-15"],
  ["tomorrow", "2027-03-16"],
  ["tmrw", "2027-03-16"],
  ["yesterday", "2027-03-14"],
  ["day after tomorrow", "2027-03-17"],
  ["the day after tomorrow", "2027-03-17"],
  ["day before yesterday", "2027-03-13"],
  ["in 3 days", "2027-03-18"],
  ["in three days", "2027-03-18"],
  ["in 3 weeks", "2027-04-05"],
  ["in a week", "2027-03-22"],
  ["in 2 months", "2027-05-15"],
  ["in 1 year", "2028-03-15"],
  ["in 2 quarters", "2027-09-15"],
  ["in 10d", "2027-03-25"],
  ["in 2w", "2027-03-29"],
  ["+3 days", "2027-03-18"],
  ["3 days from now", "2027-03-18"],
  ["3 days ago", "2027-03-12"],
  ["a week ago", "2027-03-08"],
  ["two months ago", "2027-01-15"],
  ["twelve days ago", "2027-03-03"],
  ["-3d", "2027-03-12"],
]);

table("English weekdays", "en-GB", "date", [
  ["friday", "2027-03-19"],
  ["fri", "2027-03-19"],
  ["Fri.", "2027-03-19"],
  ["thurs", "2027-03-18"],
  ["tues", "2027-03-16"],
  ["monday", "2027-03-15"],
  ["sunday", "2027-03-21"],
  ["this fri", "2027-03-19"],
  ["this friday", "2027-03-19"],
  ["next fri", "2027-03-26"],
  ["next friday", "2027-03-26"],
  ["next monday", "2027-03-22"],
  ["last monday", "2027-03-08"],
  ["last friday", "2027-03-12"],
  ["friday next", "2027-03-26"],
]);

table("English periods in date mode give their first day", "en-GB", "date", [
  ["next week", "2027-03-22"],
  ["this week", "2027-03-15"],
  ["last week", "2027-03-08"],
  ["next month", "2027-04-01"],
  ["this month", "2027-03-01"],
  ["last month", "2027-02-01"],
  ["next year", "2028-01-01"],
  ["last year", "2026-01-01"],
  ["this quarter", "2027-01-01"],
  ["next quarter", "2027-04-01"],
  ["end of month", "2027-03-31"],
  ["end of the month", "2027-03-31"],
  ["eom", "2027-03-31"],
  ["start of month", "2027-03-01"],
  ["beginning of next month", "2027-04-01"],
  ["end of next month", "2027-04-30"],
  ["end of week", "2027-03-21"],
  ["end of year", "2027-12-31"],
  ["end of february", "2028-02-29"],
  ["weekend", "2027-03-20"],
  ["this weekend", "2027-03-20"],
  ["next weekend", "2027-03-27"],
  ["last weekend", "2027-03-13"],
  ["march", "2027-03-01"],
  ["april 2027", "2027-04-01"],
  ["2028", "2028-01-01"],
  ["Q2", "2027-04-01"],
  ["next 7 days", "2027-03-15"],
  ["last 30 days", "2027-02-14"],
]);

table("English periods in range mode", "en-GB", "range", [
  ["next week", "2027-03-22..2027-03-28"],
  ["this week", "2027-03-15..2027-03-21"],
  ["last week", "2027-03-08..2027-03-14"],
  ["this month", "2027-03-01..2027-03-31"],
  ["next month", "2027-04-01..2027-04-30"],
  ["last month", "2027-02-01..2027-02-28"],
  ["this year", "2027-01-01..2027-12-31"],
  ["2027", "2027-01-01..2027-12-31"],
  ["march", "2027-03-01..2027-03-31"],
  ["february", "2028-02-01..2028-02-29"],
  ["march 2028", "2028-03-01..2028-03-31"],
  ["Q1", "2027-01-01..2027-03-31"],
  ["Q2", "2027-04-01..2027-06-30"],
  ["q4 2027", "2027-10-01..2027-12-31"],
  ["2026 Q3", "2026-07-01..2026-09-30"],
  ["2027-Q1", "2027-01-01..2027-03-31"],
  ["this quarter", "2027-01-01..2027-03-31"],
  ["next 7 days", "2027-03-15..2027-03-21"],
  ["next 2 weeks", "2027-03-15..2027-03-28"],
  ["next 3 months", "2027-03-15..2027-06-14"],
  ["last 30 days", "2027-02-14..2027-03-15"],
  ["past 7 days", "2027-03-09..2027-03-15"],
  ["last 2 weeks", "2027-03-02..2027-03-15"],
  ["this weekend", "2027-03-20..2027-03-21"],
  ["weekend", "2027-03-20..2027-03-21"],
  ["next weekend", "2027-03-27..2027-03-28"],
  ["2027-W11", "2027-03-15..2027-03-21"],
  ["2027W12", "2027-03-22..2027-03-28"],
  ["week 1", "2027-01-04..2027-01-10"],
  ["2027-W53", null],
  ["tomorrow", "2027-03-16"],
  ["end of month", "2027-03-31"],
  ["friday", "2027-03-19"],
]);

table("English explicit ranges", "en-GB", "range", [
  ["15–20 mar", "2027-03-15..2027-03-20"],
  ["15-20 March", "2027-03-15..2027-03-20"],
  ["15 - 20 March", "2027-03-15..2027-03-20"],
  ["mar 15–20", "2027-03-15..2027-03-20"],
  ["mar 15 to apr 2", "2027-03-15..2027-04-02"],
  ["from 15 mar to 2 apr", "2027-03-15..2027-04-02"],
  ["between 1 apr and 3 apr", "2027-04-01..2027-04-03"],
  ["1 apr until 3 apr", "2027-04-01..2027-04-03"],
  ["15 mar – 20 mar", "2027-03-15..2027-03-20"],
  ["15/3 - 20/3", "2027-03-15..2027-03-20"],
  ["15/3/2027 - 20/3/2027", "2027-03-15..2027-03-20"],
  ["2027-03-15 - 2027-03-20", "2027-03-15..2027-03-20"],
  ["2027-03-15 – 2027-04-20", "2027-03-15..2027-04-20"],
  ["dec 20 - jan 5", "2027-12-20..2028-01-05"],
  ["march to may", "2027-03-01..2027-05-31"],
  ["nov – feb", "2027-11-01..2028-02-29"],
  ["mon to fri", "2027-03-15..2027-03-19"],
  ["today to friday", "2027-03-15..2027-03-19"],
  ["tomorrow until next friday", "2027-03-16..2027-03-26"],
  ["today - end of month", "2027-03-15..2027-03-31"],
  ["15-20", "2027-03-15..2027-03-20"],
  ["15–2 mar", null],
  ["20 mar - 15 mar 2027", null],
  ["2027-03-20 - 2027-03-15", null],
  ["15 mar to garbage", null],
]);

table("Explicit ranges are only read in range mode", "en-GB", "date", [
  ["15–20 mar", null],
  ["mar 15 to apr 2", null],
]);

table("English written dates", "en-GB", "date", [
  ["15 mar", "2027-03-15"],
  ["15 March", "2027-03-15"],
  ["March 15th", "2027-03-15"],
  ["15th of March", "2027-03-15"],
  ["the 15th of march, 2028", "2028-03-15"],
  ["mar 15", "2027-03-15"],
  ["Mar. 16", "2027-03-16"],
  ["sept 3", "2027-09-03"],
  ["September 3rd 2026", "2026-09-03"],
  ["14 mar", "2028-03-14"],
  ["1 jan", "2028-01-01"],
  ["15 mar 28", "2028-03-15"],
  ["mar 15 28", "2028-03-15"],
  ["15 28 mar", null],
  ["Friday 19 March", "2027-03-19"],
  ["Fri, March 19, 2027", "2027-03-19"],
  ["Friday 18 March", null],
  ["the 15th", "2027-03-15"],
  ["the 10th", "2027-04-10"],
  ["the 31st", "2027-03-31"],
  ["22nd", "2027-03-22"],
  ["15", "2027-03-15"],
  ["29 feb", "2028-02-29"],
  ["31 April", null],
  ["April 31", null],
  ["32 march", null],
  ["2027-03-15", "2027-03-15"],
  ["2027-3-5", "2027-03-05"],
  ["2027/03/15", "2027-03-15"],
  ["2027-03", "2027-03-01"],
  ["03/2027", "2027-03-01"],
  ["2027-02-29", null],
  ["2028-02-29", "2028-02-29"],
  ["2027-13-01", null],
]);

test("numeric dates follow the locale's order", () => {
  assert.equal(read("3/4/2027", "en-GB", "date"), "2027-04-03");
  assert.equal(read("3/4/2027", "en-US", "date"), "2027-03-04");
  assert.equal(read("3/4", "en-GB", "date"), "2027-04-03");
  assert.equal(read("3/4", "en-US", "date"), "2028-03-04");
  assert.equal(read("15/3/2027", "en-US", "date"), null);
  assert.equal(read("3/15/2027", "en-US", "date"), "2027-03-15");
  assert.equal(read("3/15/2027", "en-GB", "date"), null);
  assert.equal(read("15.3.2027", "de", "date"), "2027-03-15");
  assert.equal(read("15.03.27", "de", "date"), "2027-03-15");
  assert.equal(read("15.3.", "de", "date"), "2027-03-15");
  assert.equal(read("15-3-2027", "pt-PT", "date"), "2027-03-15");
  assert.equal(read("15 3 2027", "en-GB", "date"), "2027-03-15");
  assert.equal(read("15/3 2027", "en-GB", "date"), null);
  assert.equal(read("2027/3/4", "ja", "date"), "2027-03-04");
  assert.equal(read("3/4", "ja", "date"), "2028-03-04");
  assert.equal(read("2027/3/4", "en-GB", "date"), "2027-03-04");
  assert.equal(read("27/3/4", "ja", "date"), "2027-03-04");
  assert.equal(read("4/3/2027", "fr", "date"), "2027-03-04");
  assert.equal(read("4/3/2027", "nl", "date"), "2027-03-04");
});

test("two-digit years are within fifty years of today's", () => {
  assert.equal(read("1/1/80", "en-US", "date"), "1980-01-01");
  assert.equal(read("1/1/77", "en-US", "date"), "2077-01-01");
  assert.equal(read("1/1/78", "en-US", "date"), "1978-01-01");
  assert.equal(read("1/1/00", "en-US", "date"), "2000-01-01");
  assert.equal(read("15/3/27", "en-GB", "date"), "2027-03-15");
  assert.equal(read("15/3/027", "en-GB", "date"), null);
});

table("Portuguese", "pt-PT", "date", [
  ["hoje", "2027-03-15"],
  ["amanhã", "2027-03-16"],
  ["amanha", "2027-03-16"],
  ["ontem", "2027-03-14"],
  ["depois de amanhã", "2027-03-17"],
  ["anteontem", "2027-03-13"],
  ["daqui a 3 dias", "2027-03-18"],
  ["em 3 dias", "2027-03-18"],
  ["em duas semanas", "2027-03-29"],
  ["dentro de um mês", "2027-04-15"],
  ["há 3 dias", "2027-03-12"],
  ["ha 3 dias", "2027-03-12"],
  ["3 dias atrás", "2027-03-12"],
  ["sexta", "2027-03-19"],
  ["sexta-feira", "2027-03-19"],
  ["sexta feira", "2027-03-19"],
  ["sábado", "2027-03-20"],
  ["sexta que vem", "2027-03-26"],
  ["próxima sexta", "2027-03-26"],
  ["na próxima sexta-feira", "2027-03-26"],
  ["segunda passada", "2027-03-08"],
  ["esta sexta", "2027-03-19"],
  ["semana que vem", "2027-03-22"],
  ["a próxima semana", "2027-03-22"],
  ["mês que vem", "2027-04-01"],
  ["no próximo mês", "2027-04-01"],
  ["ano passado", "2026-01-01"],
  ["fim do mês", "2027-03-31"],
  ["fim do mês que vem", "2027-04-30"],
  ["início do ano", "2027-01-01"],
  ["fim de semana", "2027-03-20"],
  ["próximo fim de semana", "2027-03-27"],
  ["15 de março", "2027-03-15"],
  ["15 de março de 2027", "2027-03-15"],
  ["15 mar", "2027-03-15"],
  ["1 de setembro", "2027-09-01"],
  ["dia 20", "2027-03-20"],
  ["15/03/2027", "2027-03-15"],
  ["Q3", "2027-07-01"],
]);

table("Portuguese (Brazil)", "pt-BR", "date", [
  ["sex", "2027-03-19"],
  ["qua", "2027-03-17"],
  ["sexta que vem", "2027-03-26"],
  ["15 de março", "2027-03-15"],
  ["daqui a 2 semanas", "2027-03-29"],
]);

table("Portuguese ranges", "pt-PT", "range", [
  ["de 15 a 20 de março", "2027-03-15..2027-03-20"],
  ["15 a 20 de março", "2027-03-15..2027-03-20"],
  ["entre 1 e 3 de abril", "2027-04-01..2027-04-03"],
  ["de hoje até sexta", "2027-03-15..2027-03-19"],
  ["próximos 7 dias", "2027-03-15..2027-03-21"],
  ["os últimos 30 dias", "2027-02-14..2027-03-15"],
  ["semana que vem", "2027-03-22..2027-03-28"],
  ["este mês", "2027-03-01..2027-03-31"],
  ["este fim de semana", "2027-03-20..2027-03-21"],
  ["março", "2027-03-01..2027-03-31"],
]);

table("Portuguese times", "pt-PT", "datetime", [
  ["amanhã às 9h", "2027-03-16T09:00"],
  ["amanhã às 21h30", "2027-03-16T21:30"],
  ["sexta às 14:30", "2027-03-19T14:30"],
  ["amanhã ao meio-dia", "2027-03-16T12:00"],
  ["hoje à meia-noite", "2027-03-15T00:00"],
  ["amanhã às 9 da noite", "2027-03-16T21:00"],
  ["daqui a 2 horas", "2027-03-15T02:00"],
  ["amanhã", "2027-03-16"],
]);

table("Spanish", "es", "date", [
  ["hoy", "2027-03-15"],
  ["mañana", "2027-03-16"],
  ["ayer", "2027-03-14"],
  ["pasado mañana", "2027-03-17"],
  ["anteayer", "2027-03-13"],
  ["en 3 días", "2027-03-18"],
  ["dentro de dos semanas", "2027-03-29"],
  ["hace 3 días", "2027-03-12"],
  ["viernes", "2027-03-19"],
  ["el viernes que viene", "2027-03-26"],
  ["el próximo viernes", "2027-03-26"],
  ["el lunes pasado", "2027-03-08"],
  ["este viernes", "2027-03-19"],
  ["la semana que viene", "2027-03-22"],
  ["el mes que viene", "2027-04-01"],
  ["fin de mes", "2027-03-31"],
  ["fin de semana", "2027-03-20"],
  ["15 de marzo", "2027-03-15"],
  ["15 mar", "2027-03-15"],
  ["mar", "2027-03-16"],
  ["15 de marzo de 2028", "2028-03-15"],
]);

table("Spanish ranges and times", "es", "range", [
  ["del 15 al 20 de marzo", "2027-03-15..2027-03-20"],
  ["de 15 a 20 de marzo", "2027-03-15..2027-03-20"],
  ["entre el 1 y el 3 de abril", "2027-04-01..2027-04-03"],
  ["los próximos 7 días", "2027-03-15..2027-03-21"],
  ["los últimos 30 días", "2027-02-14..2027-03-15"],
  ["fin de semana que viene", "2027-03-27..2027-03-28"],
]);

table("Spanish datetimes", "es", "datetime", [
  ["mañana a las 9", "2027-03-16T09:00"],
  ["viernes a las 14:30", "2027-03-19T14:30"],
  ["mañana a las 9 de la noche", "2027-03-16T21:00"],
  ["hoy a mediodía", null],
  ["mañana mediodía", "2027-03-16T12:00"],
]);

table("French", "fr", "date", [
  ["aujourd'hui", "2027-03-15"],
  ["aujourd’hui", "2027-03-15"],
  ["demain", "2027-03-16"],
  ["hier", "2027-03-14"],
  ["après-demain", "2027-03-17"],
  ["avant-hier", "2027-03-13"],
  ["dans 3 jours", "2027-03-18"],
  ["dans deux semaines", "2027-03-29"],
  ["il y a 3 jours", "2027-03-12"],
  ["vendredi", "2027-03-19"],
  ["vendredi prochain", "2027-03-26"],
  ["lundi dernier", "2027-03-08"],
  ["ce vendredi", "2027-03-19"],
  ["la semaine prochaine", "2027-03-22"],
  ["le mois prochain", "2027-04-01"],
  ["l'année prochaine", "2028-01-01"],
  ["fin de mois", "2027-03-31"],
  ["fin du mois", "2027-03-31"],
  ["début de l'année", "2027-01-01"],
  ["ce week-end", "2027-03-20"],
  ["15 mars", "2027-03-15"],
  ["le 15 mars 2027", "2027-03-15"],
  ["1er avril", "2027-04-01"],
  ["mar", "2027-03-16"],
  ["15 mar", "2027-03-15"],
  ["févr.", "2028-02-01"],
]);

table("French ranges", "fr", "range", [
  ["du 15 au 20 mars", "2027-03-15..2027-03-20"],
  ["entre le 1 et le 3 avril", "2027-04-01..2027-04-03"],
  ["entre 1 et 3 avril", "2027-04-01..2027-04-03"],
  ["les 7 derniers jours", "2027-03-09..2027-03-15"],
  ["les 7 prochains jours", "2027-03-15..2027-03-21"],
  ["la semaine prochaine", "2027-03-22..2027-03-28"],
]);

table("French times", "fr", "datetime", [
  ["demain à 14h", "2027-03-16T14:00"],
  ["demain 21h30", "2027-03-16T21:30"],
  ["vendredi à midi", "2027-03-19T12:00"],
  ["demain à 8h du soir", "2027-03-16T20:00"],
]);

table("German", "de", "date", [
  ["heute", "2027-03-15"],
  ["morgen", "2027-03-16"],
  ["gestern", "2027-03-14"],
  ["übermorgen", "2027-03-17"],
  ["vorgestern", "2027-03-13"],
  ["in 3 Tagen", "2027-03-18"],
  ["in einer Woche", "2027-03-22"],
  ["in zwei Monaten", "2027-05-15"],
  ["vor 3 Tagen", "2027-03-12"],
  ["Freitag", "2027-03-19"],
  ["nächsten Freitag", "2027-03-26"],
  ["letzten Montag", "2027-03-08"],
  ["diesen Freitag", "2027-03-19"],
  ["nächste Woche", "2027-03-22"],
  ["nächsten Monat", "2027-04-01"],
  ["nächstes Jahr", "2028-01-01"],
  ["Monatsende", "2027-03-31"],
  ["Ende des Monats", "2027-03-31"],
  ["Ende nächsten Monats", "2027-04-30"],
  ["Jahresanfang", "2027-01-01"],
  ["Wochenende", "2027-03-20"],
  ["nächstes Wochenende", "2027-03-27"],
  ["15. März", "2027-03-15"],
  ["am 15. März 2027", "2027-03-15"],
  ["15.3.2027", "2027-03-15"],
  ["KW 12", "2027-03-22"],
]);

table("German ranges", "de", "range", [
  ["vom 15. bis 20. März", "2027-03-15..2027-03-20"],
  ["15. bis 20. März", "2027-03-15..2027-03-20"],
  ["zwischen 1. und 3. April", "2027-04-01..2027-04-03"],
  ["die nächsten 7 Tage", "2027-03-15..2027-03-21"],
  ["die letzten 30 Tage", "2027-02-14..2027-03-15"],
  ["nächste Woche", "2027-03-22..2027-03-28"],
]);

table("German times", "de", "datetime", [
  ["morgen um 9 Uhr", "2027-03-16T09:00"],
  ["morgen um 9", "2027-03-16T09:00"],
  ["Freitag um 14:30", "2027-03-19T14:30"],
  ["morgen 14:30 Uhr", "2027-03-16T14:30"],
  ["morgen um Mitternacht", "2027-03-16T00:00"],
]);

table("Italian", "it", "date", [
  ["oggi", "2027-03-15"],
  ["domani", "2027-03-16"],
  ["ieri", "2027-03-14"],
  ["dopodomani", "2027-03-17"],
  ["l'altro ieri", "2027-03-13"],
  ["tra 3 giorni", "2027-03-18"],
  ["fra tre settimane", "2027-04-05"],
  ["3 giorni fa", "2027-03-12"],
  ["venerdì", "2027-03-19"],
  ["venerdi prossimo", "2027-03-26"],
  ["venerdì prossimo", "2027-03-26"],
  ["lunedì scorso", "2027-03-08"],
  ["questo venerdì", "2027-03-19"],
  ["la settimana prossima", "2027-03-22"],
  ["il mese prossimo", "2027-04-01"],
  ["l'anno scorso", "2026-01-01"],
  ["fine mese", "2027-03-31"],
  ["fine del mese", "2027-03-31"],
  ["questo fine settimana", "2027-03-20"],
  ["15 marzo", "2027-03-15"],
  ["il 15 marzo 2027", "2027-03-15"],
]);

table("Italian ranges and times", "it", "range", [
  ["dal 15 al 20 marzo", "2027-03-15..2027-03-20"],
  ["i prossimi 7 giorni", "2027-03-15..2027-03-21"],
  ["gli ultimi 30 giorni", "2027-02-14..2027-03-15"],
  ["quest'anno", "2027-01-01..2027-12-31"],
]);

table("Italian datetimes", "it", "datetime", [
  ["domani alle 9", "2027-03-16T09:00"],
  ["venerdì alle 14:30", "2027-03-19T14:30"],
  ["domani a mezzogiorno", "2027-03-16T12:00"],
]);

table("Dutch", "nl", "date", [
  ["vandaag", "2027-03-15"],
  ["morgen", "2027-03-16"],
  ["gisteren", "2027-03-14"],
  ["overmorgen", "2027-03-17"],
  ["eergisteren", "2027-03-13"],
  ["over 3 dagen", "2027-03-18"],
  ["over twee weken", "2027-03-29"],
  ["3 dagen geleden", "2027-03-12"],
  ["vrijdag", "2027-03-19"],
  ["volgende vrijdag", "2027-03-26"],
  ["vorige maandag", "2027-03-08"],
  ["deze vrijdag", "2027-03-19"],
  ["volgende week", "2027-03-22"],
  ["volgende maand", "2027-04-01"],
  ["vorig jaar", "2026-01-01"],
  ["eind van de maand", "2027-03-31"],
  ["dit weekend", "2027-03-20"],
  ["15 maart", "2027-03-15"],
  ["15 maart 2027", "2027-03-15"],
  ["15 mrt", "2027-03-15"],
]);

table("Dutch ranges and times", "nl", "range", [
  ["van 15 tot 20 maart", "2027-03-15..2027-03-20"],
  ["15 t/m 20 maart", "2027-03-15..2027-03-20"],
  ["de komende 7 dagen", "2027-03-15..2027-03-21"],
  ["de afgelopen 30 dagen", "2027-02-14..2027-03-15"],
]);

table("Dutch datetimes", "nl", "datetime", [
  ["morgen om 9", "2027-03-16T09:00"],
  ["vrijdag om 14:30", "2027-03-19T14:30"],
  ["morgen om middernacht", "2027-03-16T00:00"],
]);

table("Japanese", "ja", "date", [
  ["今日", "2027-03-15"],
  ["明日", "2027-03-16"],
  ["あした", "2027-03-16"],
  ["昨日", "2027-03-14"],
  ["明後日", "2027-03-17"],
  ["一昨日", "2027-03-13"],
  ["3日後", "2027-03-18"],
  ["三日後", "2027-03-18"],
  ["3日前", "2027-03-12"],
  ["3週間後", "2027-04-05"],
  ["2ヶ月後", "2027-05-15"],
  ["1年前", "2026-03-15"],
  ["金曜日", "2027-03-19"],
  ["金曜", "2027-03-19"],
  ["金", "2027-03-19"],
  ["来週の金曜日", "2027-03-26"],
  ["先週の月曜日", "2027-03-08"],
  ["今週の金曜日", "2027-03-19"],
  ["来週", "2027-03-22"],
  ["来月", "2027-04-01"],
  ["今月", "2027-03-01"],
  ["先月", "2027-02-01"],
  ["来年", "2028-01-01"],
  ["去年", "2026-01-01"],
  ["月末", "2027-03-31"],
  ["来月末", "2027-04-30"],
  ["年末", "2027-12-31"],
  ["週末", "2027-03-20"],
  ["2027年3月15日", "2027-03-15"],
  ["2028年3月15日", "2028-03-15"],
  ["3月15日", "2027-03-15"],
  ["３月１６日", "2027-03-16"],
  ["2027年4月", "2027-04-01"],
  ["2027/3/15", "2027-03-15"],
  ["2027年2月30日", null],
]);

table("Japanese ranges", "ja", "range", [
  ["3月15日〜20日", "2027-03-15..2027-03-20"],
  ["3月15日~20日", "2027-03-15..2027-03-20"],
  ["3月15日から20日まで", "2027-03-15..2027-03-20"],
  ["来週", "2027-03-22..2027-03-28"],
  ["今月", "2027-03-01..2027-03-31"],
  ["過去30日間", "2027-02-14..2027-03-15"],
  ["今週末", "2027-03-20..2027-03-21"],
]);

table("Japanese times", "ja", "datetime", [
  ["明日の午前9時", "2027-03-16T09:00"],
  ["明日9時", "2027-03-16T09:00"],
  ["明日の午後3時半", "2027-03-16T15:30"],
  ["金曜日15時30分", "2027-03-19T15:30"],
  ["明日の正午", "2027-03-16T12:00"],
  ["2時間後", "2027-03-15T02:00"],
]);

test("Chinese dates through Intl and the shared markers", () => {
  assert.equal(read("2027年3月15日", "zh-CN", "date"), "2027-03-15");
  assert.equal(read("三月", "zh-CN", "range"), "2027-03-01..2027-03-31");
  assert.equal(read("tomorrow", "zh-CN", "date"), "2027-03-16");
});

test("English is accepted in every locale, after the locale's own words", () => {
  assert.equal(read("tomorrow", "pt-PT", "date"), "2027-03-16");
  assert.equal(read("next friday", "de", "date"), "2027-03-26");
  assert.equal(read("15 mar to 20 mar", "pt-PT", "range"), "2027-03-15..2027-03-20");
  assert.equal(read("in 3 days", "ja", "date"), "2027-03-18");
  // German morgen is tomorrow before English could see it.
  assert.equal(read("morgen", "de", "date"), "2027-03-16");
  // Names in another language than the locale and English are not known.
  assert.equal(read("15 maart", "en-GB", "date"), null);
  assert.equal(read("15 maart", "nl-BE", "date"), "2027-03-15");
});

table("Times", "en-GB", "time", [
  ["9am", "T09:00"],
  ["9 am", "T09:00"],
  ["9 a.m.", "T09:00"],
  ["9:30pm", "T21:30"],
  ["9:30 PM", "T21:30"],
  ["12am", "T00:00"],
  ["12pm", "T12:00"],
  ["12:15am", "T00:15"],
  ["21:30", "T21:30"],
  ["21:30:15", "T21:30"],
  ["07:05", "T07:05"],
  ["21.30", "T21:30"],
  ["21h30", "T21:30"],
  ["21h", "T21:00"],
  ["9h30", "T09:30"],
  ["9", "T09:00"],
  ["at 9", "T09:00"],
  ["noon", "T12:00"],
  ["midnight", "T00:00"],
  ["now", "T00:00"],
  ["13pm", null],
  ["24:00", null],
  ["9:60", null],
  ["9:5", null],
  ["tomorrow", null],
  ["tomorrow 9am", null],
]);

test("times in each language's words", () => {
  const cases: [string, string, string][] = [
    ["pt-PT", "meio-dia", "T12:00"],
    ["pt-PT", "meia-noite", "T00:00"],
    ["pt-PT", "9h", "T09:00"],
    ["es", "mediodía", "T12:00"],
    ["es", "medianoche", "T00:00"],
    ["fr", "midi", "T12:00"],
    ["fr", "minuit", "T00:00"],
    ["de", "Mittag", "T12:00"],
    ["de", "Mitternacht", "T00:00"],
    ["de", "9 Uhr", "T09:00"],
    ["de", "9 Uhr 30", "T09:30"],
    ["it", "mezzogiorno", "T12:00"],
    ["it", "mezzanotte", "T00:00"],
    ["nl", "middag", "T12:00"],
    ["nl", "middernacht", "T00:00"],
    ["ja", "正午", "T12:00"],
    ["ja", "午前9時", "T09:00"],
    ["ja", "午後3時半", "T15:30"],
    ["ja", "15時30分", "T15:30"],
    ["ja", "午前0時", "T00:00"],
  ];
  for (const [locale, text, expected] of cases) assert.equal(read(text, locale, "time"), expected, `${text} in ${locale}`);
});

table("English datetimes", "en-GB", "datetime", [
  ["tomorrow 9am", "2027-03-16T09:00"],
  ["tomorrow at 9am", "2027-03-16T09:00"],
  ["tomorrow at 9", "2027-03-16T09:00"],
  ["tomorrow 9", null],
  ["fri at 14:30", "2027-03-19T14:30"],
  ["next friday 6pm", "2027-03-26T18:00"],
  ["15 mar 21:30", "2027-03-15T21:30"],
  ["2027-03-15 21:30", "2027-03-15T21:30"],
  ["9am tomorrow", "2027-03-16T09:00"],
  ["at 9am on friday", "2027-03-19T09:00"],
  ["tomorrow at noon", "2027-03-16T12:00"],
  ["9am", "2027-03-15T09:00"],
  ["at 5", "2027-03-15T05:00"],
  ["tomorrow", "2027-03-16"],
  ["next week", "2027-03-22"],
  ["in 3 days at 8am", "2027-03-18T08:00"],
  ["tomorrow at 25:00", null],
]);

test("hours and minutes count from now and cross midnight", () => {
  const late = { now: timeOf(23, 30) };
  assert.equal(read("in 2 hours", "en-GB", "datetime", late), "2027-03-16T01:30");
  assert.equal(read("in 30 minutes", "en-GB", "datetime", late), "2027-03-16T00:00");
  assert.equal(read("in 15 min", "en-GB", "datetime", late), "2027-03-15T23:45");
  assert.equal(read("now", "en-GB", "datetime", late), "2027-03-15T23:30");
  assert.equal(read("in 2 hours", "en-GB", "date", late), "2027-03-16");
  assert.equal(read("in 2 hours", "en-GB", "time", late), "T01:30");
  assert.equal(read("in 2 hours", "en-GB", "range", late), "2027-03-16");
  assert.equal(read("in 26 hours", "en-GB", "datetime", late), "2027-03-17T01:30");
  const early = { now: timeOf(0, 10) };
  assert.equal(read("30 minutes ago", "en-GB", "datetime", early), "2027-03-14T23:40");
  assert.equal(read("2 hours ago", "en-GB", "datetime", early), "2027-03-14T22:10");
  assert.equal(read("daqui a 2 horas", "pt-PT", "datetime", late), "2027-03-16T01:30");
  assert.equal(read("in 2 Stunden", "de", "datetime", late), "2027-03-16T01:30");
  assert.equal(read("dans 2 heures", "fr", "datetime", late), "2027-03-16T01:30");
  assert.equal(read("2時間後", "ja", "datetime", late), "2027-03-16T01:30");
  assert.equal(read("in 2 hours", "en-GB", "datetime"), "2027-03-15T02:00");
});

test("month, week and year modes give a day inside the period", () => {
  assert.equal(read("next month", "en-GB", "month"), "2027-04-01");
  assert.equal(read("march", "en-GB", "month"), "2027-03-01");
  assert.equal(read("15 april", "en-GB", "month"), "2027-04-15");
  assert.equal(read("2027-05", "en-GB", "month"), "2027-05-01");
  assert.equal(read("next week", "en-GB", "week"), "2027-03-22");
  assert.equal(read("2027-W20", "en-GB", "week"), "2027-05-17");
  assert.equal(read("friday", "en-GB", "week"), "2027-03-19");
  assert.equal(read("2030", "en-GB", "year"), "2030-01-01");
  assert.equal(read("next year", "en-GB", "year"), "2028-01-01");
  assert.equal(read("Q3", "en-GB", "dates"), "2027-07-01");
  assert.equal(read("tomorrow", "en-GB", "dates"), "2027-03-16");
});

test("direction resolves dates without a year", () => {
  const dir = (text: string, direction: "future" | "past" | "nearest", today = MONDAY, mode: ParseMode = "date") =>
    show(parseDate(text, { locale: "en-GB", today, mode, direction }));
  // On or after today, on or before today, the closest.
  assert.equal(dir("15 mar", "future"), "2027-03-15");
  assert.equal(dir("15 mar", "past"), "2027-03-15");
  assert.equal(dir("14 mar", "future"), "2028-03-14");
  assert.equal(dir("14 mar", "past"), "2027-03-14");
  assert.equal(dir("14 mar", "nearest"), "2027-03-14");
  assert.equal(dir("1 dec", "nearest"), "2026-12-01");
  assert.equal(dir("1 jul", "nearest"), "2027-07-01");
  assert.equal(dir("29 feb", "past"), "2024-02-29");
  // Weekdays.
  assert.equal(dir("friday", "future"), "2027-03-19");
  assert.equal(dir("friday", "past"), "2027-03-12");
  assert.equal(dir("friday", "nearest"), "2027-03-12");
  assert.equal(dir("tuesday", "nearest"), "2027-03-16");
  assert.equal(dir("monday", "past"), "2027-03-15");
  // Months: the current one counts.
  assert.equal(dir("march", "future", MONDAY, "range"), "2027-03-01..2027-03-31");
  assert.equal(dir("march", "past", MONDAY, "range"), "2027-03-01..2027-03-31");
  assert.equal(dir("april", "past", MONDAY, "range"), "2026-04-01..2026-04-30");
  assert.equal(dir("january", "nearest", MONDAY, "range"), "2027-01-01..2027-01-31");
  assert.equal(dir("october", "nearest", MONDAY, "range"), "2026-10-01..2026-10-31");
  assert.equal(dir("Q4", "past", MONDAY, "range"), "2026-10-01..2026-12-31");
  // Days of the month.
  assert.equal(dir("the 10th", "future"), "2027-04-10");
  assert.equal(dir("the 10th", "past"), "2027-03-10");
  assert.equal(dir("the 20th", "past"), "2027-02-20");
  assert.equal(dir("the 20th", "nearest"), "2027-03-20");
  // Relative words do not depend on direction.
  assert.equal(dir("next friday", "past"), "2027-03-26");
  assert.equal(dir("tomorrow", "past"), "2027-03-16");
});

test("dates cross the year boundary", () => {
  const december = parseISO("2027-12-20")!;
  const at = (text: string, direction: "future" | "past" | "nearest" = "future", mode: ParseMode = "date") =>
    show(parseDate(text, { locale: "en-GB", today: december, mode, direction }));
  assert.equal(at("15 jan"), "2028-01-15");
  assert.equal(at("15 jan", "past"), "2027-01-15");
  assert.equal(at("15 jan", "nearest"), "2028-01-15");
  assert.equal(at("15/1"), "2028-01-15");
  assert.equal(at("january", "future", "range"), "2028-01-01..2028-01-31");
  assert.equal(at("Q1", "future", "range"), "2028-01-01..2028-03-31");
  assert.equal(at("next month", "future", "range"), "2028-01-01..2028-01-31");
  assert.equal(at("in 2 weeks"), "2028-01-03");
  assert.equal(at("next week", "future", "range"), "2027-12-27..2028-01-02");
  assert.equal(at("the 5th"), "2028-01-05");
  assert.equal(at("28 dec - 3 jan", "future", "range"), "2027-12-28..2028-01-03");
  assert.equal(at("next 14 days", "future", "range"), "2027-12-20..2028-01-02");
  assert.equal(at("end of month"), "2027-12-31");
  assert.equal(at("1 jan", "past"), "2027-01-01");
});

test("a Saturday reference", () => {
  const sat = (text: string, mode: ParseMode = "date", extra: Partial<ParseOptions> = {}) =>
    show(parseDate(text, { locale: "en-GB", today: SATURDAY, mode, ...extra }));
  assert.equal(sat("this weekend", "range"), "2027-03-20..2027-03-21");
  assert.equal(sat("weekend", "range"), "2027-03-20..2027-03-21");
  assert.equal(sat("next weekend", "range"), "2027-03-27..2027-03-28");
  assert.equal(sat("last weekend", "range"), "2027-03-13..2027-03-14");
  assert.equal(sat("friday"), "2027-03-26");
  assert.equal(sat("friday", "date", { direction: "past" }), "2027-03-19");
  assert.equal(sat("friday", "date", { direction: "nearest" }), "2027-03-19");
  assert.equal(sat("saturday"), "2027-03-20");
  assert.equal(sat("monday"), "2027-03-22");
  assert.equal(sat("this friday"), "2027-03-19");
  assert.equal(sat("next friday"), "2027-03-26");
  assert.equal(sat("next monday"), "2027-03-22");
  assert.equal(sat("last friday"), "2027-03-12");
  assert.equal(sat("this week", "range"), "2027-03-15..2027-03-21");
  assert.equal(sat("next 7 days", "range"), "2027-03-20..2027-03-26");
  assert.equal(sat("tomorrow"), "2027-03-21");
  assert.equal(sat("sexta que vem", "date", { locale: "pt-PT" }), "2027-03-26");
  assert.equal(sat("来週の月曜日", "date", { locale: "ja" }), "2027-03-22");
  const sunday = parseISO("2027-03-21")!;
  assert.equal(show(parseDate("this weekend", { locale: "en-GB", today: sunday, mode: "range" })), "2027-03-20..2027-03-21");
  assert.equal(show(parseDate("next weekend", { locale: "en-GB", today: sunday, mode: "range" })), "2027-03-27..2027-03-28");
});

test("firstDay shapes weeks", () => {
  const sunday = { firstDay: 7 };
  assert.equal(read("this week", "en-US", "range", sunday), "2027-03-14..2027-03-20");
  assert.equal(read("next week", "en-US", "range", sunday), "2027-03-21..2027-03-27");
  assert.equal(read("next week", "en-US", "date", sunday), "2027-03-21");
  assert.equal(read("end of week", "en-US", "date", sunday), "2027-03-20");
  assert.equal(read("this sunday", "en-US", "date", sunday), "2027-03-14");
  assert.equal(read("this sunday", "en-GB", "date"), "2027-03-21");
  assert.equal(read("next sunday", "en-US", "date", sunday), "2027-03-21");
  // ISO weeks stay ISO.
  assert.equal(read("2027-W11", "en-US", "range", sunday), "2027-03-15..2027-03-21");
});

test("modes keep to their kind", () => {
  assert.equal(read("tomorrow 9am", "en-GB", "date"), "2027-03-16");
  assert.equal(read("tomorrow 9am", "en-GB", "range"), "2027-03-16");
  assert.equal(read("9am", "en-GB", "date"), null);
  assert.equal(read("9am", "en-GB", "range"), null);
  assert.equal(read("next week", "en-GB", "datetime"), "2027-03-22");
  assert.deepEqual(parseDate("tomorrow", { locale: "en", today: MONDAY, mode: "date" }), { kind: "date", day: MONDAY + 1 });
  assert.deepEqual(parseDate("next week", { locale: "en", today: MONDAY, mode: "range" }), { kind: "range", from: MONDAY + 7, to: MONDAY + 13 });
  assert.deepEqual(parseDate("tomorrow 9am", { locale: "en", today: MONDAY, mode: "datetime" }), { kind: "datetime", day: MONDAY + 1, time: 9 * 3600 });
  assert.deepEqual(parseDate("9am", { locale: "en", today: MONDAY, mode: "time" }), { kind: "time", time: 9 * 3600 });
});

table("Garbage and invalid dates are null", "en-GB", "date", [
  ["", null],
  ["   ", null],
  ["asdf", null],
  ["next", null],
  ["in", null],
  ["in days", null],
  ["in 3", null],
  ["in march", "2027-03-01"],
  ["in 2028", "2028-01-01"],
  ["3 ago", null],
  ["next banana", null],
  ["31/4/2027", null],
  ["29/2/2027", null],
  ["0/1/2027", null],
  ["1/0/2027", null],
  ["2027-00-10", null],
  ["15 15 mar", null],
  ["mar apr", null],
  ["friday monday", null],
  ["Q5", null],
  ["2027-W00", null],
  ["123456", null],
  ["15.", "2027-03-15"],
  ["{a}", null],
  ["in 999999999 days", null],
]);

test("never throws", () => {
  const texts = [
    "", "\u0000", "🙂", "{n} {u}", "((((", "-", "–", "~", "- -", "...", "1/2/3/4", "31.12.", "q", "w", "2027-W", "午後", "時",
    "in -3 days", "next next friday", "from to", "between and", "the the the", "%s %d", "a".repeat(500), "1".repeat(50),
    "15 – – 20 mar", "to", "at", "at at 9", "3日後後", "来", "の", "'", "l'", "t/m",
  ];
  const locales = ["en", "en-US", "pt-PT", "ja", "de", "xx", "not a locale!!", "", "zh-Hant-TW", "ar-EG", "he"];
  const modes: ParseMode[] = ["date", "range", "dates", "month", "year", "week", "time", "datetime"];
  for (const text of texts) {
    for (const locale of locales) {
      for (const mode of modes) {
        assert.doesNotThrow(() => parseDate(text, { locale, today: MONDAY, mode }));
      }
    }
  }
  assert.equal(read("tomorrow", "not a locale!!", "date"), "2027-03-16");
  assert.equal(read("tomorrow", "", "date"), "2027-03-16");
  assert.equal(show(parseDate("tomorrow", { locale: "en", today: 1.5, mode: "date" })), null);
});
