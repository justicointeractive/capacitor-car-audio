export interface CarAudioPlugin {
  setRoot(options: { url: string }): Promise<void>;
}
