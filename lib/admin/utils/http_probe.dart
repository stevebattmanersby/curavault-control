// IMPORTANT:
// `HttpProbeResult` must be available on *all* platforms.
// The web implementation (`http_probe_web.dart`) imports the type but does not
// re-export it, so we export the type from the stub file unconditionally.
export 'package:curavault_admin/admin/utils/http_probe_stub.dart'
    show HttpProbeResult;

// Platform-specific `httpProbe` implementation.
export 'package:curavault_admin/admin/utils/http_probe_stub.dart'
    if (dart.library.html) 'package:curavault_admin/admin/utils/http_probe_web.dart'
    hide HttpProbeResult;
