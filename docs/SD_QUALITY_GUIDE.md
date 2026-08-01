# SD 1.5 Quality Guide

## Study

The original demos used four diffusion steps, overriding stable-diffusion.cpp's 20-step default. A controlled RTX 5090 study generated 144 images with the exact Phase 1 SD 1.5 Q8_0 model:

- eight prompt categories: portrait, landscape, architecture, product, animal, illustration, food, and multi-subject action
- three deterministic seeds per prompt
- six step counts per prompt and seed: 4, 8, 12, 20, 30, and 40
- identical model, prompt, seed, sampler, scheduler, guidance, frame, and batch size within each comparison

The timing figures below describe the RTX 5090 test host, not a cross-hardware latency guarantee.

| Steps | Mean time | Visual role |
| ---: | ---: | --- |
| 4 | 0.308 s | Unusable preview; weak structure and detail |
| 8 | 0.532 s | Large improvement, but inconsistent core features |
| 12 | 0.762 s | Lowest consistently useful setting |
| 20 | 1.223 s | Safest general default |
| 30 | 1.799 s | Detail-focused; useful selectively |
| 40 | 2.374 s | Experimental maximum; often different rather than better |

## Product Levels

- **Standard, 12 steps:** Fastest allowed setting. Best for concept iteration, landscapes, and illustrations where exact anatomy or geometry is not the core requirement.
- **Balanced, 20 steps:** Default. Best general choice for portraits, products, animals, food, and mixed prompts.
- **Detailed, 30 steps:** Best for architecture, materials, fur, and texture-heavy final renders. It can overwork skin, food, highlights, and fine edges.
- **Max, 40 steps:** Comparison or experimentation. It costs more time and does not reliably improve composition, anatomy, object count, or prompt adherence.

Four and eight steps are not exposed because the weakest core elements were too often unusable. Legacy protocol requests with a zero step value use the 12-step floor and are billed in the same surcharge tier as explicit quality requests. Old journal entries without quality metadata remain labelled `Legacy / unrecorded`; new web requests default explicitly to 20 steps. Other values are clamped to 12 through 40.

## Prompt Guidance

- Portraits usually stabilize by 12 steps. Twenty is safer; 30-40 can add harsh skin texture without fixing eyes, hands, or accessories.
- Landscapes and illustrations are often useful at 12. Twenty helps atmosphere and separation; higher values can add busy pseudo-detail.
- Architecture benefits most from 20-30 steps, but repeated windows, warped lines, and bad joins are model limitations rather than step-count problems.
- Product, animal, and food prompts generally benefit through 20. Thirty can help material or fur detail but can also create noisy seams and oversharpening.
- Multi-subject action is the weakest category. More steps do not reliably repair fused subjects, anatomy, identity, or exact object counts. Simplify the prompt or use a stronger model when those details are essential.

More diffusion steps refine a sampled result. They do not behave like deterministic post-processing and should not be described as guaranteed quality improvement.

## Protocol Mapping

The existing `AiRequestPayload.max_tokens` field carries the bounded SD step count. This avoids a wire-format change. Values from 12 through 40 remain in the same current reward-surcharge tier, so the studied quality levels do not change the Phase 3 configured payment.
