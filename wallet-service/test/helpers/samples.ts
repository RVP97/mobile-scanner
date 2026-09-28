import type { PassRequest } from "../../src/schema";

export const BOARDING: PassRequest = {
  passType: "boardingPass",
  barcode: { message: "M1DOE/JANE            EABC123 MEXJFKAM 0401 274Y012A0001 100", format: "PDF417" },
  color: "ocean",
  fields: {
    carrier: "AM",
    flightNumber: "401",
    from: "MEX",
    to: "JFK",
    date: "2026-10-01",
    boardingTime: "07:45",
    gate: "B12",
    seat: "12A",
    group: "3",
    passenger: "DOE/JANE MS",
  },
};
