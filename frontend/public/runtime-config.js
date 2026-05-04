(function () {
  // In development, the API URL is configured in src/api/config.ts via VITE_API_URL.
  // In production (Azure App Service), VITE_API_URL is injected at build time by Oryx.
  window.RUNTIME_CONFIG = Object.assign({}, window.RUNTIME_CONFIG, { API_URL: undefined });
})();
