import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  late ProviderContainer container;
  late HiddifyCoreService service;

  setUp(() {
    final serviceProvider = Provider<HiddifyCoreService>(HiddifyCoreService.new);
    container = ProviderContainer();
    service = container.read(serviceProvider);
  });

  tearDown(() async {
    await service.logController.close();
    await service.statusController.close();
    container.dispose();
  });

  test("watchLogs immediately emits an empty snapshot before core initialization", () async {
    final logs = await service.watchLogs("unused").first.timeout(const Duration(seconds: 1));

    expect(logs, isEmpty);
  });

  test("log controller starts with an empty snapshot", () {
    expect(service.logController.value, isEmpty);
  });

  test("clearLogs publishes the cleared snapshot", () async {
    service.logBuffer.add(LogMessage(message: "stale"));
    service.logController.add(List<LogMessage>.unmodifiable(service.logBuffer));

    final result = await service.clearLogs().run();

    expect(result.isRight(), isTrue);
    expect(service.logBuffer, isEmpty);
    expect(service.logController.value, isEmpty);
  });
}
