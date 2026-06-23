# RunPod Canada Region — Claim Unverified, Deferred

**Date logged:** 2026-06-21

## Status
Unverified. Two research sources give contradictory information on whether RunPod offers a Canada-based GPU region:

- Source A indicates a Canada region exists in RunPod's datacenter list.
- Source B's datacenter documentation does not list Canada.

Neither source was authoritative enough to rely on for compliance or data-residency planning.

## Why it matters
If customer call audio (which may contain Canadian personal data under PIPEDA) must stay within Canadian jurisdiction, RunPod's actual datacenter availability determines whether it is a viable GPU provider for that deployment scenario.

## Decision
**Deferred.** For the demo and initial trial phase, GPU workloads run on the Azure NC4as_T4_v3 (split-VM model, region controlled by us). RunPod is only relevant for the on-demand/Spot GPU burst model discussed for cost reduction at scale.

The Canada-region question does not need to be resolved before the demo or before the first paying customer, unless that customer explicitly requires Canadian data residency for audio processing.

## When to revisit
When approaching a customer that raises data residency requirements. At that point, verify directly against RunPod's current [datacenter page](https://www.runpod.io/gpu-instance/pricing) or by creating a test pod and checking the available regions. Do not rely on cached search results — RunPod's datacenter availability changes frequently.
