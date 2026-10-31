/// <reference types="vite/client" />

interface Window {
  /** Provided by FiveM's CEF: the name of the resource that owns this page. */
  GetParentResourceName?: () => string;
  /** Only defined inside FiveM's CEF. */
  invokeNative?: unknown;
}
