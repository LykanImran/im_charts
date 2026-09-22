import 'dart:io';

void main(List<String> args) async {
  stdout.writeln(
    '\n════════════════════════════════════════════════════════════',
  );
  stdout.writeln('  🚀 im_charts: Deploying to pub.dev');
  stdout.writeln(
    '════════════════════════════════════════════════════════════\n',
  );

  final rootDir = Directory.current;

  // 0. Pre-flight: Check git working tree
  final gitStatusResult = await Process.run(
    'git',
    ['status', '--porcelain'],
    workingDirectory: rootDir.path,
  );
  if (gitStatusResult.exitCode == 0 &&
      gitStatusResult.stdout.toString().trim().isNotEmpty) {
    stderr.writeln('⚠️  Warning: You have uncommitted git changes:');
    for (final line in gitStatusResult.stdout.toString().trim().split('\n')) {
      stderr.writeln('    $line');
    }
    stderr.writeln(
      '\n💡 pub.dev dry-run requires a clean git commit. Please commit your changes before deploying.\n',
    );
    exit(1);
  }

  // 1. Static Analysis
  stdout.writeln('🔍 [1/4] Running static analysis (flutter analyze)...');
  final analyzeProcess = await Process.start(
    'flutter',
    ['analyze'],
    workingDirectory: rootDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final analyzeCode = await analyzeProcess.exitCode;
  if (analyzeCode != 0) {
    stderr.writeln('\n❌ Error: flutter analyze failed with exit code $analyzeCode');
    exit(analyzeCode);
  }

  // 2. Unit and Widget Tests
  stdout.writeln('\n🧪 [2/4] Running automated test suite (flutter test)...');
  final testProcess = await Process.start(
    'flutter',
    ['test'],
    workingDirectory: rootDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final testCode = await testProcess.exitCode;
  if (testCode != 0) {
    stderr.writeln('\n❌ Error: flutter test failed with exit code $testCode');
    exit(testCode);
  }

  // 3. Dry-run Package Validation
  stdout.writeln('\n📦 [3/4] Performing dry-run package validation (dart pub publish --dry-run)...');
  final dryRunProcess = await Process.start(
    'dart',
    ['pub', 'publish', '--dry-run'],
    workingDirectory: rootDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final dryRunCode = await dryRunProcess.exitCode;
  if (dryRunCode != 0) {
    stderr.writeln('\n❌ Error: Dry-run validation failed with exit code $dryRunCode');
    exit(dryRunCode);
  }

  // 4. Publish to pub.dev
  final force = args.contains('--force');
  if (!force) {
    stdout.write('\n⚠️  Ready to publish to pub.dev. Proceed? (y/N): ');
    final input = stdin.readLineSync()?.trim().toLowerCase();
    if (input != 'y' && input != 'yes') {
      stdout.writeln('❌ Deployment cancelled by user.\n');
      exit(0);
    }
  }

  stdout.writeln('\n🚀 [4/4] Publishing im_charts to pub.dev...');
  final publishProcess = await Process.start(
    'dart',
    ['pub', 'publish', if (force) '--force'],
    workingDirectory: rootDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final publishCode = await publishProcess.exitCode;

  if (publishCode != 0) {
    stderr.writeln('\n❌ Error: Publishing failed with exit code $publishCode');
    exit(publishCode);
  }

  stdout.writeln(
    '\n════════════════════════════════════════════════════════════',
  );
  stdout.writeln('  🎉 PUBLISHED TO PUB.DEV SUCCESSFULLY!');
  stdout.writeln('  🔗 Package URL: https://pub.dev/packages/im_charts');
  stdout.writeln(
    '════════════════════════════════════════════════════════════\n',
  );
}
