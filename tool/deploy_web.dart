import 'dart:io';

void main() async {
  stdout.writeln(
    '\n════════════════════════════════════════════════════════════',
  );
  stdout.writeln('  🚀 im_charts: Deploying Example Web to GitHub Pages');
  stdout.writeln(
    '════════════════════════════════════════════════════════════\n',
  );

  final rootDir = Directory.current;
  final exampleDir = Directory('${rootDir.path}/example');
  final buildWebDir = Directory('${exampleDir.path}/build/web');

  if (!exampleDir.existsSync()) {
    stderr.writeln(
      '❌ Error: Could not find "example" directory at ${exampleDir.path}',
    );
    exit(1);
  }

  // 1. Get git remote URL
  stdout.writeln('📦 [1/4] Detecting Git remote origin URL...');
  final remoteResult = await Process.run('git', [
    'remote',
    'get-url',
    'origin',
  ]);
  if (remoteResult.exitCode != 0) {
    stderr.writeln(
      '❌ Error: Failed to get Git remote origin: ${remoteResult.stderr}',
    );
    exit(1);
  }
  final remoteUrl = remoteResult.stdout.toString().trim();
  stdout.writeln('    Origin: $remoteUrl');

  // 2. Build Flutter Web
  stdout.writeln(
    '\n🔨 [2/4] Building Flutter Web for release (base-href: /im_charts/)...',
  );
  final buildProcess = await Process.start(
    'flutter',
    ['build', 'web', '--release', '--base-href', '/im_charts/'],
    workingDirectory: exampleDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final buildExitCode = await buildProcess.exitCode;
  if (buildExitCode != 0) {
    stderr.writeln(
      '\n❌ Error: Flutter build failed with exit code $buildExitCode',
    );
    exit(buildExitCode);
  }

  // 3. Ensure .nojekyll
  stdout.writeln('\n📝 [3/4] Ensuring .nojekyll in build directory...');
  final noJekyllFile = File('${buildWebDir.path}/.nojekyll');
  noJekyllFile.writeAsStringSync('# Disable Jekyll on GitHub Pages\n');

  // 4. Push to gh-pages branch
  stdout.writeln('\n🚀 [4/4] Pushing release assets to gh-pages branch...');

  final tempGitDir = Directory('${buildWebDir.path}/.git');
  if (tempGitDir.existsSync()) {
    tempGitDir.deleteSync(recursive: true);
  }

  Future<void> runCmd(String exe, List<String> args, {String? cwd}) async {
    final res = await Process.run(
      exe,
      args,
      workingDirectory: cwd ?? buildWebDir.path,
    );
    if (res.exitCode != 0) {
      stderr.writeln('❌ Command failed: $exe ${args.join(' ')}\n${res.stderr}');
      if (tempGitDir.existsSync()) tempGitDir.deleteSync(recursive: true);
      exit(res.exitCode);
    }
  }

  await runCmd('git', ['init']);
  await runCmd('git', ['checkout', '-B', 'gh-pages']);
  await runCmd('git', ['add', '-A']);
  await runCmd('git', [
    'commit',
    '-m',
    'Deploy example web showcase to GitHub Pages [skip ci]',
  ]);
  await runCmd('git', ['remote', 'add', 'origin', remoteUrl]);

  stdout.writeln('    Pushing to origin gh-pages (force)...');
  final pushProcess = await Process.start(
    'git',
    ['push', '-f', 'origin', 'gh-pages'],
    workingDirectory: buildWebDir.path,
    mode: ProcessStartMode.inheritStdio,
  );
  final pushExit = await pushProcess.exitCode;

  // Clean up temporary .git
  if (tempGitDir.existsSync()) {
    tempGitDir.deleteSync(recursive: true);
  }

  if (pushExit != 0) {
    stderr.writeln('\n❌ Error: Git push failed with exit code $pushExit');
    exit(pushExit);
  }

  stdout.writeln(
    '\n════════════════════════════════════════════════════════════',
  );
  stdout.writeln('  🎉 DEPLOYMENT COMPLETE!');
  stdout.writeln('  🔗 Live Showcase: https://lykanimran.github.io/im_charts/');
  stdout.writeln(
    '════════════════════════════════════════════════════════════\n',
  );
}
