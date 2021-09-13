import { WebPlugin } from '@capacitor/core';

import type { CarAudioPlugin } from './definitions';

export class CarAudioWeb extends WebPlugin implements CarAudioPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
