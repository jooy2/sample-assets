# Platform sync — 18 June 2026

**Time:** 10:00–10:45 (KST)
**Location:** Meeting room 3 / video bridge
**Chair:** Dana Whitfield
**Notes:** Tomas Beck

## Attendees

- Dana Whitfield (platform lead)
- Marcus Oyelaran (backend)
- Priya Ramanathan (mobile)
- Tomas Beck (infrastructure)
- Ines Alcazar (design) — apologies, joined for item 3 only

## Agenda

1. Import pipeline throughput
2. Mobile release cut
3. Documents upload feature

## 1. Import pipeline throughput

Marcus reported the nightly import now takes 42 minutes, up from 19 in April. The growth
is in the validation stage, not the transfer.

- Validation runs per record; batching by 500 in a spike branch brought it to 24 minutes.
- Nobody could explain the memory profile, so the spike stays behind a flag for now.

**Decision:** merge the batching change behind `IMPORT_BATCH_SIZE`, default off, and
measure for a week before flipping it.

## 2. Mobile release cut

Priya asked to move the cut from Thursday to Monday. Two regressions in the offline queue
are still open, and one has no reproduction.

- Dana pushed back on cutting with an unreproduced bug in the queue.
- Agreed the cut moves only if the reproduction is still missing on Wednesday.

**Decision:** hold the Thursday date, review on Wednesday morning.

## 3. Documents upload feature

Ines walked through the upload states: idle, uploading, converting, done, and three
failure states. The converting state has no design for files above the size limit.

- Tomas noted the limit is enforced at the gateway, so the client never sees the file.
- Ines will add the oversized-file state to the flow this week.

## Action items

| # | Owner   | Action                                                     | Due     |
| - | ------- | ---------------------------------------------------------- | ------- |
| 1 | Marcus  | Merge batching behind `IMPORT_BATCH_SIZE`, default off      | 22 June |
| 2 | Marcus  | Post a week of throughput numbers to the platform channel   | 29 June |
| 3 | Priya   | Chase the offline-queue reproduction, report Wednesday      | 24 June |
| 4 | Ines    | Design the oversized-file state                             | 25 June |
| 5 | Tomas   | Document the gateway size limit in the upload runbook       | 26 June |

## Next meeting

25 June 2026, 10:00. Standing agenda plus the import throughput numbers.
