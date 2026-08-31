import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trusted worker host artifacts fail closed for live execution', () {
    final root = Directory('infra/trusted-worker');
    final cloudInit = File('${root.path}/cloud-init.yaml').readAsStringSync();
    final compose = File('${root.path}/docker-compose.yml').readAsStringSync();
    final sandbox =
        File('${root.path}/scripts/run-sandbox.sh').readAsStringSync();
    final unit = File('${root.path}/systemd/curavault-trusted-worker.service')
        .readAsStringSync();
    final deployment =
        File('docs/development-control-plane/TRUSTED_WORKER_DEPLOYMENT.md')
            .readAsStringSync();

    expect(cloudInit, contains('PasswordAuthentication no'));
    expect(cloudInit, contains('PermitRootLogin no'));
    expect(cloudInit, isNot(contains("[ufw, allow, '22/tcp']")));
    expect(compose, contains('user: "65532:65532"'));
    expect(compose, contains('no-new-privileges:true'));
    expect(sandbox, contains('--network none'));
    expect(sandbox, contains('--pids-limit 256'));
    expect(sandbox, contains('--memory 2g'));
    expect(sandbox, contains('--ulimit fsize=1073741824:1073741824'));
    expect(sandbox, contains('--cap-drop ALL'));
    expect(sandbox, contains('CURAVAULT_SANDBOX_TIMEOUT_SECONDS:-1800'));
    expect(sandbox, contains('timeout_seconds > 1800'));
    expect(sandbox, isNot(contains('/var/run/docker.sock')));
    expect(unit, contains('NoNewPrivileges=true'));
    expect(unit, contains('ProtectHome=true'));
    expect(unit, contains('Type=simple'));
    expect(deployment, contains('HOST NOT DEPLOYED'));
    expect(deployment, contains('Keep both live/fake gates false'));
  });
}
