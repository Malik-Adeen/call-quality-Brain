# Phase 3 & 4 Research: Urdu ASR and QLoRA Fine-Tuning
**Context:** This document dictates the constraints for processing 8kHz narrowband telephonic Urdu/English code-switched audio on an 8GB VRAM GPU.

1) Whisper's Phonetic and Linguistic Errors on Urdu When processing Urdu audio, Whisper exhibits several specific transcription errors and limitations:
Phonetic Substitutions: The model frequently confuses words with similar sounds, especially when dealing with formal vocabulary or words of Arabic origin
.
Lexical Distortions: It regularly misrepresents multi-syllabic or morphologically complex words
.
Orthographic Inconsistencies: Whisper struggles with words that have multiple accepted spellings (e.g., transcribing "Chahiye" with or without a "Hamza") or produces incorrect word spacing (e.g., splitting "Hoga" into "Ho ga"), which creates false positives against standard reference texts
.
Syntactic and Structural Loss: In longer sentences, the model may fail to preserve sentence structure and overall coherence
. It is also prone to repetitive artifacts, uncontrollably repeating syllables or words
.
Hallucinations and Script Mixing: Whisper has a tendency to guess and transcribe plausible but completely incorrect speaker names
. Additionally, zero-shot models sometimes output gibberish, mix scripts, or struggle heavily with numerals and regional accents
.
Overlapping Speech: When multiple speakers talk at the same time, Whisper typically fails to capture the overlapping speech and only transcribes the dominant voice
.
2) Methodology for Fine-Tuning Whisper using PEFT (under 8GB VRAM) The provided sources do not contain the exact step-by-step methodology or specific hyperparameter configurations required to keep VRAM usage strictly under an 8GB limit.
However, the provided literature outlines the core framework for parameter-efficient adaptation that makes running on constrained hardware possible:
Low-Rank Adaptation (LoRA): Instead of a full fine-tuning process, you should use LoRA, which injects low-rank trainable matrices into the frozen layers of the pre-trained model
. This approach requires updating less than 10% of the model's parameters (typically 5M–15M parameters) while maintaining near-equivalent performance
.
QLoRA (Quantized LoRA): To drastically reduce memory limits, the methodology recommends applying QLoRA, which integrates 4-bit quantization alongside LoRA
. This combination achieves a 30% to 70% reduction in memory usage with minimal sacrifices to accuracy, making it highly suitable for constrained hardware
.
3) Core Topic of 'Huge.pdf' and Its Relevance to Your Pipeline The document "Huge.pdf" contains the proceedings of the First Workshop on Challenges in Processing South Asian Languages (CHiPSAL), which focuses on overcoming the linguistic complexities, dialectal variations, and low-resource constraints of South Asian NLP and speech models
.
This document provides several insights directly applicable to your Urdu-English Call Center pipeline:
Telephonic Data Strategies: It highlights research on telephonic Urdu ASR, showing that you can bridge the "bandwidth gap" and significantly lower Word Error Rates (WER) by directly mixing your noisy, narrowband telephonic data with wideband speech data during the training phase
.
Whisper Fine-Tuning Evidence: It includes benchmarking studies demonstrating that even a small amount of domain-specific fine-tuning (few-shot learning on 1 to 15 hours of Urdu telephonic data) dramatically reduces Whisper's transcription errors compared to its zero-shot baseline
.
Analytics and Code-Mixing: It features research on processing code-mixed text (like Hindi-English, which is phonetically identical to spoken Urdu-English) and benchmarks various Large Language Models (LLMs) on Urdu NLU tasks
. These findings can directly guide how you design the downstream analytics (like intent detection, sentiment, or summarization) for your transcribed code-switched call center data.