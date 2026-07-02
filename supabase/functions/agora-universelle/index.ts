import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GITHUB_TOKEN = Deno.env.get("EMERICK_GITHUB_TOKEN") || "";
const OWNER = "mecaniquedutrading33-blip";
const REPO = "agora-admin-roblox-public";
const BRANCH = "main";

const ALLOWED_FILES = [
  "MilanEmerickPanel_v38.txt",
  "AgoraRegistryPanel.lua",
  "AgoraLoader.lua",
  "MainModule.lua",
  "Commands.lua",
];

function decodeBase64Bytes(b64: string): Uint8Array {
  const binary = atob(b64.replace(/\n/g, ""));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);

  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  const file = url.searchParams.get("file") || "MilanEmerickPanel_v38.txt";

  if (!file || !ALLOWED_FILES.includes(file)) {
    return new Response(`File not allowed: ${file}`, { status: 404 });
  }

  if (!GITHUB_TOKEN) {
    return new Response("GitHub token not configured", { status: 500 });
  }

  const apiUrl = `https://api.github.com/repos/${OWNER}/${REPO}/contents/${file}?ref=${BRANCH}`;

  const res = await fetch(apiUrl, {
    headers: {
      "Authorization": `Bearer ${GITHUB_TOKEN}`,
      "Accept": "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "agora-universelle-loader",
    },
  });

  if (!res.ok) {
    const errText = await res.text();
    console.error(`GitHub API error ${res.status}: ${errText}`);
    return new Response(`GitHub error: ${res.status} - ${errText}`, { status: 502 });
  }

  const data = await res.json();

  if (!data.content) {
    return new Response("No content found", { status: 500 });
  }

  const bytes = decodeBase64Bytes(data.content);

  return new Response(bytes, {
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Cache-Control": "no-cache, no-store, must-revalidate",
      "Connection": "keep-alive",
    },
  });
});
