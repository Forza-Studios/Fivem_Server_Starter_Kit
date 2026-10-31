import React from 'react';
import { useNuiEvent } from '../hooks/useNuiEvent';

interface SoundData {
  soundName: string;
  volume?: number;
}

const SoundPlayer: React.FC = () => {
  useNuiEvent<SoundData>('playSound', (data) => {
    const { soundName, volume = 0.5 } = data;
    if (!soundName) return;

    // Use absolute path to the sound file in the resource
    // Since fxmanifest 'files' exposes sounds/*.ogg, they are at the root or /sounds/
    // FiveM NUI absolute path: https://cfx-nui-<resource_name>/<path>
    // Relative path works if index.html is in /nui/ and sounds is in /sounds/
    // ../sounds/name.ogg
    const soundPath = `../sounds/${soundName}.ogg`;

    const audio = new Audio(soundPath);
    audio.volume = volume;

    audio.play().catch(() => {});
  });

  return null; // This component doesn't render anything
};

export default SoundPlayer;
