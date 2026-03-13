# Top 3 Features for the HR-ERG Cycling App

This document summarizes the **top 3 features** to prioritize for the first strong version of the app, with practical detail for implementation.

---

## 1. HR-Controlled ERG

### What it is
This is the core differentiator of the app.

Instead of holding a fixed power target like normal ERG mode, the app adjusts trainer power to keep the rider near a **target heart rate**. This makes the session respond to fatigue, heat, sleep, dehydration, and day-to-day variation.

### Why it matters
Most indoor cycling apps are built around **power-based ERG**. That is good for intervals, but it is less ideal for long endurance work because heart rate can drift upward while power stays fixed.

A strong HR-ERG mode gives riders a way to do:
- Zone 2 training
- endurance rides
- fatigue-aware steady sessions
- “internal load” based training instead of fixed external load

This is one of the few features that clearly separates the app from Zwift-style platforms.

### Recommended implementation
Use the logic already discussed:

- Read HR continuously from the BLE HR monitor
- Calculate a **1-minute moving average HR**
- Run the control loop every **20 seconds**
- Compare average HR to target HR
- Adjust power gradually based on HR deviation

### Example control table
| HR deviation from target | Power adjustment |
|---|---:|
| +1 bpm | -3 W/min |
| +2 bpm | -6 W/min |
| +3 bpm or more | -10 W/min |
| -1 bpm | +3 W/min |
| -2 bpm | +6 W/min |
| -3 bpm or less | +10 W/min |

Then scale this to the 20-second loop.

### Important implementation details
- Use smoothing to avoid oscillation
- Clamp power to safe min/max values
- Support FTMS trainers
- Auto-reconnect BLE devices if connection drops
- Allow simple target changes during the ride

### Minimum user interface
The first version can stay very simple:

- Current HR
- Target HR
- Current power
- Cadence
- Trainer connection status
- HR monitor connection status

### Why this should be feature #1
Because it is the most unique part of the product and the easiest thing to explain:

> “Your trainer automatically adjusts power to hold your target heart rate.”

That is clear, useful, and different.

---

## 2. Aerobic Drift / Durability Detection

### What it is
This feature tells the rider whether the effort stayed truly aerobic over time.

A rider can feel like they are staying in Zone 2, but if HR drifts up or power fades over a long ride, the effort may not be as sustainable as it looked at the start.

This feature makes the app more than just a trainer controller. It becomes a physiology tool.

### Why it matters
Cyclists doing endurance training increasingly care about:
- cardiac drift
- aerobic durability
- whether a power level is really sustainable
- whether the ride stayed in the intended training zone

Most apps either do not calculate this at all, or they make it too hidden or too complicated.

### Recommended implementation
Calculate at least **two metrics**:

#### A. Power Fade
A simple user-facing metric.

Compare:
- an early steady 20-minute window
- the final steady 20-minute window

Formula:

`power_fade_percent = ((early_power - late_power) / early_power) * 100`

This is easy for riders to understand.

#### B. Aerobic Drift
A more physiological metric.

Compare the ratio of power to heart rate between the same windows.

Formula:

`drift_percent = (((early_power / early_hr) - (late_power / late_hr)) / (early_power / early_hr)) * 100`

This is closer to classic decoupling.

### Excluding warm-up and cooldown
For a 2-hour ride with:
- 10-minute ramp-up
- 5-minute ramp-down

Use trimmed analysis only.

Recommended windows:
- Early window: minutes **20–40**
- Late window: minutes **95–115**

This avoids warm-up contamination and avoids the cooldown.

### Suggested interpretation
| Drift | Meaning |
|---|---|
| < 3% | Very steady aerobic ride |
| 3–5% | Good upper Zone 2 range |
| 5–7% | Borderline / quite hard |
| > 7% | Likely above durable Zone 2 |

### Useful rider feedback
The app could show messages like:
- “Aerobic drift low: effort remained steady.”
- “Drift moderate: this may be near your upper Zone 2.”
- “Drift high: effort may be above sustainable aerobic range.”

### Why this should be feature #2
Because this gives the app **real training intelligence**. It is not just controlling the trainer; it is helping the rider understand what the session meant.

This is also one of the best ways to make the app interesting to serious cyclists.

---

## 3. Automatic Zone 2 Estimation

### What it is
This feature helps the rider estimate their practical Zone 2 power from real riding data rather than guessing or relying only on lab-style thresholds.

The app uses long steady rides plus drift analysis to suggest the rider’s likely sustainable aerobic power.

### Why it matters
Cyclists are constantly trying to answer questions like:
- “What is my real Zone 2 power?”
- “Am I riding too easy?”
- “Am I actually drifting into tempo?”
- “Has my endurance improved?”

Most riders do not have a clean, simple answer.

If your app gives them a usable estimate after a long ride, that is very valuable.

### Recommended implementation
After a suitable steady ride, for example 75–120 minutes:

1. Exclude warm-up and cooldown
2. Calculate:
   - average power
   - average HR
   - power fade
   - aerobic drift
3. Use the drift result to classify whether that power was sustainable

### Suggested logic
- If drift is **below 3%**, the rider may have been below upper Zone 2
- If drift is **3–5%**, the ride was probably around upper Zone 2
- If drift is **above 5%**, the effort may be above true durable Zone 2

### Example
Ride result:
- Average power: 188 W
- Average HR: 136 bpm
- Drift: 3.8%

Suggested app output:
- “Estimated upper Zone 2 power: ~188 W”
- “This effort stayed within sustainable aerobic range.”

Another ride:
- Average power: 194 W
- Drift: 6.7%

Suggested output:
- “194 W may be above your durable Zone 2 for long rides.”
- “Suggested Zone 2 range: 186–190 W”

### Best way to present it
Keep it simple. The app could show:

- Estimated Zone 2 power
- Confidence level
- Drift score
- Short explanation

Example:

- **Estimated Zone 2 power:** 188 W  
- **Drift:** 3.8%  
- **Confidence:** Good  
- **Interpretation:** Sustainable aerobic effort

### Why this should be feature #3
Because it turns the app from a ride controller into a coaching tool.

This is also highly marketable. A clear message could be:

> “Automatically find and train your Zone 2 power.”

That is easy for cyclists to understand and care about.

---

# Recommended MVP Order

## 1. HR-Controlled ERG
Build and refine this first.
It is the core product.

## 2. Aerobic Drift / Durability Detection
Add ride intelligence and post-ride feedback.

## 3. Automatic Zone 2 Estimation
Use drift data to generate a practical training recommendation.

---

# Product Positioning

The app should not try to compete head-on with virtual world apps.

It is better positioned as a:

**simple physiology-driven indoor cycling app**

That means:
- minimal UI
- strong HR-based trainer control
- clear post-ride analysis
- useful Zone 2 guidance

A good one-line description would be:

> A simple indoor cycling app that automatically controls power by heart rate and helps you find your real Zone 2.

---

# Final Advice for Implementation

When taking this to Codex, the most important thing is to keep the first release focused.

Avoid adding:
- virtual worlds
- racing
- social features
- huge workout libraries
- complex training plans

Focus on:
- reliability
- BLE stability
- simple UI
- trustworthy training metrics

If those are strong, the app will already be useful and differentiated.
