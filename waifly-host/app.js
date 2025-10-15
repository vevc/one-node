const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");

const DOMAIN = "node.waifly.com";
const PORT = 10008;
const UUID = "YOUR_UUID";
const SHORT_ID = "YOUR_SHORT_ID";
const PUBLIC_KEY = "YOUR_PUBLIC_KEY";
let ARGO_DOMAIN = "xxx.trycloudflare.com";
const ARGO_TOKEN = "";

// Binary and config definitions
const apps = [
  {
    name: "cf",
    binaryPath: "/home/container/cf/cf",
    args: ["tunnel", "--no-autoupdate", "--edge-ip-version", "auto", "--protocol", "http2", "--url", "http://localhost:8001"],
    mode: "filter",
    pattern: /https:\/\/[a-z0-9-]+\.trycloudflare\.com/g
  },
  {
    name: "xy",
    binaryPath: "/home/container/xy/xy",
    args: ["-c", "/home/container/xy/config.json"],
    mode: "inherit"
  },
  {
    name: "h2",
    binaryPath: "/home/container/h2/h2",
    args: ["server", "-c", "/home/container/h2/config.yaml"],
    mode: "inherit"
  }
];

const REMARKS_PREFIX = "waifly";
const subInfo = [
  `vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&sni=${ARGO_DOMAIN}&fp=chrome&type=ws&path=%2F%3Fed%3D2560#${REMARKS_PREFIX}-ws-argo`,
  `vless://${UUID}@${DOMAIN}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.cloudflare.com&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&spx=%2F&type=tcp&headerType=none#${REMARKS_PREFIX}-reality`,
  `hysteria2://${UUID}@${DOMAIN}:${PORT}?insecure=1#${REMARKS_PREFIX}-hy2`
];

// Print sub info
function printSubInfo() {
  console.log(
    `============================================================
🚀 WebSocket+Argo & Reality & HY2 Node Info
------------------------------------------------------------
${subInfo.join('\n')}
============================================================`);
}

if (ARGO_TOKEN) {
  apps[0].mode = "inherit";
  apps[0].args = ["tunnel", "--no-autoupdate", "--edge-ip-version", "auto", "--protocol", "http2", "run", "--token", ARGO_TOKEN];
  printSubInfo();
}

// Run binary with keep-alive
function runProcess(app) {
  const child = spawn(app.binaryPath, app.args, {
    stdio: app.mode === "inherit" ? "inherit" : ["ignore", "pipe", "pipe"]
  });

  if (app.mode === "filter") {
    const handleData = (data) => {
      const logText = data.toString();
      const matches = logText.match(app.pattern);
      if (matches && matches.length > 0) {
        child.stdout.off("data", handleData);
        child.stderr.off("data", handleData);
        const tunnelUrl = matches[matches.length - 1];
        ARGO_DOMAIN = new URL(tunnelUrl).hostname;
        subInfo[0] = `vless://${UUID}@${ARGO_DOMAIN}:443?encryption=none&security=tls&sni=${ARGO_DOMAIN}&fp=chrome&type=ws&path=%2F%3Fed%3D2560#${REMARKS_PREFIX}-ws-argo`;
        fs.writeFile(path.join(__dirname, "node.txt"), subInfo.join('\n'), () => { });
        printSubInfo();
      }
    };
    child.stdout.on("data", handleData);
    child.stderr.on("data", handleData);
  }

  child.on("exit", (code) => {
    console.log(`[EXIT] ${app.name} exited with code: ${code}`);
    console.log(`[RESTART] Restarting ${app.name}...`);
    setTimeout(() => runProcess(app), 3000); // restart after 3s
  });
}

// Main execution
function main() {
  try {
    for (const app of apps) {
      runProcess(app);
    }
  } catch (err) {
    console.error("[ERROR] Startup failed:", err);
    process.exit(1);
  }
}

main();
