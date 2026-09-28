// Strict request schema for POST /lens/v1/pass. Unknown keys are rejected everywhere.
import { z } from "zod";

/** No control characters (C0/C1), bidi overrides/isolates, zero-width space or BOM. (ZWJ/ZWNJ stay allowed: emoji, Indic/Persian text.) */
const SAFE_TEXT = /^[^\u0000-\u001f\u007f-\u009f\u200b\u202a-\u202e\u2066-\u2069\ufeff]*$/;

const text = (max: number) =>
  z
    .string()
    .trim()
    .min(1)
    .max(max)
    .regex(SAFE_TEXT, "contains control characters");

const IATA = z.string().regex(/^[A-Z]{3}$/, "IATA airport code (3 letters)");
const DATE = z
  .string()
  .regex(/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/, "YYYY-MM-DD")
  .refine((s) => !Number.isNaN(Date.parse(`${s}T00:00:00Z`)), "invalid date");
const TIME = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "HH:MM");
/** ISO 8601 date-time with explicit offset (what Wallet needs for relevantDate). */
const DATETIME = z.iso.datetime({ offset: true, local: false });

export const PALETTE = ["midnight", "graphite", "ocean", "forest", "plum", "ember", "paper"] as const;
export type PaletteName = (typeof PALETTE)[number];

export const BARCODE_FORMATS = ["QR", "PDF417", "Aztec", "Code128"] as const;

const barcode = z
  .object({
    message: z.string().min(1).max(2048),
    format: z.enum(BARCODE_FORMATS),
    altText: text(64).optional(),
  })
  .strict()
  .refine((b) => b.format !== "Code128" || /^[\x20-\x7e]{1,80}$/.test(b.message), {
    message: "Code128 needs 1–80 printable ASCII characters",
    path: ["message"],
  });

const common = {
  barcode,
  color: z.enum(PALETTE).optional(),
  relevantDate: DATETIME.optional(),
};

const boardingPass = z
  .object({
    passType: z.literal("boardingPass"),
    ...common,
    fields: z
      .object({
        carrier: text(32),
        flightNumber: z.string().regex(/^[A-Z0-9]{1,8}$/, "flight number (A–Z, 0–9)"),
        from: IATA,
        to: IATA,
        date: DATE,
        boardingTime: TIME.optional(),
        gate: text(8).optional(),
        seat: text(6).optional(),
        group: text(8).optional(),
        passenger: text(64),
      })
      .strict(),
  })
  .strict();

const eventTicket = z
  .object({
    passType: z.literal("eventTicket"),
    ...common,
    fields: z
      .object({
        title: text(64),
        venue: text(64).optional(),
        date: z.union([DATE, DATETIME]).optional(),
      })
      .strict(),
  })
  .strict();

const simpleFields = z
  .object({
    title: text(64),
    subtitle: text(64).optional(),
    number: text(40).optional(),
  })
  .strict();

const storeCard = z.object({ passType: z.literal("storeCard"), ...common, fields: simpleFields }).strict();
const generic = z.object({ passType: z.literal("generic"), ...common, fields: simpleFields }).strict();

export const PassRequestSchema = z.discriminatedUnion("passType", [boardingPass, eventTicket, storeCard, generic]);
export type PassRequest = z.infer<typeof PassRequestSchema>;

export type ParseResult = { ok: true; value: PassRequest } | { ok: false; issues: string[] };

export function parsePassRequest(input: unknown): ParseResult {
  const r = PassRequestSchema.safeParse(input);
  if (r.success) return { ok: true, value: r.data };
  // Report paths + messages only — never echo the submitted values back.
  return { ok: false, issues: r.error.issues.slice(0, 10).map((i) => `${i.path.join(".") || "(root)"}: ${i.message}`) };
}

export const AttestRequestSchema = z
  .object({
    keyId: z.string().regex(/^[A-Za-z0-9+/]{43}=$/, "base64 SHA-256"),
    attestation: z.string().min(100).max(16384),
    challenge: z.string().regex(/^[A-Za-z0-9_-]{43}$/, "base64url 32 bytes"),
  })
  .strict();
