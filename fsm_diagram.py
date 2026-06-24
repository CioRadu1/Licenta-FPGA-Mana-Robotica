#!/usr/bin/env python3
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

fig, ax = plt.subplots(1, 1, figsize=(18, 14))
ax.set_xlim(-1, 17)
ax.set_ylim(-1, 13)
ax.axis('off')
ax.set_aspect('equal')

BLUE = '#2C3E50'
TEAL = '#007B7F'
ORANGE = '#E67E22'
RED = '#C0392B'
GREEN = '#27AE60'
PURPLE = '#8E44AD'
LIGHT_BLUE = '#D6EAF2'
LIGHT_TEAL = '#D0ECE7'
LIGHT_ORANGE = '#FDEBD0'
LIGHT_GREEN = '#D5F5E3'
LIGHT_RED = '#FADBD8'
LIGHT_PURPLE = '#E8DAEF'
WHITE = '#FFFFFF'

def state_circle(x, y, name, color=LIGHT_BLUE, edge=BLUE, r=0.7, fontsize=8):
    circle = plt.Circle((x, y), r, facecolor=color, edgecolor=edge, linewidth=2)
    ax.add_patch(circle)
    ax.text(x, y, name, ha='center', va='center', fontsize=fontsize,
            fontweight='bold', color=BLUE, linespacing=1.2)

def arrow(x1, y1, x2, y2, color=BLUE, lw=1.5, r=0.7):
    dx = x2 - x1
    dy = y2 - y1
    dist = np.sqrt(dx**2 + dy**2)
    ux = dx / dist
    uy = dy / dist
    sx = x1 + ux * r
    sy = y1 + uy * r
    ex = x2 - ux * r
    ey = y2 - uy * r
    ax.annotate('', xy=(ex, ey), xytext=(sx, sy),
                arrowprops=dict(arrowstyle='->', color=color, lw=lw))

def curved_arrow(x1, y1, x2, y2, color=RED, lw=2, rad=0.3, r=0.7):
    dx = x2 - x1
    dy = y2 - y1
    dist = np.sqrt(dx**2 + dy**2)
    ux = dx / dist
    uy = dy / dist
    sx = x1 + ux * r
    sy = y1 + uy * r
    ex = x2 - ux * r
    ey = y2 - uy * r
    ax.annotate('', xy=(ex, ey), xytext=(sx, sy),
                arrowprops=dict(arrowstyle='->', color=color, lw=lw,
                                connectionstyle=f'arc3,rad={rad}',
                                linestyle='--'))

# ── State positions ──

# Row 0 (top) - Init and Idle
states = {
    'INIT_RAM':    (2, 12,   LIGHT_ORANGE, ORANGE),
    'IDLE':        (6, 12,   LIGHT_GREEN, GREEN),
    'LOAD':        (10, 12,  LIGHT_BLUE, BLUE),

    # Row 1 - Predict
    'PREDICT_X':   (14, 10,  LIGHT_TEAL, TEAL),
    'PREDICT\nP00': (10, 10, LIGHT_TEAL, TEAL),
    'PREDICT\nP01': (6, 10,  LIGHT_TEAL, TEAL),
    'PREDICT\nP11': (2, 10,  LIGHT_TEAL, TEAL),

    # Row 2 - Update
    'UPDATE_S':    (2, 7.5,  LIGHT_ORANGE, ORANGE),
    'UPDATE\nK0':  (6, 7.5,  LIGHT_BLUE, BLUE),
    'UPDATE\nK1':  (10, 7.5, LIGHT_BLUE, BLUE),
    'UPDATE_X':    (14, 7.5, LIGHT_BLUE, BLUE),

    # Row 3 - Store and output
    'UPDATE_P':    (14, 5,   LIGHT_BLUE, BLUE),
    'STORE':       (10, 5,   LIGHT_PURPLE, PURPLE),
    'NEXT_CH':     (6, 5,    LIGHT_ORANGE, ORANGE),
    'OUTPUT':      (2, 5,    LIGHT_GREEN, GREEN),
}

# Draw states
for name, (x, y, fc, ec) in states.items():
    state_circle(x, y, name, fc, ec)

# ── Normal flow arrows ──

# INIT_RAM -> IDLE
arrow(2, 12, 6, 12)
ax.text(4, 12.3, 'done', fontsize=7, color=BLUE, ha='center', style='italic')

# IDLE -> LOAD
arrow(6, 12, 10, 12)
ax.text(8, 12.3, 'tick 20ms', fontsize=7, color=GREEN, ha='center', style='italic')

# LOAD -> PREDICT_X
arrow(10, 12, 14, 10)

# PREDICT_X -> PREDICT_P00
arrow(14, 10, 10, 10)

# PREDICT_P00 -> PREDICT_P01
arrow(10, 10, 6, 10)

# PREDICT_P01 -> PREDICT_P11
arrow(6, 10, 2, 10)

# PREDICT_P11 -> UPDATE_S
arrow(2, 10, 2, 7.5)

# UPDATE_S -> UPDATE_K0
arrow(2, 7.5, 6, 7.5)
ax.text(4, 7.8, '|y| < 30', fontsize=7, color=GREEN, ha='center', style='italic')

# UPDATE_K0 -> UPDATE_K1
arrow(6, 7.5, 10, 7.5)

# UPDATE_K1 -> UPDATE_X
arrow(10, 7.5, 14, 7.5)

# UPDATE_X -> UPDATE_P
arrow(14, 7.5, 14, 5)

# UPDATE_P -> STORE
arrow(14, 5, 10, 5)

# STORE -> NEXT_CH
arrow(10, 5, 6, 5)

# NEXT_CH -> OUTPUT
arrow(6, 5, 2, 5)
ax.text(4, 5.3, 'ch = 7', fontsize=7, color=GREEN, ha='center', style='italic')

# NEXT_CH -> LOAD (loop back)
curved_arrow(6, 5, 10, 12, color=TEAL, lw=1.8, rad=-0.4)
ax.text(9.2, 8.8, 'ch < 7\nch++', fontsize=7, color=TEAL, ha='center', style='italic')

# OUTPUT -> IDLE
arrow(2, 5, 6, 12)
ax.text(3.2, 8.8, 'done', fontsize=7, color=GREEN, ha='center', style='italic')

# ── BYPASS: UPDATE_S -> STORE (|y| > 30 deg) ──
curved_arrow(2, 7.5, 10, 5, color=RED, lw=2.5, rad=0.4)
ax.text(4.5, 5.5, 'BYPASS\n|y| > 30 grade', fontsize=8, color=RED,
        ha='center', fontweight='bold')

# ── BYPASS: LOAD -> STORE (first run) ──
curved_arrow(10, 12, 10, 5, color=RED, lw=2.5, rad=0.5)
ax.text(12.2, 8.5, 'BYPASS\nprima rulare', fontsize=8, color=RED,
        ha='center', fontweight='bold')

# ── Legend ──
legend_x = 0
legend_y = 2.5
ax.text(legend_x, legend_y, 'Legenda:', fontsize=10, fontweight='bold', color=BLUE)

items = [
    (LIGHT_ORANGE, ORANGE, 'Decizie / Init'),
    (LIGHT_TEAL, TEAL, 'Predictie'),
    (LIGHT_BLUE, BLUE, 'Actualizare'),
    (LIGHT_PURPLE, PURPLE, 'Stocare'),
    (LIGHT_GREEN, GREEN, 'Idle / Output'),
]
for i, (fc, ec, label) in enumerate(items):
    yy = legend_y - 0.7 - i * 0.6
    circ = plt.Circle((legend_x + 0.3, yy), 0.2, facecolor=fc, edgecolor=ec, linewidth=1.5)
    ax.add_patch(circ)
    ax.text(legend_x + 0.7, yy, label, fontsize=9, color=BLUE, va='center')

ax.plot([legend_x + 5, legend_x + 6.5], [legend_y - 0.7, legend_y - 0.7],
        color=RED, lw=2, linestyle='--')
ax.annotate('', xy=(legend_x + 6.5, legend_y - 0.7), xytext=(legend_x + 6.3, legend_y - 0.7),
            arrowprops=dict(arrowstyle='->', color=RED, lw=2))
ax.text(legend_x + 6.8, legend_y - 0.7, 'Bypass (ocolire filtru)', fontsize=9, color=RED, va='center')

# Title
ax.text(8, 13.3, 'Diagrama starilor FSM — Filtrul Kalman', ha='center', va='center',
        fontsize=16, fontweight='bold', color=BLUE)
ax.text(8, 12.9, '14 stari, multiplexat temporal pe 8 canale servo', ha='center', va='center',
        fontsize=10, color=BLUE, style='italic')

plt.tight_layout()
plt.savefig('/home/rciobanu/Theseis/thesis/fsm_diagram.png', dpi=200, bbox_inches='tight',
            facecolor='white')
plt.savefig('/home/rciobanu/Theseis/thesis/fsm_diagram.pdf', bbox_inches='tight',
            facecolor='white')
print("Saved fsm_diagram.png and .pdf")
