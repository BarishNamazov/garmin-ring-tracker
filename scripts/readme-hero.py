#!/usr/bin/env python3
"""Generate docs/readme-hero.svg. Render with:
    rsvg-convert -w 1440 -h 720 docs/readme-hero.svg -o docs/readme-hero.png
Requires the Inter font."""
import math
W, H = 1440, 720
cx, cy = 1030, 360
R_CASE, R_BEZEL_IN, R_SCREEN, R_ARC, ARC_W = 272, 244, 236, 222, 15

def pt(r, deg):
    a = math.radians(deg)
    return cx + r * math.sin(a), cy - r * math.cos(a)

def arc(r, a0, a1):
    x0, y0 = pt(r, a0); x1, y1 = pt(r, a1)
    large = 1 if (a1 - a0) > 180 else 0
    return f"M{x0:.2f},{y0:.2f} A{r},{r} 0 {large} 1 {x1:.2f},{y1:.2f}"

elapsed = 4 / 28 * 360
ticks = []
for i in range(60):
    major = i % 5 == 0
    x0, y0 = pt(R_CASE - 6, i * 6); x1, y1 = pt(R_CASE - (20 if major else 12), i * 6)
    ticks.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" stroke="#{"8a939b" if major else "4a5157"}" stroke-width="{3 if major else 1.5}" stroke-linecap="round"/>')

def button(deg, side):
    x, y = pt(R_CASE + 4, deg)
    w, h = 16, 44
    return f'<rect x="{x - w/2:.1f}" y="{y - h/2:.1f}" width="{w}" height="{h}" rx="5" fill="url(#btn)" transform="rotate({deg - 90 if side > 0 else deg + 90:.1f} {x:.1f} {y:.1f})"/>'

dx, dy = pt(R_ARC, elapsed)
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0B1119"/><stop offset="1" stop-color="#05070B"/>
    </linearGradient>
    <radialGradient id="glowG" cx="{cx - 60}" cy="{cy + 40}" r="420" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#38D6A0" stop-opacity="0.22"/><stop offset="1" stop-color="#38D6A0" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glowP" cx="{cx - 140}" cy="{cy - 170}" r="300" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#A690FF" stop-opacity="0.20"/><stop offset="1" stop-color="#A690FF" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="case" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#5A6168"/><stop offset="0.45" stop-color="#2A2F34"/><stop offset="1" stop-color="#121518"/>
    </linearGradient>
    <linearGradient id="bezel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#23272B"/><stop offset="1" stop-color="#15181B"/>
    </linearGradient>
    <linearGradient id="strap" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#15191D"/><stop offset="0.5" stop-color="#262B30"/><stop offset="1" stop-color="#15191D"/>
    </linearGradient>
    <linearGradient id="btn" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#6A727A"/><stop offset="1" stop-color="#2A2F34"/>
    </linearGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#000" flood-opacity="0.65"/>
    </filter>
  </defs>

  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <rect width="{W}" height="{H}" fill="url(#glowG)"/>
  <rect width="{W}" height="{H}" fill="url(#glowP)"/>

  <g font-family="Inter">
    <text x="90" y="336" font-size="98" font-weight="700" letter-spacing="-2.5" fill="#F4F7F8">Ring Tracker</text>
    <text x="94" y="400" font-size="33" font-weight="400" fill="#9AA6AD">Your NuvaRing schedule, on your wrist.</text>
    <g font-size="22" font-weight="500" fill="#B2BAC1">
      <circle cx="103" cy="472" r="8" fill="#38D6A0"/><text x="122" y="480">Ring in · 3 weeks</text>
      <circle cx="341" cy="472" r="8" fill="#A690FF"/><text x="360" y="480">Ring-free · 1 week</text>
    </g>
  </g>

  <g filter="url(#shadow)">
    <path d="M{cx-120},-20 L{cx+120},-20 L{cx+135},{cy-200} L{cx-135},{cy-200} Z" fill="url(#strap)"/>
    <path d="M{cx-135},{cy+200} L{cx+135},{cy+200} L{cx+120},{H+20} L{cx-120},{H+20} Z" fill="url(#strap)"/>
    {button(60, 1)}{button(120, 1)}{button(-60, -1)}{button(-90, -1)}{button(-120, -1)}
    <circle cx="{cx}" cy="{cy}" r="{R_CASE + 6}" fill="url(#case)"/>
    <circle cx="{cx}" cy="{cy}" r="{R_CASE}" fill="url(#bezel)"/>
  </g>
  {''.join(ticks)}
  <circle cx="{cx}" cy="{cy}" r="{R_BEZEL_IN}" fill="#07090B"/>
  <circle cx="{cx}" cy="{cy}" r="{R_SCREEN}" fill="#000"/>

  <g fill="none" stroke-width="{ARC_W}">
    <path d="{arc(R_ARC, 0, elapsed)}" stroke="#196047"/>
    <path d="{arc(R_ARC, elapsed, 270)}" stroke="#38D6A0"/>
    <path d="{arc(R_ARC, 270, 360)}" stroke="#645699"/>
  </g>
  <circle cx="{dx:.2f}" cy="{dy:.2f}" r="10" fill="#F4F7F8" stroke="#000" stroke-width="3"/>

  <g font-family="Inter" text-anchor="middle">
    <text x="{cx}" y="{cy - 92}" font-size="37" font-weight="700" letter-spacing="1.5" fill="#38D6A0">RING IN</text>
    <text x="{cx - 8}" y="{cy + 42}" font-size="150" font-weight="600" letter-spacing="-4" fill="#F4F7F8">17<tspan dx="10" font-size="48" font-weight="700">d</tspan></text>
    <text x="{cx}" y="{cy + 100}" font-size="34" font-weight="600" fill="#9AA6AD">Remove · <tspan fill="#F4F7F8">4 Oct</tspan></text>
    <text x="{cx}" y="{cy + 140}" font-size="34" font-weight="600" fill="#F4F7F8">12:26 PM</text>
  </g>

  <circle cx="{cx}" cy="{cy}" r="{R_SCREEN}" fill="none" stroke="#fff" stroke-opacity="0.05" stroke-width="2"/>
</svg>
'''
import sys
open(sys.argv[1], 'w').write(svg)
