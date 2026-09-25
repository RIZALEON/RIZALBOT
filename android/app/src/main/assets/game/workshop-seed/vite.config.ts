import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

// `vite build`               -> dist/        (normal multi-file build, relative paths)
// `vite build --mode single` -> dist-single/ (one self-contained index.html, all JS inlined)
export default defineConfig(({ mode }) => ({
  base: './',
  plugins: mode === 'single' ? [viteSingleFile()] : [],
  build: {
    outDir: mode === 'single' ? 'dist-single' : 'dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 3000,
    target: 'es2020',
  },
}));
