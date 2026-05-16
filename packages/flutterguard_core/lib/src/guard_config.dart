class FlutterGuardConfig {
  final bool enabled;
  final bool collectErrors;
  final bool collectFrames;
  final bool collectRoutes;
  final bool collectBuilds;
  final int slowFlowMs;
  final int jankFrameMs;
  final int maxTraces;
  final bool sanitizeNetwork;

  const FlutterGuardConfig({
    this.enabled = true,
    this.collectErrors = true,
    this.collectFrames = true,
    this.collectRoutes = true,
    this.collectBuilds = true,
    this.slowFlowMs = 1000,
    this.jankFrameMs = 16,
    this.maxTraces = 100,
    this.sanitizeNetwork = true,
  });
}
