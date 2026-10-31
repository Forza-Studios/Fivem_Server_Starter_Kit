export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'bg-primary': 'rgba(var(--bg-primary), <alpha-value>)',
        'bg-secondary': 'rgba(var(--bg-secondary), <alpha-value>)',
        'sidebar': 'rgba(var(--sidebar-bg), <alpha-value>)',
        'accent': 'rgba(var(--accent), <alpha-value>)',
        'primary': 'rgba(var(--text-primary), <alpha-value>)',
        'muted': 'rgba(var(--text-muted), <alpha-value>)',
        'border': 'rgba(var(--border), <alpha-value>)',
        'white': 'rgba(var(--theme-white), <alpha-value>)',
        'black': 'rgba(var(--theme-black), <alpha-value>)',
        'success': 'rgba(var(--success), <alpha-value>)',
        'warning': 'rgba(var(--warning), <alpha-value>)',
        'danger': 'rgba(var(--danger), <alpha-value>)',
      },
      fontSize: {
        // Font sizes are driven through --font-scale (default 1) so the admin's
        // "Font Size" slider scales text ONLY — layout (padding/gap/width, which
        // use rem) is unaffected, so the menu box keeps its size. See utils/fonts.ts.
        'xs': ['calc(0.75rem * var(--font-scale, 1))', { lineHeight: 'calc(1rem * var(--font-scale, 1))' }],
        'sm': ['calc(0.875rem * var(--font-scale, 1))', { lineHeight: 'calc(1.25rem * var(--font-scale, 1))' }],
        'base': ['calc(1rem * var(--font-scale, 1))', { lineHeight: 'calc(1.5rem * var(--font-scale, 1))' }],
        'lg': ['calc(1.125rem * var(--font-scale, 1))', { lineHeight: 'calc(1.75rem * var(--font-scale, 1))' }],
        'xl': ['calc(1.25rem * var(--font-scale, 1))', { lineHeight: 'calc(1.75rem * var(--font-scale, 1))' }],
        '2xl': ['calc(1.5rem * var(--font-scale, 1))', { lineHeight: 'calc(2rem * var(--font-scale, 1))' }],
        '3xl': ['calc(1.875rem * var(--font-scale, 1))', { lineHeight: 'calc(2.25rem * var(--font-scale, 1))' }],
        '4xl': ['calc(2.25rem * var(--font-scale, 1))', { lineHeight: 'calc(2.5rem * var(--font-scale, 1))' }],
        '5xl': ['calc(3rem * var(--font-scale, 1))', { lineHeight: '1' }],
        '6xl': ['calc(3.75rem * var(--font-scale, 1))', { lineHeight: '1' }],
        '7xl': ['calc(4.5rem * var(--font-scale, 1))', { lineHeight: '1' }],
      },
      fontFamily: {
        sans: ['var(--font-sans)', 'Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'SFMono-Regular', 'monospace'],
        rajdhani: ['var(--font-sans)', 'sans-serif'],
        barlow: ['var(--font-sans)', 'sans-serif'],
      }
    },
  },
  plugins: [require('tailwindcss-animate')],
}
