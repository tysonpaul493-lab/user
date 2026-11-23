const fs = require('fs');
const path = require('path');

function emptyDirSync(dir) {
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
  fs.mkdirSync(dir, { recursive: true });
}

function copyFolderRecursiveSync(source, target) {
  if (!fs.existsSync(source)) return;
  if (!fs.existsSync(target)) {
    fs.mkdirSync(target, { recursive: true });
  }

  const files = fs.readdirSync(source);
  for (const file of files) {
    const curSource = path.join(source, file);
    const curTarget = path.join(target, file);
    if (fs.lstatSync(curSource).isDirectory()) {
      copyFolderRecursiveSync(curSource, curTarget);
    } else {
      fs.copyFileSync(curSource, curTarget);
    }
  }
}

const sourceDir = path.join(__dirname, 'frontend', 'build', 'web');
const rootDir = __dirname;
const buildWebDir = path.join(__dirname, 'build', 'web');
const publicDir = path.join(__dirname, 'public');

if (fs.existsSync(sourceDir)) {
  const buildId = 'build_' + Date.now();
  console.log(`Syncing User Web distribution with build ID: ${buildId}...`);

  // Copy to build/web and public
  copyFolderRecursiveSync(sourceDir, buildWebDir);
  copyFolderRecursiveSync(sourceDir, publicDir);

  // Copy individual files to root
  const files = fs.readdirSync(sourceDir);
  for (const file of files) {
    const src = path.join(sourceDir, file);
    const dst = path.join(rootDir, file);
    if (fs.lstatSync(src).isDirectory()) {
      copyFolderRecursiveSync(src, dst);
    } else {
      fs.copyFileSync(src, dst);
    }
  }

  // Inject anti-cache & localStorage sanitizer into index.html
  const sanitizeScript = `  <script id="liferoute-sanitizer">
    // Unregister legacy service workers and clear browser cache
    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.getRegistrations().then(function(registrations) {
        for (var i = 0; i < registrations.length; i++) {
          registrations[i].unregister();
        }
      });
    }
    if ('caches' in window) {
      caches.keys().then(function(names) {
        for (var i = 0; i < names.length; i++) {
          caches.delete(names[i]);
        }
      });
    }
    try {
      for (var k in localStorage) {
        var v = localStorage.getItem(k);
        if (k && k.indexOf('8428304510') !== -1) {
          localStorage.removeItem(k);
        }
        if (v && (v.indexOf('8428304510') !== -1 || v.indexOf('trycloudflare.com') !== -1 || v.indexOf('bottle-equilibrium') !== -1 || v.indexOf('jessica-western') !== -1)) {
          localStorage.removeItem(k);
        }
      }
    } catch(e) {}
    // Discard any browser autofilled 8428304510 values
    function purgeStalePhoneInputs() {
      try {
        var inputs = document.querySelectorAll('input');
        for (var i = 0; i < inputs.length; i++) {
          if (inputs[i].value && inputs[i].value.indexOf('8428304510') !== -1) {
            inputs[i].value = '';
          }
        }
      } catch(e) {}
    }
    window.addEventListener('DOMContentLoaded', purgeStalePhoneInputs);
    window.addEventListener('load', purgeStalePhoneInputs);
    setInterval(purgeStalePhoneInputs, 500);
  </script>`;

  const indexFiles = [
    path.join(rootDir, 'index.html'),
    path.join(buildWebDir, 'index.html'),
    path.join(publicDir, 'index.html'),
  ];

  for (const p of indexFiles) {
    if (fs.existsSync(p)) {
      let content = fs.readFileSync(p, 'utf8');
      content = content.replace(/<script[^>]*id="liferoute-sanitizer"[^>]*>[\s\S]*?<\/script>/g, '');
      content = content.replace(/<script>\s*\/\/ Unregister legacy service workers[\s\S]*?<\/script>/g, '');
      content = content.replace('</head>', `${sanitizeScript}\n</head>`);
      content = content.replace(/flutter_bootstrap\.js(\?v=[^"']+)?/g, `flutter_bootstrap.js?v=${buildId}`);
      fs.writeFileSync(p, content, 'utf8');
    }
  }

  // Update flutter_bootstrap.js mainJsPath
  const bootstrapFiles = [
    path.join(rootDir, 'flutter_bootstrap.js'),
    path.join(buildWebDir, 'flutter_bootstrap.js'),
    path.join(publicDir, 'flutter_bootstrap.js'),
  ];

  for (const p of bootstrapFiles) {
    if (fs.existsSync(p)) {
      let content = fs.readFileSync(p, 'utf8');
      content = content.replace(/main\.dart\.js(\?v=[^"']+)?/g, `main.dart.js?v=${buildId}`);
      fs.writeFileSync(p, content, 'utf8');
    }
  }

  fs.writeFileSync(path.join(rootDir, '.last_build_id'), buildId, 'utf8');
  console.log('✅ User App web distribution synced and cache-busted successfully!');
} else {
  console.error('Source directory does not exist:', sourceDir);
}
