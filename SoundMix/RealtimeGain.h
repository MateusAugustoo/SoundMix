#ifndef SOUNDMIX_REALTIME_GAIN_H
#define SOUNDMIX_REALTIME_GAIN_H

typedef struct SoundMixGainStorage SoundMixGainStorage;

SoundMixGainStorage *SoundMixGainCreate(float gain);
void SoundMixGainDestroy(SoundMixGainStorage *storage);
void SoundMixGainStore(SoundMixGainStorage *storage, float gain);
float SoundMixGainLoad(const SoundMixGainStorage *storage);

#endif
