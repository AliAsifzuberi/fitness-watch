# Phase 1 — Data Recorder

> Parent plan: [`PLAN.md`](./PLAN.md)  
> Goal: Record labeled wrist motion on the Watch, hand it to the iPhone, upload to **Supabase**, and **not** keep CSVs on the Watch.  
> Outcome: Finish a gym set → see the file in Supabase (phone may sit in your pocket).

---

## 1. Why this phase first

Live detection needs training data. Without a reliable recorder, Create ML and Core ML have nothing useful to learn from.

Phase 1 does **not** include classification or rep counting. It only captures ground truth.

---

## 2. Storage philosophy (important)

| Place | Role |
|-------|------|
| Watch **RAM** | Holds samples *during* the set only |
| Watch **disk** | Tiny staging file, deleted after iPhone confirms receipt |
| iPhone disk | Brief holding area until Supabase upload finishes |
| **Supabase** | Permanent home for training CSVs |

We do **not** pile CSVs on the Watch long-term.

---

## 3. User flow (gym, alone, left wrist)

1. Pause/stop any other workout tracker on the Watch.
2. Open **fitness-watch** on Watch **and** leave the iPhone app installed/opened once (so WatchConnectivity can activate).
3. Pick a label → **Start** → do the set → **Stop**.
4. Enter **true reps** (+ optional weight) → **Save & Send to iPhone**.
5. Watch queues a file transfer; when delivered, **Watch file is deleted**.
6. iPhone receives the CSV and **auto-uploads to Supabase** (if `Secrets.plist` is configured).
7. After a successful upload, the phone deletes its local CSV too.

---

## 4. Components

### Watch
- Collection UI, HealthKit session, Core Motion → in-memory buffer
- Short-lived CSV in `RecordingsStaging`
- `PhoneBridge` (`WCSession.transferFile`) → delete on success

### iPhone
- `WatchBridge` receives file → `RecordingStore` index
- `SupabaseUploader` (Storage + `recordings` table via REST)
- UI list + manual retry if auto-upload fails

### Supabase
- See [`supabase-setup.sql`](./supabase-setup.sql)
- Copy `fitness-watch/Secrets.example.plist` → `Secrets.plist` and fill in URL + anon key

---

## 5. CSV format

Same as before: one row per sample, metadata columns repeated.

**Sample rate:** 50 Hz  
**File name:** `{session_id}_{label}.csv`

---

## 6. Setup checklist (you do this once)

### A. Supabase
1. Create a free Supabase project
2. Run [`supabase-setup.sql`](./supabase-setup.sql) in the SQL editor
3. Confirm Storage bucket `motion-recordings` exists
4. Copy Project URL + `anon` key from Project Settings → API

### B. Xcode secrets
1. Duplicate `fitness-watch/Secrets.example.plist` as `fitness-watch/Secrets.plist`
2. Paste your URL and anon key
3. Confirm `Secrets.plist` is in the **fitness-watch** (iPhone) target membership
4. `Secrets.plist` is gitignored — do not commit it

### C. Devices
1. Run the **iPhone** app once on your phone
2. Run the **Watch** app on your watch
3. Allow Health permissions on the Watch

---

## 7. Definition of done

1. Record a labeled set on the Watch  
2. Watch status shows transfer + deletion  
3. iPhone shows the recording, then **Uploaded**  
4. File appears in Supabase Storage + row in `recordings`  

Then → Phase 2 (collect a real dataset).
