---
id: TASK-120
title: >-
  Spike: on-device object and Vietnamese food recognition (MobileCLIP) vs.
  vision LLM
status: Done
assignee:
  - '@claude'
created_date: 2026-11-02 15:19
updated_date: '2026-11-02T16:26:00Z'
labels:
  - ios
  - backend
  - research
dependencies: []
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The developer wants a camera feature: point the phone at a thing (a desk, a bowl of phở, bánh mì) and see its simple English explanation (explain first, translate last). Common object detectors (COCO YOLO, ML Kit) do not know 'desk' or Vietnamese dishes, so the plan is a cascade: MobileCLIP on the phone with Saynata's own dictionary nouns as labels, a small trained layer for Vietnamese dishes, and a vision LLM on the backend when the phone is unsure. This spike measures accuracy and speed before any UI or backend code. Test data: 30VNFoods on Hugging Face (vuongnhathien/30VNFoods, CC BY-NC-SA 4.0, test only, not committed) and ImageNet validation photos (research use only, not committed). Wikimedia Commons blocks the cloud session IP.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 scripts/vision_spike has runnable uv scripts for the zero-shot test and the food layer, with a README of results
- [x] #2 README reports top-1/top-5 accuracy and confidence vs. coverage for objects and for Vietnamese dishes
- [x] #3 README compares MobileCLIP with a vision LLM (Gemini) on the same photos
- [x] #4 README ends with a recommended cascade and thresholds for the iOS feature
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Tests pass
- [x] #2 Feature doc (backlog/docs/features/) updated if a flow changed
- [x] #3 CLAUDE.md overview updated if the stack, folders, or commands changed
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Zero-shot MobileCLIP2-S2 test: dictionary nouns (WordNet physical, no plurals) + 30 dishes as labels; 30VNFoods validation + 27 ImageNet objects (done)
2. Linear probe on frozen image vectors, trained on 30VNFoods test split, scored on validation (running)
3. Gemini flash-lite on the same photos (llm_test.py; needs GEMINI_API_KEY in a new session; under 1 US cent)
4. README with results and a recommended cascade + thresholds
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wikimedia Commons blocks the cloud IP (403), so photos come from Hugging Face (30VNFoods CC BY-NC-SA 4.0, ImageNet research-only); none are committed. Zero-shot: objects 57% top-1 / 77% top-5, food 38% / 66%; ≥0.6 confidence answers 40% of photos at 68%. clip_test.py needs NLTK_ALLOW_PROXIED_URLOPEN=1 in cloud sessions. Commit 55eb7e4 used the non-standard type 'research'; not rewritten (no force-push).

Food probe (MobileCLIP2-S2, 2,989 train / 2,515 test photos): 87% top-1 / 98% top-5 vs 49% / 76% zero-shot on the 30 names; confidence ≥0.7 answers 64% at 98%. Results and recommended cascade in scripts/vision_spike/README.md. Remaining: Gemini comparison (AC 3) and final cascade (AC 4).

Gemini 3.5 flash-lite on 171 photos (llm_test.py --per-class 3, under 1 cent): objects 57% script / 68% by hand, dishes 69% / 73%, 4.2 s per photo. Not better than the food layer (87%) on dishes; kept as the fallback when the phone is unsure. Cascade confirmed and built in TASK-121. llm_test.py now sends the key in a header and retries 429.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Measured three ways to name the thing in a photo: MobileCLIP2-S2 zero-shot on the phone (objects 57% top-1, 77% top-5), a trained food layer for 30 Vietnamese dishes (87%, 98% at >= 0.7), and Gemini flash-lite on the backend (objects 68%, dishes 73% by hand, 4.2 s, paid). Recommended cascade in scripts/vision_spike/README.md: food layer for food, zero-shot >= 0.7, else 3 chips and ask AI. Risk: train and test photos share a dataset; 30VNFoods is non-commercial (TASK-122).
<!-- SECTION:FINAL_SUMMARY:END -->
