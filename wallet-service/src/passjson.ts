// Builds pass.json from a validated request. Pure: all randomness/time is injected.
import type { PaletteName, PassRequest } from "./schema";

export interface PassConfig {
  passTypeIdentifier: string;
  teamIdentifier: string;
}

type Rgb = `rgb(${number}, ${number}, ${number})`;
interface Colors {
  backgroundColor: Rgb;
  foregroundColor: Rgb;
  labelColor: Rgb;
}

/** Fixed palette — clients pick a name, never an arbitrary color. */
export const PALETTE_COLORS: Record<PaletteName, Colors> = {
  midnight: { backgroundColor: "rgb(14, 17, 22)", foregroundColor: "rgb(245, 247, 250)", labelColor: "rgb(100, 210, 255)" },
  graphite: { backgroundColor: "rgb(44, 44, 46)", foregroundColor: "rgb(242, 242, 247)", labelColor: "rgb(174, 174, 178)" },
  ocean: { backgroundColor: "rgb(10, 61, 98)", foregroundColor: "rgb(255, 255, 255)", labelColor: "rgb(153, 214, 255)" },
  forest: { backgroundColor: "rgb(22, 66, 48)", foregroundColor: "rgb(255, 255, 255)", labelColor: "rgb(166, 227, 190)" },
  plum: { backgroundColor: "rgb(72, 32, 88)", foregroundColor: "rgb(255, 255, 255)", labelColor: "rgb(222, 190, 255)" },
  ember: { backgroundColor: "rgb(120, 40, 20)", foregroundColor: "rgb(255, 255, 255)", labelColor: "rgb(255, 204, 170)" },
  paper: { backgroundColor: "rgb(246, 246, 243)", foregroundColor: "rgb(28, 28, 30)", labelColor: "rgb(0, 122, 153)" },
};

const WALLET_FORMAT = {
  QR: "PKBarcodeFormatQR",
  PDF417: "PKBarcodeFormatPDF417",
  Aztec: "PKBarcodeFormatAztec",
  Code128: "PKBarcodeFormatCode128",
} as const;

const DISCLAIMER =
  "Created with Ojito from a code you scanned. This pass was not issued by, and is not affiliated with, the carrier, venue or merchant named on it. Always follow the official ticket or boarding pass.";

interface Field {
  key: string;
  label?: string;
  value: string | number;
  textAlignment?: string;
  dateStyle?: string;
  timeStyle?: string;
  ignoresTimeZone?: boolean;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
function shortDate(isoDate: string): string {
  const [y, m, d] = isoDate.split("-").map(Number);
  return `${MONTHS[m! - 1]} ${d}, ${y}`;
}

/** Date-only value rendered in the pass's own terms (no time-zone shifting). */
function dateField(key: string, label: string, isoDate: string): Field {
  return {
    key,
    label,
    value: `${isoDate}T00:00:00Z`,
    dateStyle: "PKDateStyleMedium",
    timeStyle: "PKDateStyleNone",
    ignoresTimeZone: true,
  };
}

function isLatin1(s: string): boolean {
  return /^[\u0000-\u00ff]*$/.test(s);
}

function splitPassengerName(p: string): { familyName?: string; givenName?: string } | undefined {
  // IATA BCBP style "SURNAME/GIVEN MR"
  const m = /^([^/]+)\/(.+)$/.exec(p);
  if (!m) return undefined;
  return { familyName: m[1]!.trim(), givenName: m[2]!.replace(/\s+(MR|MRS|MS|MISS|MSTR|DR)$/i, "").trim() };
}

export interface BuildOptions {
  serialNumber: string;
}

export function buildPassJson(req: PassRequest, cfg: PassConfig, opts: BuildOptions): Record<string, unknown> {
  const colors = PALETTE_COLORS[req.color ?? "midnight"];
  const barcode = {
    format: WALLET_FORMAT[req.barcode.format],
    message: req.barcode.message,
    messageEncoding: isLatin1(req.barcode.message) ? "iso-8859-1" : "utf-8",
    ...(req.barcode.altText ? { altText: req.barcode.altText } : {}),
  };

  const pass: Record<string, unknown> = {
    formatVersion: 1,
    passTypeIdentifier: cfg.passTypeIdentifier,
    teamIdentifier: cfg.teamIdentifier,
    serialNumber: opts.serialNumber,
    organizationName: "Ojito",
    logoText: "Ojito",
    description: "",
    ...colors,
    barcodes: [barcode],
    sharingProhibited: false,
  };
  if (req.relevantDate) pass.relevantDate = req.relevantDate;

  const back: Field[] = [{ key: "lens-note", label: "About this pass", value: DISCLAIMER }];

  switch (req.passType) {
    case "boardingPass": {
      const f = req.fields;
      const flight = `${f.carrier.length <= 3 ? f.carrier.toUpperCase() : ""}${f.flightNumber}`.trim();
      pass.description = `Boarding pass ${f.from}–${f.to} · ${flight || f.flightNumber} · ${shortDate(f.date)} (created with Ojito)`;
      const header: Field[] = [];
      if (f.gate) header.push({ key: "gate", label: "GATE", value: f.gate });
      if (f.seat) header.push({ key: "seat", label: "SEAT", value: f.seat });
      const aux: Field[] = [];
      if (f.boardingTime) {
        aux.push({
          key: "boarding",
          label: "BOARDS",
          value: `${f.date}T${f.boardingTime}:00Z`,
          dateStyle: "PKDateStyleNone",
          timeStyle: "PKDateStyleShort",
          ignoresTimeZone: true,
        });
      }
      if (f.group) aux.push({ key: "group", label: "GROUP", value: f.group });
      aux.push({ key: "flight", label: "FLIGHT", value: flight || f.flightNumber });
      aux.push({ ...dateField("date", "DATE", f.date), textAlignment: "PKTextAlignmentRight" });

      const semantics: Record<string, unknown> = {
        flightNumber: /^\d{1,4}$/.test(f.flightNumber) ? Number(f.flightNumber) : undefined,
        departureAirportCode: f.from,
        destinationAirportCode: f.to,
        ...(f.carrier.length >= 2 && f.carrier.length <= 3 && /^[A-Z0-9]+$/i.test(f.carrier)
          ? { airlineCode: f.carrier.toUpperCase(), flightCode: `${f.carrier.toUpperCase()}${f.flightNumber}` }
          : {}),
        ...(f.gate ? { departureGate: f.gate } : {}),
        ...(f.group ? { boardingGroup: f.group } : {}),
        ...(f.seat ? { seats: [{ seatNumber: f.seat }] } : {}),
      };
      const name = splitPassengerName(f.passenger);
      if (name) semantics.passengerName = name;
      for (const k of Object.keys(semantics)) if (semantics[k] === undefined) delete semantics[k];

      pass.semantics = semantics;
      pass.boardingPass = {
        transitType: "PKTransitTypeAir",
        headerFields: header,
        primaryFields: [
          { key: "origin", label: "FROM", value: f.from },
          { key: "destination", label: "TO", value: f.to },
        ],
        secondaryFields: [
          { key: "passenger", label: "PASSENGER", value: f.passenger },
          { key: "carrier", label: "CARRIER", value: f.carrier, textAlignment: "PKTextAlignmentRight" },
        ],
        auxiliaryFields: aux,
        backFields: back,
      };
      break;
    }
    case "eventTicket": {
      const f = req.fields;
      pass.description = `Ticket: ${f.title} (created with Ojito)`;
      const secondary: Field[] = [];
      if (f.venue) secondary.push({ key: "venue", label: "VENUE", value: f.venue });
      if (f.date) {
        secondary.push(
          f.date.length === 10
            ? { ...dateField("date", "DATE", f.date), textAlignment: "PKTextAlignmentRight" }
            : {
                key: "date",
                label: "DATE",
                value: f.date,
                dateStyle: "PKDateStyleMedium",
                timeStyle: "PKDateStyleShort",
                textAlignment: "PKTextAlignmentRight",
              },
        );
      }
      if (f.date && f.date.length > 10 && !pass.relevantDate) pass.relevantDate = f.date;
      pass.semantics = { eventName: f.title, ...(f.venue ? { venueName: f.venue } : {}) };
      pass.eventTicket = {
        primaryFields: [{ key: "event", label: "EVENT", value: f.title }],
        secondaryFields: secondary,
        backFields: back,
      };
      break;
    }
    case "storeCard":
    case "generic": {
      const f = req.fields;
      pass.description = `${req.passType === "storeCard" ? "Card" : "Pass"}: ${f.title} (created with Ojito)`;
      const secondary: Field[] = [];
      if (f.subtitle) secondary.push({ key: "subtitle", label: "DETAILS", value: f.subtitle });
      if (f.number) secondary.push({ key: "number", label: "NUMBER", value: f.number, textAlignment: "PKTextAlignmentRight" });
      pass[req.passType] = {
        primaryFields: [{ key: "title", label: req.passType === "storeCard" ? "CARD" : "NAME", value: f.title }],
        secondaryFields: secondary,
        backFields: back,
      };
      break;
    }
  }
  return pass;
}
