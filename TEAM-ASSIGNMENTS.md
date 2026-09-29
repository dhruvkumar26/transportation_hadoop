# Team Assignments – 6 Members

**Assignment:** BITS CC ZG522 · Big Data Systems · Assignment 1
**Domain:** Transportation · **Dataset:** NYC TLC Yellow Taxi Trips

## Team roster

| Role | Name | Registration No. |
|---|---|---|
| **Group Leader** | Dhruv Kumar | 2026NS03024 |
| **Presentation Coordinator** | Manikandan B | 2026NS03009 |
| Member | Parepalli Venkata Sai Krishna Mohan | 2026NS03066 |
| Member | Ramya K | 2026NS03046 |
| Member | Varada Sri Lalithya | 2026NS03089 |
| Member | Vishwa Vajendra M | 2026NS03076 |

Throughout the rest of this repo, first names are used as short labels for readability:
Dhruv · Manikandan · Sai Krishna Mohan · Ramya · Sri Lalithya · Vishwa.

---

## Principles behind the split

- Every member owns **one theory section** (Part A of the report) **plus one execution phase** in the VM. Roughly equal workload.
- Every member captures screenshots for **their own phase** — no single person is stuck taking every screenshot.
- Group Leader (Dhruv) additionally compiles the final PDF and drives the demo.
- Presentation Coordinator (Manikandan) additionally owns the slide deck + viva rehearsal.
- Environment setup (Phase 0) is already done by the team collectively — no ownership needed there.
- I (assistant) produce all scripts, SQL, code, config files, diagrams, and text drafts. Team executes them in the VM and reports results.

---

## Ownership matrix

| Member | Theory ownership (Part A of report) | VM execution ownership | Extra duties |
|---|---|---|---|
| **Dhruv – Group Leader** | §1 Introduction (domain, background, business problem) | Phase 0.5 – Env sanity check + config fix, re-format NameNode, verify daemons | Overall coordination · Final PDF compile · Demo lead in viva |
| **Manikandan – Presentation Coordinator** | §2 Big Data Need Analysis (Vs, why RDBMS fails) | Phase 6 – HBase table creation, zone lookup load, scan/get demos | Presentation deck (5 min) · Viva Q&A prep · Rehearsal driver |
| **Sai Krishna Mohan** | §3 Dataset Description (source, records, attributes, schema) | Phase 2 – Dataset download + HDFS ingestion + Phase 4 – native Hadoop Streaming MR (mapper.py / reducer.py) | Owns raw-data lineage story in viva |
| **Ramya** | §4 Architecture (diagram walkthrough, data flow explanation) | Phase 3 – Pig ETL execution (clean + enrich scripts) | Explains Pig→MR compilation in viva |
| **Sri Lalithya** | §5.a Technology Selection – Hadoop / HDFS / MR / Pig | Phase 5 – Hive DDL, analytical HQL queries, EXPLAIN plans, result export | Owns "why Hive over RDBMS" pitch |
| **Vishwa** | §5.b Technology Selection – Hive / HBase / Streamlit | Phase 7 – Streamlit dashboard: pull results, run app, build charts | Owns dashboard demo in viva |

---

## Cross-cutting duties (small, distributed)

| Duty | Owner |
|---|---|
| Screenshot checklist enforcement | Manikandan (deck driver — needs the screenshots anyway) |
| Git or shared drive for scripts + screenshots | Dhruv |
| References list / citations | Sai Krishna Mohan (already owns dataset story) |
| Report editing pass (single voice) | Dhruv |
| Timestamped changelog / meeting notes | Rotates weekly among Sai Krishna Mohan–Vishwa |

---

## Phase-to-owner quick lookup

| Phase | Owner | User-task MD |
|---|---|---|
| 0.5 Config fix + env verification | Dhruv | `user-tasks/00-env-verification-and-config-fix.md` |
| 1 Install Pig/Hive/HBase | Dhruv + Ramya + Sri Lalithya + Vishwa (each installs the one they own; documented together) | `user-tasks/01-install-pig-hive-hbase.md` |
| 2 Download + HDFS ingest | Sai Krishna Mohan | `user-tasks/02-download-and-ingest.md` |
| 3 Pig ETL | Ramya | `user-tasks/03-run-pig-etl.md` |
| 4 Native MR (Streaming) | Sai Krishna Mohan | `user-tasks/04-run-mapreduce.md` |
| 5 Hive analytics | Sri Lalithya | `user-tasks/05-run-hive.md` |
| 6 HBase demo | Manikandan | `user-tasks/06-run-hbase.md` |
| 7 Streamlit dashboard | Vishwa | `user-tasks/07-dashboard.md` |
| 8 Report compile | Dhruv (with sections from all) | `my-work/report/part-a-theory.md` |
| 9 Deck + viva rehearsal | Manikandan (with the whole team joining) | `my-work/report/presentation-outline.md` |

---

## Fairness check (rough LoE per member)

| Member | Theory writing | VM execution | Extra | ≈ Total |
|---|---|---|---|---|
| Dhruv | Medium (§1) | Medium (setup+verify) | High (coord + PDF) | **High** |
| Manikandan | Medium (§2) | Medium (HBase) | High (deck + viva) | **High** |
| Sai Krishna Mohan | Medium (§3) | High (2 phases: ingest + MR) | Low (refs) | **High** |
| Ramya | Medium (§4 + diagram narration) | Medium (Pig) | Low | **Medium-High** |
| Sri Lalithya | Medium (§5.a) | Medium (Hive – heaviest queries) | Low | **Medium-High** |
| Vishwa | Medium (§5.b) | Medium (Streamlit) | Low | **Medium-High** |

Balanced. Group Leader and Presentation Coordinator carry marginally more because their roles are formally called out by the assignment — this is standard.

---

## Notes

- Faculty may cold-call *any* member in the viva about *any* topic. So while ownership is by phase, **every member reads every user-task MD and the report before the demo.** Owners lead their section; others need to be conversant.
- If a member is unavailable for a phase, swap with another and update this file — do not leave a phase orphaned.
