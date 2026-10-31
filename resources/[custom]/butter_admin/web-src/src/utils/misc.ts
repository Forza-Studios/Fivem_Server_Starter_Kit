import { fetchNui } from './fetchNui';

/** True in a regular browser (dev server), false inside FiveM's CEF. */
export const isEnvBrowser = (): boolean => !window.invokeNative;

interface PlayerLike {
  Name?: string;
  CharName?: string;
  PrimaryId?: string;
  License?: string;
  Discord?: string;
  Steam?: string;
  Fivem?: string;
}

// Formats a player's display text (name + identifier) per the server's
// PlayerName/LicenseType config. Shared so every player list renders names the same way.
export const formatPlayerListText = (player: PlayerLike, playerNameFormat: string, licenseType: string): string => {
  let identifier = player.PrimaryId || player.License || player.Discord || player.Steam || player.Fivem;
  if (licenseType === 'License') identifier = player.License || identifier;
  else if (licenseType === 'Discord') identifier = player.Discord || identifier;
  else if (licenseType === 'Steam') identifier = player.Steam || identifier;
  else if (licenseType === 'Fivem') identifier = player.Fivem || identifier;
  else if (licenseType === 'SteamName' || licenseType === 'FivemName') identifier = player.Name || identifier;

  const characterName = player.CharName && player.CharName !== 'N/A' ? player.CharName : undefined;
  if (playerNameFormat === 'Steam' || playerNameFormat === 'Fivem') return `${player.Name} (${identifier})`;
  if (playerNameFormat === 'Character') return `${characterName ?? player.Name} (${identifier})`;
  if (characterName && characterName !== player.Name) return `${characterName} (${player.Name}) (${identifier})`;
  return `${characterName ?? player.Name} (${identifier})`;
};

// navigator.clipboard exists in CEF (secure context) but writeText() rejects
// there, so execCommand is the reliable path in-game.
const execCommandCopy = (text: string): boolean => {
  try {
    const element = document.createElement('textarea');
    element.value = text;
    element.setAttribute('readonly', '');
    element.style.position = 'absolute';
    element.style.left = '-9999px';
    document.body.appendChild(element);
    element.select();
    const copied = document.execCommand('copy');
    document.body.removeChild(element);
    return copied;
  } catch {
    return false;
  }
};

export const copyTextToClipboard = (text: string): boolean => {
  if (!text) return false;
  if (isEnvBrowser() && navigator.clipboard && window.isSecureContext) {
    navigator.clipboard.writeText(text).catch(() => execCommandCopy(text));
    return true;
  }
  return execCommandCopy(text);
};

export const getReportTypeStyles = (type?: string) => {
  const reportType = type?.toLowerCase();
  if (reportType === 'bug') return 'bg-red-500/10 text-red-400 border-red-500/20';
  if (reportType === 'player') return 'bg-blue-500/10 text-blue-400 border-blue-500/20';
  if (reportType === 'staff') return 'bg-amber-500/10 text-amber-400 border-amber-500/20';
  if (reportType === 'question') return 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20';
  if (reportType === 'claim') return 'bg-cyan-500/10 text-cyan-400 border-cyan-500/20';
  if (reportType === 'other') return 'bg-purple-500/10 text-purple-400 border-purple-500/20';
  return 'bg-accent/10 text-accent border-accent/20';
};

const formatUrl = (url: string): string => {
  const trimmed = url.trim();
  return /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
};

/** Opens a link in the browser, copies it as a CEF fallback and lets the game announce it. */
export const openExternalUrl = (url: string) => {
  if (!url || url === 'None') return;
  const formatted = formatUrl(url);

  window.open(formatted, '_blank', 'noopener,noreferrer');
  copyTextToClipboard(formatted);
  if (!isEnvBrowser()) fetchNui('openUrl', { url: formatted }).catch(() => {});
};
