import { registerPlugin } from '@capacitor/core';

import type { CarAudioPlugin } from './definitions';

const CarAudio = registerPlugin<CarAudioPlugin>('CarAudio', {
  web: () => import('./web').then(m => new m.CarAudioWeb()),
});

export * from './definitions';
export { CarAudio };
