"use client";

import { toPng } from "html-to-image";
import { useCallback, useEffect, useRef, useState } from "react";

// ─── Constants ────────────────────────────────────────────────────────────────
const IPHONE_W = 1320;
const IPHONE_H = 2868;
const IPAD_W = 2064;
const IPAD_H = 2752;

const MK_W = 1022;
const MK_H = 2082;
const SC_L = (52 / MK_W) * 100;
const SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100;
const SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100;
const SC_RY = (126 / 1990) * 100;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;

const IPAD_SIZES = [
  { label: '13" iPad', w: 2064, h: 2752 },
  { label: '12.9" iPad Pro', w: 2048, h: 2732 },
] as const;

type Device = "iphone" | "ipad";

// ─── App Colors (exact from the app) ─────────────────────────────────────────
const C = {
  bg: "#F2F2F7",
  card: "#FFFFFF",
  label: "#000000",
  secondary: "#3C3C43",
  tertiary: "#8E8E93",
  separator: "#C6C6C8",
  blue: "#007AFF",
  green: "#34C759",
  orange: "#FF9500",
  indigo: "#5856D6",
  red: "#FF3B30",
  purple: "#AF52DE",
  yellow: "#FFD60A",
};

// ─── SF Symbols as SVG icons ─────────────────────────────────────────────────
function SFCamera({ size = 18, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M3 7C3 5.89543 3.89543 5 5 5H7.5L9 3H15L16.5 5H19C20.1046 5 21 5.89543 21 7V18C21 19.1046 20.1046 20 19 20H5C3.89543 20 3 19.1046 3 18V7Z" fill={color}/>
      <circle cx="12" cy="12.5" r="3.5" fill={color === "#fff" ? "rgba(0,0,0,0.3)" : "rgba(255,255,255,0.5)"}/>
    </svg>
  );
}

function SFBolt({ size = 18, color = "#FFD60A" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M13 2L4.09 12.89C3.69 13.39 4.05 14.12 4.68 14.12H11V22L19.91 11.11C20.31 10.61 19.95 9.88 19.32 9.88H13V2Z"/>
    </svg>
  );
}

function SFFlip({ size = 18, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M20 7L16 3V6C10.48 6 6 10.48 6 16H8C8 11.58 11.58 8 16 8V11L20 7ZM4 17L8 21V18C13.52 18 18 13.52 18 8H16C16 12.42 12.42 16 8 16V13L4 17Z"/>
    </svg>
  );
}

function SFPhoto({ size = 18, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <rect x="3" y="5" width="18" height="14" rx="2" opacity="0.3"/>
      <rect x="1" y="3" width="18" height="14" rx="2"/>
    </svg>
  );
}

function SFViewfinder({ size = 16, color = "rgba(255,255,255,0.8)" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2.5" strokeLinecap="round">
      <path d="M3 8V5C3 3.89 3.89 3 5 3H8"/>
      <path d="M16 3H19C20.11 3 21 3.89 21 5V8"/>
      <path d="M21 16V19C21 20.11 20.11 21 19 21H16"/>
      <path d="M8 21H5C3.89 21 3 20.11 3 19V16"/>
    </svg>
  );
}

function SFQRCode({ size = 18, color = C.blue }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <rect x="3" y="3" width="8" height="8" rx="1"/>
      <rect x="5" y="5" width="4" height="4" rx="0.5" fill={color === "#fff" ? "rgba(0,0,0,0.3)" : "#fff"}/>
      <rect x="13" y="3" width="8" height="8" rx="1"/>
      <rect x="15" y="5" width="4" height="4" rx="0.5" fill={color === "#fff" ? "rgba(0,0,0,0.3)" : "#fff"}/>
      <rect x="3" y="13" width="8" height="8" rx="1"/>
      <rect x="5" y="15" width="4" height="4" rx="0.5" fill={color === "#fff" ? "rgba(0,0,0,0.3)" : "#fff"}/>
      <rect x="13" y="13" width="3" height="3"/>
      <rect x="18" y="13" width="3" height="3"/>
      <rect x="13" y="18" width="3" height="3"/>
      <rect x="18" y="18" width="3" height="3"/>
    </svg>
  );
}

function SFBarcode({ size = 18, color = C.blue }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <rect x="2" y="4" width="2" height="16"/><rect x="5" y="4" width="1" height="16"/>
      <rect x="8" y="4" width="3" height="16"/><rect x="12" y="4" width="1" height="16"/>
      <rect x="14" y="4" width="2" height="16"/><rect x="18" y="4" width="1" height="16"/>
      <rect x="20" y="4" width="2" height="16"/>
    </svg>
  );
}

function SFCheckmark({ size = 40, color = C.green }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <circle cx="12" cy="12" r="12" opacity="1"/>
      <path d="M7 12.5L10.5 16L17 9" stroke="#fff" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" fill="none"/>
    </svg>
  );
}

function SFGear({ size = 18, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M19.14 12.94c.04-.31.06-.63.06-.94 0-.31-.02-.63-.06-.94l2.03-1.58a.49.49 0 00.12-.61l-1.92-3.32a.488.488 0 00-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54a.484.484 0 00-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.04.31-.06.63-.06.94 0 .31.02.63.06.94l-2.03 1.58a.49.49 0 00-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6A3.6 3.6 0 1112 8.4a3.6 3.6 0 010 7.2z"/>
    </svg>
  );
}

function SFClock({ size = 18, color = "#fff" }: { size?: number; color?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <circle cx="12" cy="12" r="10"/>
      <path d="M12 6V12L16 14" stroke={color === "#fff" ? "rgba(0,0,0,0.3)" : "#fff"} strokeWidth="2" strokeLinecap="round" fill="none"/>
    </svg>
  );
}

// ─── iOS Status Bar ──────────────────────────────────────────────────────────
function IOSStatusBar({ dark = false, s }: { dark?: boolean; s: number }) {
  const c = dark ? "#fff" : "#000";
  return (
    <div style={{ position: "relative", zIndex: 10 }}>
      {/* Dynamic Island */}
      <div style={{ display: "flex", justifyContent: "center", paddingTop: 10 * s }}>
        <div style={{ width: 120 * s, height: 34 * s, borderRadius: 20 * s, background: "#000" }} />
      </div>
      {/* Time + indicators row */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: `${6 * s}px ${36 * s}px ${4 * s}px`, height: 22 * s }}>
        <span style={{ fontSize: 15 * s, fontWeight: 600, color: c, fontFamily: "-apple-system, system-ui, sans-serif" }}>9:41</span>
        <div style={{ display: "flex", gap: 6 * s, alignItems: "center" }}>
          <svg width={18 * s} height={12 * s} viewBox="0 0 18 12" fill={c}><rect x="0" y="3" width="3" height="9" rx="1" opacity="0.3"/><rect x="5" y="2" width="3" height="10" rx="1" opacity="0.5"/><rect x="10" y="1" width="3" height="11" rx="1" opacity="0.7"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg>
          <svg width={16 * s} height={12 * s} viewBox="0 0 16 12" fill={c}><path d="M1 5C4.7-1 11.3-1 15 5" stroke={c} strokeWidth="1.5" fill="none" opacity="0.4"/><path d="M3.5 7.5C5.8 3.5 10.2 3.5 12.5 7.5" stroke={c} strokeWidth="1.5" fill="none" opacity="0.7"/><circle cx="8" cy="10" r="2"/></svg>
          <svg width={27 * s} height={13 * s} viewBox="0 0 27 13" fill="none"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} opacity="0.35"/><rect x="25" y="4" width="2" height="5" rx="1" fill={c} opacity="0.4"/><rect x="2" y="2" width="18" height="9" rx="2" fill={c}/></svg>
        </div>
      </div>
    </div>
  );
}

// ─── iOS Tab Bar ─────────────────────────────────────────────────────────────
function IOSTabBar({ activeTab = 0, s }: { activeTab?: number; s: number }) {
  const tabs = [
    { label: "Scanner", active: activeTab === 0 },
    { label: "History", active: activeTab === 1 },
    { label: "Generator", active: activeTab === 2 },
    { label: "Settings", active: activeTab === 3 },
  ];
  return (
    <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, background: "rgba(249,249,249,0.94)", backdropFilter: "blur(20px)", borderTop: "0.5px solid rgba(0,0,0,0.12)", display: "flex", justifyContent: "space-around", padding: `${8 * s}px 0 ${28 * s}px` }}>
      {tabs.map((tab, i) => (
        <div key={tab.label} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 * s }}>
          <div style={{ width: 24 * s, height: 24 * s, display: "flex", alignItems: "center", justifyContent: "center" }}>
            {i === 0 && <SFCamera size={22 * s} color={tab.active ? C.blue : "#999"} />}
            {i === 1 && <SFClock size={22 * s} color={tab.active ? C.blue : "#999"} />}
            {i === 2 && <SFQRCode size={22 * s} color={tab.active ? C.blue : "#999"} />}
            {i === 3 && <SFGear size={22 * s} color={tab.active ? C.blue : "#999"} />}
          </div>
          <span style={{ fontSize: 10 * s, fontWeight: 500, color: tab.active ? C.blue : "#999", fontFamily: "-apple-system, system-ui, sans-serif" }}>{tab.label}</span>
        </div>
      ))}
    </div>
  );
}

// ─── iOS Large Title Header ──────────────────────────────────────────────────
function IOSLargeHeader({ title, s }: { title: string; s: number }) {
  return (
    <div style={{ padding: `${8 * s}px ${16 * s}px ${10 * s}px` }}>
      <div style={{ fontSize: 34 * s, fontWeight: 700, color: C.label, fontFamily: "-apple-system, system-ui, sans-serif", letterSpacing: -0.4 * s }}>{title}</div>
    </div>
  );
}

// ─── Mock QR Code ────────────────────────────────────────────────────────────
function MockQRCode({ size = 140 }: { size?: number }) {
  const p = [
    "111111100101011111111","100000101010010000001","101110101100110111101",
    "101110100011010111101","101110101101010111101","100000101010110000001",
    "111111101010111111111","000000000110100000000","110101110100101011001",
    "011010011011001101010","101011101010110101001","010100010101010010110",
    "110011110010101101001","000000001101011010010","111111101010110101001",
    "100000100011001010110","101110101100110101001","101110100101010110010",
    "101110101010101001101","100000101101010010010","111111100010101101001",
  ];
  const cs = size / 21;
  return (
    <div style={{ width: size, height: size, background: "#fff", display: "flex", flexDirection: "column" }}>
      {p.map((row, y) => (
        <div key={y} style={{ display: "flex", height: cs }}>
          {row.split("").map((cell, x) => (
            <div key={x} style={{ width: cs, height: cs + 0.5, background: cell === "1" ? "#000" : "#fff" }} />
          ))}
        </div>
      ))}
    </div>
  );
}

// ─── Phone / iPad Mockups ────────────────────────────────────────────────────
function Phone({ children, style, className = "" }: { children: React.ReactNode; style?: React.CSSProperties; className?: string }) {
  return (
    <div className={className} style={{ position: "relative", aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      <img src="/mockup.png" alt="" style={{ display: "block", width: "100%", height: "100%" }} draggable={false} />
      <div style={{ position: "absolute", zIndex: 10, overflow: "hidden", left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`, borderRadius: `${SC_RX}% / ${SC_RY}%` }}>
        {children}
      </div>
    </div>
  );
}

function IPad({ children, style, className = "" }: { children: React.ReactNode; style?: React.CSSProperties; className?: string }) {
  return (
    <div className={className} style={{ position: "relative", aspectRatio: "770/1000", ...style }}>
      <div style={{ width: "100%", height: "100%", borderRadius: "5% / 3.6%", background: "linear-gradient(180deg, #2C2C2E 0%, #1C1C1E 100%)", position: "relative", overflow: "hidden", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 40px rgba(0,0,0,0.6)" }}>
        <div style={{ position: "absolute", top: "1.2%", left: "50%", transform: "translateX(-50%)", width: "0.9%", height: "0.65%", borderRadius: "50%", background: "#111113", border: "1px solid rgba(255,255,255,0.08)", zIndex: 20 }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: "5% / 3.6%", border: "1px solid rgba(255,255,255,0.06)", pointerEvents: "none", zIndex: 15 }} />
        <div style={{ position: "absolute", left: "4%", top: "2.8%", width: "92%", height: "94.4%", borderRadius: "2.2% / 1.6%", overflow: "hidden", background: "#000" }}>
          {children}
        </div>
      </div>
    </div>
  );
}

// ─── Caption Component ───────────────────────────────────────────────────────
function Caption({ label, headline, W, color = "#fff", labelColor }: { label: string; headline: string; W: number; color?: string; labelColor?: string }) {
  return (
    <div style={{ textAlign: "center" }}>
      <div style={{ fontSize: W * 0.028, fontWeight: 600, color: labelColor || "rgba(255,255,255,0.65)", textTransform: "uppercase", letterSpacing: W * 0.004, marginBottom: W * 0.018, fontFamily: "-apple-system, system-ui, sans-serif" }}>{label}</div>
      <div style={{ fontSize: W * 0.082, fontWeight: 800, color, lineHeight: 1.02, letterSpacing: -W * 0.003, fontFamily: "-apple-system, system-ui, sans-serif" }} dangerouslySetInnerHTML={{ __html: headline }} />
    </div>
  );
}

// ─── Mock App Screens ────────────────────────────────────────────────────────

function ScreenScanner({ s = 1 }: { s?: number }) {
  return (
    <div style={{ width: "100%", height: "100%", background: "#000", position: "relative", overflow: "hidden", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(155deg, #0f1923 0%, #162a3e 30%, #1a3a52 50%, #0f2030 80%, #0a1520 100%)" }} />
      <IOSStatusBar dark s={s} />
      {/* Top controls */}
      <div style={{ position: "absolute", top: 80 * s, left: 20 * s, right: 20 * s, display: "flex", justifyContent: "space-between", zIndex: 5 }}>
        <div style={{ width: 44 * s, height: 44 * s, borderRadius: 22 * s, background: "rgba(0,0,0,0.5)", border: "1px solid rgba(255,255,255,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
          <SFBolt size={20 * s} />
        </div>
        <div style={{ width: 44 * s, height: 44 * s, borderRadius: 22 * s, background: "rgba(0,0,0,0.5)", border: "1px solid rgba(255,255,255,0.15)", display: "flex", alignItems: "center", justifyContent: "center" }}>
          <SFFlip size={18 * s} />
        </div>
      </div>
      {/* Viewfinder */}
      <div style={{ position: "absolute", top: "30%", left: "50%", transform: "translateX(-50%)", width: "64%", aspectRatio: "1" }}>
        {[
          { top: 0, left: 0, borderTop: `${3.5 * s}px solid #fff`, borderLeft: `${3.5 * s}px solid #fff`, borderTopLeftRadius: 14 * s },
          { top: 0, right: 0, borderTop: `${3.5 * s}px solid #fff`, borderRight: `${3.5 * s}px solid #fff`, borderTopRightRadius: 14 * s },
          { bottom: 0, left: 0, borderBottom: `${3.5 * s}px solid #fff`, borderLeft: `${3.5 * s}px solid #fff`, borderBottomLeftRadius: 14 * s },
          { bottom: 0, right: 0, borderBottom: `${3.5 * s}px solid #fff`, borderRight: `${3.5 * s}px solid #fff`, borderBottomRightRadius: 14 * s },
        ].map((st, i) => (
          <div key={i} style={{ position: "absolute", width: "15%", height: "15%", ...st } as React.CSSProperties} />
        ))}
      </div>
      {/* Bottom */}
      <div style={{ position: "absolute", bottom: 90 * s, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 10 * s }}>
        <div style={{ background: "rgba(28,28,30,0.82)", borderRadius: 14 * s, padding: `${11 * s}px ${18 * s}px`, display: "flex", alignItems: "center", gap: 8 * s }}>
          <SFViewfinder size={16 * s} />
          <span style={{ color: "rgba(255,255,255,0.9)", fontSize: 14 * s, fontWeight: 500 }}>Point at a barcode or QR code</span>
        </div>
        <div style={{ background: "rgba(28,28,30,0.82)", borderRadius: 10 * s, padding: `${9 * s}px ${16 * s}px`, display: "flex", alignItems: "center", gap: 7 * s }}>
          <SFPhoto size={16 * s} />
          <span style={{ color: "rgba(255,255,255,0.9)", fontSize: 13 * s, fontWeight: 500 }}>From Gallery</span>
        </div>
      </div>
      <IOSTabBar activeTab={0} s={s} />
    </div>
  );
}

function ScreenGenerator({ s = 1 }: { s?: number }) {
  return (
    <div style={{ width: "100%", height: "100%", background: C.bg, position: "relative", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      <IOSStatusBar s={s} />
      <IOSLargeHeader title="Generator" s={s} />
      <div style={{ padding: `0 ${16 * s}px` }}>
        {/* Code Type */}
        <div style={{ marginBottom: 20 * s }}>
          <div style={{ fontSize: 11 * s, fontWeight: 600, color: C.secondary, textTransform: "uppercase", letterSpacing: 0.5 * s, marginBottom: 6 * s, marginLeft: 4 * s }}>CODE TYPE</div>
          <div style={{ background: C.card, borderRadius: 10 * s, padding: `${12 * s}px ${14 * s}px`, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10 * s }}>
              <SFQRCode size={20 * s} />
              <span style={{ fontSize: 17 * s, color: C.label }}>QR Code</span>
            </div>
            <span style={{ color: C.tertiary, fontSize: 13 * s }}>⇅</span>
          </div>
        </div>
        {/* Content */}
        <div style={{ marginBottom: 20 * s }}>
          <div style={{ fontSize: 11 * s, fontWeight: 600, color: C.secondary, textTransform: "uppercase", letterSpacing: 0.5 * s, marginBottom: 6 * s, marginLeft: 4 * s }}>CONTENT</div>
          <div style={{ background: C.card, borderRadius: 10 * s, padding: `${13 * s}px ${14 * s}px`, fontSize: 17 * s, color: C.label }}>https://myportfolio.dev</div>
        </div>
        {/* Generate */}
        <div style={{ background: C.blue, borderRadius: 12 * s, padding: `${14 * s}px`, textAlign: "center", color: "#fff", fontWeight: 600, fontSize: 17 * s, marginBottom: 22 * s, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 * s }}>✨ Generate</div>
        {/* Result */}
        <div style={{ marginBottom: 10 * s }}>
          <div style={{ fontSize: 11 * s, fontWeight: 600, color: C.secondary, textTransform: "uppercase", letterSpacing: 0.5 * s, marginBottom: 6 * s, marginLeft: 4 * s }}>GENERATED CODE</div>
          <div style={{ background: C.card, borderRadius: 12 * s, padding: `${28 * s}px`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <MockQRCode size={160 * s} />
          </div>
          <div style={{ display: "flex", gap: 10 * s, marginTop: 10 * s }}>
            <div style={{ flex: 1, background: C.card, borderRadius: 10 * s, padding: `${13 * s}px`, textAlign: "center", color: C.blue, fontWeight: 600, fontSize: 17 * s, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 * s }}>
              <SFPhoto size={16 * s} color={C.blue} /> Copy
            </div>
            <div style={{ flex: 1, background: C.card, borderRadius: 10 * s, padding: `${13 * s}px`, textAlign: "center", color: C.blue, fontWeight: 600, fontSize: 17 * s, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 * s }}>↗ Share</div>
          </div>
        </div>
      </div>
      <IOSTabBar activeTab={2} s={s} />
    </div>
  );
}

function ScreenHistory({ s = 1 }: { s?: number }) {
  const scans = [
    { type: "QR", data: "https://example.com/menu", date: "Today, 2:34 PM" },
    { type: "EAN-13", data: "5901234123457", date: "Today, 11:20 AM" },
    { type: "QR", data: "https://wifi.connect/office", date: "Yesterday" },
    { type: "CODE 128", data: "SHIP-2024-00891", date: "Mar 8, 2026" },
  ];
  return (
    <div style={{ width: "100%", height: "100%", background: C.bg, position: "relative", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      <IOSStatusBar s={s} />
      <IOSLargeHeader title="History" s={s} />
      <div style={{ padding: `0 ${16 * s}px` }}>
        {/* Segmented control */}
        <div style={{ display: "flex", background: "rgba(118,118,128,0.12)", borderRadius: 8 * s, padding: 2 * s, marginBottom: 14 * s }}>
          <div style={{ flex: 1, textAlign: "center", padding: `${6 * s}px`, borderRadius: 6 * s, background: C.card, fontSize: 13 * s, fontWeight: 600, color: C.label, boxShadow: "0 1px 3px rgba(0,0,0,0.08)" }}>Scans</div>
          <div style={{ flex: 1, textAlign: "center", padding: `${6 * s}px`, borderRadius: 6 * s, fontSize: 13 * s, fontWeight: 600, color: C.tertiary }}>Generations</div>
        </div>
        {/* Header */}
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 * s }}>
          <span style={{ fontSize: 14 * s, fontWeight: 500, textTransform: "uppercase", letterSpacing: 0.5 * s, color: C.secondary }}>4 scans</span>
          <div style={{ display: "flex", alignItems: "center", gap: 5 * s, background: `${C.red}20`, borderRadius: 7 * s, padding: `${5 * s}px ${10 * s}px` }}>
            <span style={{ fontSize: 14 * s, fontWeight: 600, color: C.red }}>Clear All</span>
          </div>
        </div>
        {/* Cards */}
        <div style={{ display: "flex", flexDirection: "column", gap: 10 * s }}>
          {scans.map((scan, i) => (
            <div key={i} style={{ background: C.card, borderRadius: 16 * s, padding: `${14 * s}px ${14 * s}px` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 * s }}>
                <div style={{ display: "flex", alignItems: "center", gap: 5 * s, background: `${C.blue}20`, borderRadius: 5 * s, padding: `${3 * s}px ${7 * s}px` }}>
                  <SFQRCode size={12 * s} />
                  <span style={{ fontSize: 11 * s, fontWeight: 700, letterSpacing: 0.5 * s, color: C.blue }}>{scan.type}</span>
                </div>
                <span style={{ fontSize: 13 * s, color: C.tertiary }}>{scan.date}</span>
              </div>
              <div style={{ fontSize: 15 * s, fontFamily: "Menlo, monospace", color: scan.data.startsWith("http") ? C.blue : C.label, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", marginBottom: 12 * s }}>{scan.data}</div>
              <div style={{ display: "flex", gap: 8 * s }}>
                {["Copy", "Share", "Preview"].map((action) => (
                  <div key={action} style={{ background: C.bg, borderRadius: 10 * s, padding: `${8 * s}px ${12 * s}px`, fontSize: 14 * s, fontWeight: 500, color: C.blue, minHeight: 36 * s, display: "flex", alignItems: "center" }}>{action}</div>
                ))}
                <div style={{ marginLeft: "auto", background: C.bg, borderRadius: 10 * s, padding: `${8 * s}px ${10 * s}px`, display: "flex", alignItems: "center", minHeight: 36 * s }}>
                  <span style={{ color: C.red, fontSize: 14 * s }}>🗑</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
      <IOSTabBar activeTab={1} s={s} />
    </div>
  );
}

function ScreenScanResult({ s = 1 }: { s?: number }) {
  return (
    <div style={{ width: "100%", height: "100%", background: C.bg, position: "relative", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      <IOSStatusBar s={s} />
      <div style={{ padding: `${24 * s}px ${24 * s}px 0`, display: "flex", flexDirection: "column", alignItems: "center" }}>
        {/* Success icon ring */}
        <div style={{ width: 100 * s, height: 100 * s, borderRadius: 50 * s, border: `3px solid ${C.green}30`, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 18 * s }}>
          <div style={{ width: 80 * s, height: 80 * s, borderRadius: 40 * s, background: `${C.green}15`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <SFCheckmark size={52 * s} />
          </div>
        </div>
        <div style={{ fontSize: 28 * s, fontWeight: 700, color: C.label, marginBottom: 5 * s }}>Scan Complete</div>
        <div style={{ fontSize: 16 * s, color: C.secondary, marginBottom: 28 * s }}>Website URL detected</div>
        {/* Content card */}
        <div style={{ background: C.card, borderRadius: 16 * s, padding: `${18 * s}px`, width: "100%", marginBottom: 20 * s }}>
          <div style={{ display: "flex", alignItems: "center", gap: 7 * s, marginBottom: 10 * s }}>
            <span style={{ fontSize: 14 * s }}>🔗</span>
            <span style={{ fontSize: 14 * s, fontWeight: 600, textTransform: "uppercase", color: C.secondary, letterSpacing: 0.5 * s }}>URL</span>
          </div>
          <div style={{ fontSize: 17 * s, fontFamily: "Menlo, monospace", color: C.blue, lineHeight: 1.5 }}>https://example.com/menu</div>
        </div>
        {/* Action grid */}
        <div style={{ display: "flex", gap: 10 * s, width: "100%", marginBottom: 18 * s }}>
          {[
            { label: "Copy", bg: `${C.blue}15`, iconColor: C.blue },
            { label: "Share", bg: `${C.green}15`, iconColor: C.green },
            { label: "Open URL", bg: `${C.indigo}15`, iconColor: C.indigo },
          ].map((a) => (
            <div key={a.label} style={{ flex: 1, background: C.card, borderRadius: 16 * s, padding: `${18 * s}px ${8 * s}px`, display: "flex", flexDirection: "column", alignItems: "center", gap: 8 * s }}>
              <div style={{ width: 48 * s, height: 48 * s, borderRadius: 14 * s, background: a.bg, display: "flex", alignItems: "center", justifyContent: "center" }}>
                <div style={{ width: 22 * s, height: 22 * s, borderRadius: 4 * s, background: a.iconColor, opacity: 0.8 }} />
              </div>
              <span style={{ fontSize: 14 * s, fontWeight: 600, color: C.label }}>{a.label}</span>
            </div>
          ))}
        </div>
        {/* Preview */}
        <div style={{ background: C.card, borderRadius: 16 * s, padding: `${14 * s}px ${18 * s}px`, width: "100%", marginBottom: 18 * s, display: "flex", alignItems: "center", gap: 10 * s }}>
          <div style={{ width: 48 * s, height: 48 * s, borderRadius: 14 * s, background: `${C.orange}15`, display: "flex", alignItems: "center", justifyContent: "center" }}>
            <div style={{ width: 22 * s, height: 22 * s, borderRadius: 4 * s, background: C.orange, opacity: 0.8 }} />
          </div>
          <span style={{ fontSize: 14 * s, fontWeight: 600, color: C.label }}>Preview Code</span>
        </div>
        {/* Scan Again */}
        <div style={{ background: C.blue, borderRadius: 16 * s, padding: `${16 * s}px`, width: "100%", textAlign: "center", color: "#fff", fontWeight: 700, fontSize: 18 * s, display: "flex", alignItems: "center", justifyContent: "center", gap: 10 * s, boxShadow: "0 4px 12px rgba(0,122,255,0.3)" }}>
          <SFCamera size={20 * s} /> Scan Another
        </div>
      </div>
      <IOSTabBar activeTab={0} s={s} />
    </div>
  );
}

function ScreenSettings({ s = 1 }: { s?: number }) {
  const rows = [
    { icon: "🌐", color: C.blue, title: "Language", sub: "English", chevron: true },
  ];
  const scannerRows = [
    { icon: "👆", color: C.blue, title: "Haptic Feedback", sub: "Vibrate when scanning", on: true },
    { icon: "🔊", color: C.purple, title: "Sound", sub: "Play sound when scanning", on: true },
    { icon: "📋", color: C.green, title: "Auto-Copy", sub: "Copy scanned content automatically", on: false },
    { icon: "🔗", color: C.orange, title: "Scan and Go", sub: "Open URLs automatically after scanning", on: false },
    { icon: "📚", color: C.indigo, title: "Multi-Code Scanning", sub: "Scan multiple codes before viewing results", on: false },
  ];

  function SettingsSection({ title, children }: { title: string; children: React.ReactNode }) {
    return (
      <div style={{ marginBottom: 18 * s }}>
        <div style={{ fontSize: 13 * s, fontWeight: 600, color: C.secondary, marginLeft: 20 * s, marginBottom: 6 * s, letterSpacing: 0.5 * s }}>{title}</div>
        <div style={{ marginLeft: 16 * s, marginRight: 16 * s, background: C.card, borderRadius: 12 * s, overflow: "hidden" }}>{children}</div>
      </div>
    );
  }

  function SettingsRow({ icon, iconColor, title, subtitle, isToggle, toggleOn, chevron, subValue }: { icon: string; iconColor: string; title: string; subtitle?: string; isToggle?: boolean; toggleOn?: boolean; chevron?: boolean; subValue?: string }) {
    return (
      <div style={{ display: "flex", alignItems: "center", padding: `${12 * s}px ${16 * s}px`, gap: 14 * s }}>
        <div style={{ width: 30 * s, height: 30 * s, borderRadius: 7 * s, background: iconColor, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 15 * s, flexShrink: 0 }}>{icon}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 17 * s, color: C.label }}>{title}</div>
          {subtitle && <div style={{ fontSize: 13 * s, color: C.tertiary, marginTop: 1 * s }}>{subtitle}</div>}
        </div>
        {isToggle && (
          <div style={{ width: 51 * s, height: 31 * s, borderRadius: 16 * s, background: toggleOn ? C.green : "#E9E9EB", position: "relative", flexShrink: 0 }}>
            <div style={{ width: 27 * s, height: 27 * s, borderRadius: 14 * s, background: "#fff", position: "absolute", top: 2 * s, left: toggleOn ? 22 * s : 2 * s, boxShadow: "0 2px 4px rgba(0,0,0,0.2)" }} />
          </div>
        )}
        {subValue && <span style={{ fontSize: 17 * s, color: C.tertiary }}>{subValue}</span>}
        {chevron && <span style={{ color: C.tertiary, fontSize: 14 * s }}>›</span>}
      </div>
    );
  }

  return (
    <div style={{ width: "100%", height: "100%", background: C.bg, position: "relative", fontFamily: "-apple-system, system-ui, sans-serif", overflow: "hidden" }}>
      <IOSStatusBar s={s} />
      <IOSLargeHeader title="Settings" s={s} />
      <div style={{ overflowY: "hidden" }}>
        <SettingsSection title="GENERAL">
          <SettingsRow icon="🌐" iconColor={C.blue} title="Language" subValue="English" chevron />
        </SettingsSection>
        <SettingsSection title="SCANNER">
          {scannerRows.map((row, i) => (
            <div key={row.title}>
              <SettingsRow icon={row.icon} iconColor={row.color} title={row.title} subtitle={row.sub} isToggle toggleOn={row.on} />
              {i < scannerRows.length - 1 && <div style={{ height: 0.5 * s, background: C.separator, marginLeft: 60 * s }} />}
            </div>
          ))}
        </SettingsSection>
        <SettingsSection title="HISTORY">
          <SettingsRow icon="🕐" iconColor={C.orange} title="Save Scan History" subtitle="Keep a record of scanned items" isToggle toggleOn />
          <div style={{ height: 0.5 * s, background: C.separator, marginLeft: 60 * s }} />
          <SettingsRow icon="🔒" iconColor={C.green} title="Require Face ID" subtitle="Protect history with authentication" isToggle toggleOn={false} />
        </SettingsSection>
      </div>
      <IOSTabBar activeTab={3} s={s} />
    </div>
  );
}

// ─── Slide Definitions ───────────────────────────────────────────────────────
interface SlideProps { W: number; H: number; device: Device }

function Slide1({ W, H, device }: SlideProps) {
  const D = device === "iphone" ? Phone : IPad;
  const dw = device === "iphone" ? "82%" : "65%";
  const sc = device === "iphone" ? 1 : 1.3;
  return (
    <div style={{ width: W, height: H, background: "linear-gradient(168deg, #001B44 0%, #003580 30%, #0060D0 60%, #007AFF 100%)", position: "relative", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ position: "absolute", width: W * 0.9, height: W * 0.9, borderRadius: "50%", background: "radial-gradient(circle, rgba(0,122,255,0.25) 0%, transparent 65%)", top: "2%", left: "50%", transform: "translateX(-50%)" }} />
      <div style={{ marginTop: H * 0.075, zIndex: 2, padding: `0 ${W * 0.08}px` }}>
        <Caption label="QR & Barcode Scanner" headline="Scan any code<br/>in a flash." W={W} />
      </div>
      <div style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(13%)", width: dw, zIndex: 1 }}>
        <D><ScreenScanner s={sc} /></D>
      </div>
    </div>
  );
}

function Slide2({ W, H, device }: SlideProps) {
  const D = device === "iphone" ? Phone : IPad;
  const dw = device === "iphone" ? "82%" : "65%";
  const sc = device === "iphone" ? 1 : 1.3;
  return (
    <div style={{ width: W, height: H, background: "linear-gradient(168deg, #0D0D1C 0%, #12122E 25%, #1C1C50 55%, #2A1B60 100%)", position: "relative", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ position: "absolute", width: W * 0.6, height: W * 0.6, borderRadius: "50%", background: "radial-gradient(circle, rgba(88,86,214,0.2) 0%, transparent 65%)", top: "15%", right: "-5%" }} />
      <div style={{ marginTop: H * 0.075, zIndex: 2, padding: `0 ${W * 0.08}px` }}>
        <Caption label="Generate" headline="Create codes<br/>your way." W={W} labelColor="rgba(148,128,255,0.75)" />
      </div>
      <div style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(13%)", width: dw, zIndex: 1 }}>
        <D><ScreenGenerator s={sc} /></D>
      </div>
    </div>
  );
}

function Slide3({ W, H, device }: SlideProps) {
  const D = device === "iphone" ? Phone : IPad;
  const dw = device === "iphone" ? "82%" : "65%";
  const sc = device === "iphone" ? 1 : 1.3;
  return (
    <div style={{ width: W, height: H, background: "linear-gradient(168deg, #E3F0FC 0%, #CCE4FF 30%, #B0D4FF 60%, #97C8FF 100%)", position: "relative", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ position: "absolute", width: W * 0.7, height: W * 0.7, borderRadius: "50%", background: "radial-gradient(circle, rgba(0,122,255,0.06) 0%, transparent 65%)", bottom: "30%", left: "-15%" }} />
      <div style={{ marginTop: H * 0.075, zIndex: 2, padding: `0 ${W * 0.08}px` }}>
        <Caption label="History" headline="Every scan,<br/>saved." W={W} color="#001B44" labelColor="rgba(0,60,170,0.6)" />
      </div>
      <div style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(13%)", width: dw, zIndex: 1 }}>
        <D><ScreenHistory s={sc} /></D>
      </div>
    </div>
  );
}

function Slide4({ W, H, device }: SlideProps) {
  const D = device === "iphone" ? Phone : IPad;
  const dw = device === "iphone" ? "82%" : "65%";
  const sc = device === "iphone" ? 1 : 1.3;
  return (
    <div style={{ width: W, height: H, background: "linear-gradient(168deg, #0F1B2D 0%, #132D48 30%, #1A4060 60%, #1F506E 100%)", position: "relative", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ position: "absolute", width: W * 0.5, height: W * 0.5, borderRadius: "50%", background: "radial-gradient(circle, rgba(52,199,89,0.12) 0%, transparent 65%)", top: "10%", left: "15%" }} />
      <div style={{ marginTop: H * 0.075, zIndex: 2, padding: `0 ${W * 0.08}px` }}>
        <Caption label="Instant Actions" headline="Copy, share,<br/>or open." W={W} labelColor="rgba(52,199,89,0.75)" />
      </div>
      <div style={{ position: "absolute", bottom: 0, left: "50%", transform: "translateX(-50%) translateY(13%)", width: dw, zIndex: 1 }}>
        <D><ScreenScanResult s={sc} /></D>
      </div>
    </div>
  );
}

function Slide5({ W, H }: SlideProps) {
  return (
    <div style={{ width: W, height: H, background: "linear-gradient(168deg, #0A0A10 0%, #0F0F18 40%, #141420 100%)", position: "relative", overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      <div style={{ position: "absolute", width: W * 0.7, height: W * 0.7, borderRadius: "50%", background: "radial-gradient(circle, rgba(0,122,255,0.1) 0%, transparent 65%)", top: "3%", left: "50%", transform: "translateX(-50%)" }} />
      <div style={{ marginTop: H * 0.09, width: W * 0.15, height: W * 0.15, borderRadius: W * 0.034, overflow: "hidden", boxShadow: "0 8px 40px rgba(0,122,255,0.25)", marginBottom: H * 0.03, zIndex: 2, flexShrink: 0 }}>
        <img src="/app-icon.png" alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </div>
      <div style={{ zIndex: 2, padding: `0 ${W * 0.08}px`, marginBottom: H * 0.05 }}>
        <Caption label="Designed with care" headline="And so<br/>much more." W={W} labelColor="rgba(255,255,255,0.4)" />
      </div>
      <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: W * 0.018, padding: `0 ${W * 0.06}px`, zIndex: 2 }}>
        {[
          { label: "Flashlight", color: C.yellow },
          { label: "Multi-Code Scan", color: C.indigo },
          { label: "Face ID Lock", color: C.green },
          { label: "Haptic Feedback", color: C.blue },
          { label: "Scan from Photos", color: C.orange },
          { label: "Export to CSV", color: C.purple },
          { label: "3 Languages", color: C.blue },
          { label: "Sound Effects", color: C.red },
          { label: "Auto-Copy", color: C.green },
          { label: "12+ Barcode Types", color: "#FF6B6B" },
        ].map((p) => (
          <div key={p.label} style={{ background: `${p.color}15`, border: `1px solid ${p.color}35`, borderRadius: W * 0.016, padding: `${W * 0.012}px ${W * 0.024}px`, fontSize: W * 0.027, fontWeight: 600, color: p.color, whiteSpace: "nowrap" }}>{p.label}</div>
        ))}
      </div>
      <div style={{ marginTop: H * 0.04, zIndex: 2 }}>
        <div style={{ fontSize: W * 0.022, fontWeight: 600, color: "rgba(255,255,255,0.25)", textTransform: "uppercase", letterSpacing: W * 0.004, marginBottom: W * 0.018, textAlign: "center" }}>Coming Soon</div>
        <div style={{ display: "flex", flexWrap: "wrap", justifyContent: "center", gap: W * 0.018 }}>
          {["Widgets", "Apple Watch", "Batch Export"].map((p) => (
            <div key={p} style={{ background: "rgba(255,255,255,0.04)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: W * 0.016, padding: `${W * 0.01}px ${W * 0.022}px`, fontSize: W * 0.024, fontWeight: 500, color: "rgba(255,255,255,0.25)", whiteSpace: "nowrap" }}>{p}</div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Registry ────────────────────────────────────────────────────────────────
const SLIDES = [Slide1, Slide2, Slide3, Slide4, Slide5];
const SLIDE_NAMES = ["hero-scanner", "generator", "history", "scan-result", "features"];

// ─── Preview + Export ────────────────────────────────────────────────────────
function ScreenshotPreview({ slideIndex, device, W, H, exportW, exportH, onExportRef }: { slideIndex: number; device: Device; W: number; H: number; exportW: number; exportH: number; onExportRef: (idx: number, el: HTMLDivElement | null) => void }) {
  const previewRef = useRef<HTMLDivElement>(null);
  const exportRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const el = previewRef.current;
    if (!el?.parentElement) return;
    const obs = new ResizeObserver((entries) => { setScale(entries[0].contentRect.width / W); });
    obs.observe(el.parentElement);
    return () => obs.disconnect();
  }, [W]);

  useEffect(() => { onExportRef(slideIndex, exportRef.current); }, [slideIndex, onExportRef]);

  const Slide = SLIDES[slideIndex];
  return (
    <>
      <div style={{ width: "100%", aspectRatio: `${W}/${H}`, overflow: "hidden", borderRadius: 12, boxShadow: "0 4px 24px rgba(0,0,0,0.2)" }}>
        <div ref={previewRef} style={{ width: W, height: H, transform: `scale(${scale})`, transformOrigin: "top left" }}>
          <Slide W={W} H={H} device={device} />
        </div>
      </div>
      <div ref={exportRef} style={{ position: "absolute", left: -9999, top: 0, width: exportW, height: exportH, opacity: 0, pointerEvents: "none" }}>
        <div style={{ width: exportW, height: exportH, transform: exportW !== W ? `scale(${exportW / W})` : undefined, transformOrigin: "top left" }}>
          <Slide W={W} H={H} device={device} />
        </div>
      </div>
    </>
  );
}

// ─── Main Page ───────────────────────────────────────────────────────────────
export default function ScreenshotsPage() {
  const [device, setDevice] = useState<Device>("iphone");
  const [sizeIdx, setSizeIdx] = useState(0);
  const [isExporting, setIsExporting] = useState(false);
  const [exportProgress, setExportProgress] = useState("");
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  const sizes = device === "iphone" ? IPHONE_SIZES : IPAD_SIZES;
  const designW = device === "iphone" ? IPHONE_W : IPAD_W;
  const designH = device === "iphone" ? IPHONE_H : IPAD_H;
  const exportSize = sizes[sizeIdx];

  const handleExportRef = useCallback((idx: number, el: HTMLDivElement | null) => { exportRefs.current[idx] = el; }, []);

  const doExport = async (indices: number[]) => {
    setIsExporting(true);
    for (const i of indices) {
      const el = exportRefs.current[i];
      if (!el) continue;
      setExportProgress(`${indices.indexOf(i) + 1}/${indices.length}`);
      el.style.left = "0px"; el.style.opacity = "1"; el.style.zIndex = "-1";
      const opts = { width: exportSize.w, height: exportSize.h, pixelRatio: 1, cacheBust: true };
      try {
        await toPng(el, opts);
        const dataUrl = await toPng(el, opts);
        const link = document.createElement("a");
        link.download = `${String(i + 1).padStart(2, "0")}-${SLIDE_NAMES[i]}-${device}-${exportSize.w}x${exportSize.h}.png`;
        link.href = dataUrl; link.click();
      } catch (err) { console.error(err); }
      el.style.left = "-9999px"; el.style.opacity = "0"; el.style.zIndex = "";
      await new Promise((r) => setTimeout(r, 350));
    }
    setExportProgress(""); setIsExporting(false);
  };

  return (
    <div style={{ minHeight: "100vh", background: "#09090b", color: "#fff", fontFamily: "-apple-system, system-ui, sans-serif" }}>
      {/* Toolbar */}
      <div style={{ position: "sticky", top: 0, zIndex: 50, background: "rgba(9,9,11,0.92)", backdropFilter: "blur(20px)", borderBottom: "1px solid rgba(255,255,255,0.08)", padding: "12px 24px", display: "flex", alignItems: "center", gap: 16, flexWrap: "wrap" }}>
        <h1 style={{ fontSize: 17, fontWeight: 700, margin: 0, whiteSpace: "nowrap" }}>📱 App Store Screenshots</h1>
        <div style={{ display: "flex", background: "rgba(255,255,255,0.08)", borderRadius: 8, padding: 2 }}>
          {(["iphone", "ipad"] as Device[]).map((d) => (
            <button key={d} onClick={() => { setDevice(d); setSizeIdx(0); }} style={{ padding: "6px 16px", borderRadius: 6, border: "none", cursor: "pointer", fontSize: 13, fontWeight: 600, background: device === d ? "#fff" : "transparent", color: device === d ? "#000" : "rgba(255,255,255,0.5)", transition: "all 0.15s" }}>{d === "iphone" ? "iPhone" : "iPad"}</button>
          ))}
        </div>
        <select value={sizeIdx} onChange={(e) => setSizeIdx(Number(e.target.value))} style={{ background: "rgba(255,255,255,0.08)", color: "#fff", border: "1px solid rgba(255,255,255,0.12)", borderRadius: 8, padding: "6px 12px", fontSize: 13, cursor: "pointer" }}>
          {sizes.map((s, i) => (<option key={i} value={i} style={{ color: "#000" }}>{s.label} ({s.w}×{s.h})</option>))}
        </select>
        <button onClick={() => doExport([...Array(SLIDES.length).keys()])} disabled={isExporting} style={{ marginLeft: "auto", background: isExporting ? "rgba(255,255,255,0.08)" : C.blue, color: "#fff", border: "none", borderRadius: 8, padding: "8px 20px", fontSize: 14, fontWeight: 600, cursor: isExporting ? "wait" : "pointer" }}>
          {isExporting ? `Exporting ${exportProgress}...` : "⬇ Export All"}
        </button>
      </div>
      {/* Grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: 24, padding: 24, maxWidth: 1600, margin: "0 auto" }}>
        {SLIDES.map((_, i) => (
          <div key={`${device}-${i}`} style={{ position: "relative" }}>
            <div style={{ marginBottom: 8, display: "flex", justifyContent: "space-between", alignItems: "center" }}>
              <span style={{ fontSize: 13, color: "rgba(255,255,255,0.4)", fontWeight: 500 }}>{String(i + 1).padStart(2, "0")} — {SLIDE_NAMES[i]}</span>
              <button onClick={() => doExport([i])} style={{ background: "rgba(255,255,255,0.06)", color: "rgba(255,255,255,0.5)", border: "1px solid rgba(255,255,255,0.08)", borderRadius: 6, padding: "4px 10px", fontSize: 12, cursor: "pointer" }}>⬇ Export</button>
            </div>
            <ScreenshotPreview slideIndex={i} device={device} W={designW} H={designH} exportW={exportSize.w} exportH={exportSize.h} onExportRef={handleExportRef} />
          </div>
        ))}
      </div>
    </div>
  );
}
