# Fitness Watch — Project Plan (V1)

> Working title: **fitness-watch** (placeholder)
> Status: Planning
> Audience: Personal use only (no App Store release for now)

---

## 1. What we're building

An **Apple Watch + iPhone** app that tracks strength workouts with minimal manual logging.

You start a workout on the watch, lift, and the watch:

1. **Classifies** which exercise you're doing (from wrist motion)
2. **Counts reps** for that set
3. Lets you **correct** mistakes with a tap
4. Syncs history to the iPhone and (later) Apple Health

V1 proves the core idea works **for you**, on your left wrist, at a commercial gym — not a polished consumer product.

### Inspiration
Apps like Motra. We train our own model on our own data; we are not copying anyone's method.

### How "automatic" works
You **manually tap Start Workout**. Detection runs automatically *inside* that session.  
If another fitness app is tracking, **pause/stop it first** so this app can own the `HKWorkoutSession` (required for reliable background sensing on watchOS).

---

## 2. V1 exercise set

| # | Exercise | Equipment |
|---|----------|-----------|
| 1 | Bench press | Barbell or dumbbell |
| 2 | Shoulder press | Machine |
| 3 | Dumbbell curls | Dumbbell |
| 4 | Lat pulldown | Machine |
| 5 | Tricep pushdown | Machine |
| — | **Rest / other** | Walking, resting, fidgeting, adjusting watch, etc. |

`rest / other` is required so the app does not invent reps between sets.

---

## 3. Success criteria (personal V1)

| Metric | Target |
|--------|--------|
| Exercise classification (on your data / held-out sessions) | Feels reliable in the gym; aim ~80%+ correct labels |
| Rep count | Within **±1 rep** on most sets |
| False reps while resting | Rare |
| Latency | Label appears within a few seconds of starting a set |
| Battery | A normal gym session doesn't kill the watch |
| Usability | One-handed watch UI you can use alone between sets |

Accuracy bar: **middle ground** — good enough to trust for personal tracking, not research-grade.

---

## 4. Tech stack

### Apps (Watch + iPhone)
| Area | Choice | Why |
|------|--------|-----|
| Language | Swift | Native watchOS / iOS |
| UI | SwiftUI | Shared patterns, fast iteration |
| Motion | Core Motion (`CMMotionManager`) | Accel, gyro, gravity/attitude |
| Workout session | HealthKit (`HKWorkoutSession`, `HKLiveWorkoutBuilder`) | Keeps watch app alive during workouts |
| Watch ↔ phone | WatchConnectivity | Sync workouts + CSV files |
| Local storage | SwiftData | Workout history on phone |
| On-device ML | Core ML | Inference on watch |
| IDE | Xcode (+ Cursor for editing / agent) | Required for Watch builds & signing |

### Machine learning (offline, on Mac)
| Area | Choice | Why |
|------|--------|-----|
| First model path | **Create ML** Activity Classifier | Fastest path to a `.mlmodel` that runs on watch; fits middle-ground accuracy |
| Fallback / upgrade | PyTorch 1D CNN + `coremltools` | If Create ML isn't accurate enough |
| Baseline / exploration | Python + pandas / NumPy / SciPy | Plot signals, prototype rep counting |
| Notebooks | Jupyter (optional) | Exploration |

### Backend
| Area | Choice | Why |
|------|--------|-----|
| Training data upload | **Supabase** (Auth optional, Storage + Postgres) | Upload CSVs from gym sessions without cables |
| Auth for V1 | Simple (personal account / anon key carefully scoped) | Solo use |

### Tooling
| Area | Choice |
|------|--------|
| Editor | Cursor |
| Build / run / device | Xcode |
| Cursor ↔ Xcode | Xcode MCP (`mcpbridge`) when enabled — agent can trigger builds/tests; Xcode still required for Watch + HealthKit on device |

---

## 5. Architecture (high level)

```
┌──────────────────────────── Apple Watch ────────────────────────────┐
│  Start Workout → HKWorkoutSession                                    │
│  Core Motion (accel + gyro + gravity, ~50–100 Hz)                    │
│        │                                                             │
│        ▼                                                             │
│  Sliding windows (2–4 s, ~50% overlap)                               │
│        ├──► Core ML classifier → exercise + confidence               │
│        └──► Rep counter (filter + peaks) → rep count                 │
│  State machine: idle → exercising → resting                          │
│  Correction UI + data-collection recorder                            │
└───────────────┬──────────────────────────────────────────────────────┘
                │ WatchConnectivity
                ▼
┌──────────────────────────── iPhone ──────────────────────────────────┐
│  History (SwiftData) · edits · HealthKit export (later phases)       │
│  Upload recordings → Supabase Storage                                │
└──────────────────────────────────────────────────────────────────────┘

        Offline (Mac): Create ML (or PyTorch) → .mlmodel → Xcode
```

---

## 6. Phases

| Phase | Name | Goal | Done when |
|-------|------|------|-----------|
| **0** | Setup | Project, signing, HealthKit capability, repo hygiene | App builds to your iPhone + Watch |
| **1** | Recorder | Labeled motion capture → iPhone → Supabase (no long-term Watch storage) | You can record a labeled set at the gym and see the file in Supabase |
| **2** | Dataset | Collect personal data for all 5 exercises + other | Roughly dozens of sets per exercise; signals plotted and sanity-checked |
| **3** | Prototype ML | Train Create ML classifier + simple rep counter offline | Measured accuracy on held-out sessions; decide ship vs iterate |
| **4** | On-watch inference | Live label + rep count during a workout | Usable live detection on your wrist |
| **5** | App shell | History, corrections, Health export | End-to-end personal tracker |
| **6** | Gym hardening | Real sessions, fix failure modes, retrain | Stable enough for daily use |

Detailed breakdown for Phase 1 lives in [`phase-1-recorder.md`](./phase-1-recorder.md).

### Phase 0 — Setup (short)
- Confirm Apple Developer / device signing for Watch
- Enable HealthKit + Motion usage descriptions
- Keep placeholder branding
- Confirm Cursor MCP optional; primary run path is Xcode → device

### Phase 1 — Recorder
See dedicated doc. Delivers the data pipeline everything else depends on.

### Phase 2 — Dataset
- Record at the commercial gym (alone), left wrist
- Mix weights, reps (~8–12), rest/other noise
- Log true rep counts per set
- Upload via Supabase; keep local CSV backup

### Phase 3 — Prototype ML
- Format data for Create ML Activity Classifier
- Train, evaluate on held-out days/sessions (not random windows only)
- Prototype peak-based rep counting in Python; tune per exercise
- Export `.mlmodel` if classification looks good enough

### Phase 4 — On-watch inference
- Bundle Core ML model in Watch app
- Windowing + smoothing + confidence threshold
- Rep counter while exercise is active
- Basic workout UI: exercise, reps, set, rest

### Phase 5 — App shell
- iPhone history list + detail + edit/delete
- Correction feedback loop (store corrections for future training)
- HealthKit workout save
- Settings: wrist = left, privacy notes for yourself

### Phase 6 — Gym hardening
- Confusion pairs (e.g. similar pressing motions)
- Battery / sample-rate tradeoffs
- Retrain with correction data
- UX tweaks for one-handed gym use

---

## 7. Explicitly out of scope (V1)

- App Store / TestFlight marketing / payments
- Social features, AI programming, recovery estimates
- Weight estimation from motion
- Large exercise libraries
- Android / Wear OS
- Running alongside another active workout tracker

---

## 8. Risks (keep in mind)

| Risk | Mitigation |
|------|------------|
| Not enough / too-similar data | Structured collection checklist; record `other` deliberately |
| Machine exercises look similar on the wrist | Start with Create ML; add more sets for confused pairs |
| watchOS background limits | Always start our workout session; pause other trackers |
| Battery drain | Tune Hz and inference frequency after Phase 4 works |
| Supabase keys on device | Personal project: restrict policies; don't ship public |

---

## 9. Immediate next step

**Phase 1 — build the recorder.**  
Open [`phase-1-recorder.md`](./phase-1-recorder.md) and implement against that checklist.
