#include "RealtimeGain.h"

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct SoundMixGainStorage {
    _Atomic(uint32_t) bits;
};

static uint32_t gain_bits(float gain) {
    uint32_t bits;
    memcpy(&bits, &gain, sizeof(bits));
    return bits;
}

SoundMixGainStorage *SoundMixGainCreate(float gain) {
    SoundMixGainStorage *storage = malloc(sizeof(*storage));
    if (storage != NULL) {
        atomic_init(&storage->bits, gain_bits(gain));
    }
    return storage;
}

void SoundMixGainDestroy(SoundMixGainStorage *storage) {
    free(storage);
}

void SoundMixGainStore(SoundMixGainStorage *storage, float gain) {
    atomic_store_explicit(&storage->bits, gain_bits(gain), memory_order_relaxed);
}

float SoundMixGainLoad(const SoundMixGainStorage *storage) {
    uint32_t bits = atomic_load_explicit(&storage->bits, memory_order_relaxed);
    float gain;
    memcpy(&gain, &bits, sizeof(gain));
    return gain;
}
