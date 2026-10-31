import React from 'react';

interface ErrorBoundaryProps {
  children: React.ReactNode;
  /** Shown in the fallback, e.g. the page name. */
  label?: string;
}

interface ErrorBoundaryState {
  error: Error | null;
}

/**
 * Without a boundary, an exception while rendering any page unmounts the whole
 * NUI tree and the menu goes blank until the resource restarts. This contains
 * it to the failing part. Give it a `key` (e.g. the page name) so moving to
 * another page resets it.
 */
export default class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error(`[butter_admin] ${this.props.label ?? 'UI'} crashed:`, error, info.componentStack);
  }

  render() {
    if (!this.state.error) return this.props.children;

    return (
      <div className="flex flex-col items-center justify-center gap-3 p-6 text-center h-full">
        <div className="text-red-400 font-rajdhani text-sm font-bold uppercase tracking-wider">
          {this.props.label ? `${this.props.label} failed to load` : 'Something went wrong'}
        </div>
        <div className="text-[11px] text-muted break-all max-w-md">
          {String(this.state.error.message || this.state.error)}
        </div>
        <button
          type="button"
          onClick={() => this.setState({ error: null })}
          className="px-3 py-1.5 rounded-lg border border-white/10 bg-white/5 hover:bg-white/10 text-xs text-white transition-colors"
        >
          Try again
        </button>
      </div>
    );
  }
}
