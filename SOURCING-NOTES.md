# Sourcing Notes — unresolved attributions flagged for editors

*This file exists because a fact-checker (Bellingcat-grade) will check every quotation, and two rhetorical lines in the companion article/report are **not** independently sourced. They are flagged here rather than quietly shipped. None of them bears on the byte-level forensic findings, which stand on their own; but they should be fixed before any publication.*

---

## 1. "a former senior defence official" (a.k.a. "un ancien haut responsable de la défense")

**Where it appears.** In the narrative article (v2, "The disclosure that was about something else"), as the closing irony — that the only official criticism of the corpus targeted its *lack* of metadata; and, in the report's motive section, as "a former AARO director calling it a 'shiny object'."

**Problem.** There is **no verifiable, named, on-record source** in our research for a specific "former senior defence official" saying this. It is an **editorial paraphrase**. The "shiny object" / "distraction" framing traces to **opinion commentary** (op-eds, contemporaneous punditry), not to a citable statement by a named official. Farid may not flag it; **Bellingcat will.**

**Recommended fix — pick one:**
- **(a) Cut it.** The argument does not need it.
- **(b) Replace with a real, citable, named source.** The honest options that say a defensible version of the same skepticism:
  - **Dr. Sean Kirkpatrick**, *former director of AARO* — on the record (Senate Armed Services Committee, April 2023): AARO found *"no credible evidence thus far of extraterrestrial activity, off-world technology or objects that defy the known laws of physics."* This is an actual former senior defence official, named and quotable.
  - **DefenseScoop**'s contemporaneous reporting criticised the *content quality* of the release (low quality, missing metadata) — cite the outlet and date, not an anonymous "official."
  - For the "metadata is the real problem" irony specifically, attribute it to the **documentary record** (the catalogue's own missing provenance fields) rather than to a person.

**Do not** invent or infer a name. If no on-record source can be attached, the line must be presented explicitly as the author's analysis, not as reported speech.

---

## 2. "Data alone is not disclosure"

**Where it appears.** Used as an epigraph/summary line, attributed to "a defense analyst."

**Problem.** Also **unattributed / editorial.** It is a good line, but it is not a sourced quotation.

**Recommended fix.** Either present it plainly as the **author's framing** (no quotation marks implying a source), or attach a real citation. The substance is independently supportable without a mystery source: the **NASA UAP Independent Study report (Sept 2023, Spergel panel)** and the **ODNI/AARO annual reports** all make the same point in citable form — that the bottleneck is **data quality and calibrated collection**, not the volume of released material.

---

## 3. General rule applied in the forensic pack itself

The verification pack (`manifest.sha256`, `reproduce.sh`, `forensic-dossier-EN.md`, `CORRECTION.md`) contains **no unattributed quotations** and **no rhetorical sourcing**: every claim there is either (a) a hash, (b) a byte-level metadata field re-derivable with `exiftool`, or (c) a public infrastructure record (WHOIS/DNS). The two items above live in the **narrative** layer only. Keep the two layers separate: the forensic claims must never inherit the narrative layer's unresolved attributions.

---

*Summary for an editor: the forensic core is clean and machine-checkable; two colour quotes in the prose are not sourced and should be cut or replaced (Kirkpatrick / NASA-Spergel / DefenseScoop are the real, citable substitutes). Flagging beats shipping.*
