export interface CarAudioPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
