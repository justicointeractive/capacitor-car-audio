import { WebPlugin } from '@capacitor/core';

import type { CarAudioPlugin } from './definitions';

export class CarAudioWeb extends WebPlugin implements CarAudioPlugin {
  async setRoot(): Promise<void> {
    // do nothing
  }
}
