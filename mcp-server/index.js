#!/usr/bin/env node
/**
 * wow-addons MCP Server
 *
 * Exposes repository-specific tools to Claude so you can deploy addons,
 * inspect git state, search Lua source, and read in-game error logs without
 * dropping to a terminal.
 *
 * Tools
 * ─────
 *  wow_addon_list      List all addons from config.json
 *  wow_deploy          Deploy one or all addons via deploy.ps1
 *  wow_git_log         Recent commit history
 *  wow_git_status      Working-tree / staged state
 *  wow_git_diff        Diff of a file or everything
 *  wow_git_commit      Stage paths + commit
 *  wow_grep            Full-text / regex search across Lua source
 *  wow_addon_files     List source files for an addon
 *  wow_read_errors     Load SlyErrorDB in-game errors from WTF
 *  wow_read_saved_vars Read any SavedVariables .lua file
 */

import { Server }              from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

import { execSync }                    from "node:child_process";
import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, resolve, relative }     from "node:path";
import { fileURLToPath }               from "node:url";

// ── Paths ────────────────────────────────────────────────────────────────────
const __dirname  = fileURLToPath(new URL(".", import.meta.url));
const REPO_ROOT  = resolve(__dirname, "..");
const CONFIG     = JSON.parse(readFileSync(join(REPO_ROOT, "config.json"), "utf8"));
const WTF_PATH   = CONFIG.wow.wtfPath;          // e.g. C:\...\WTF
const ADDONS_DIR = join(REPO_ROOT, "addons");

// ── Helpers ──────────────────────────────────────────────────────────────────
function sh(cmd, opts = {}) {
  return execSync(cmd, {
    cwd: REPO_ROOT,
    encoding: "utf8",
    windowsHide: true,
    ...opts,
  }).trim();
}

function walkLua(dir, results = []) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st   = statSync(full);
    if (st.isDirectory()) {
      walkLua(full, results);
    } else if (entry.endsWith(".lua") || entry.endsWith(".toc")) {
      results.push(full);
    }
  }
  return results;
}

function trimText(str, max = 8000) {
  if (str.length <= max) return str;
  return str.slice(0, max) + `\n…[truncated — ${str.length - max} chars omitted]`;
}

// ── Tool definitions ─────────────────────────────────────────────────────────
const TOOLS = [
  {
    name: "wow_addon_list",
    description:
      "List every addon in the repository (from config.json) with its name, " +
      "enabled flag, version, source directory, and description. " +
      "Use this to orient yourself before deploying or editing.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "wow_deploy",
    description:
      "Deploy one or all addons to the live WoW AddOns folder by executing " +
      "scripts/deploy.ps1. Returns the deploy log output. " +
      "Pass `addon` to deploy a single addon (e.g. 'SlySuite_Char'), " +
      "omit it to deploy everything.",
    inputSchema: {
      type: "object",
      properties: {
        addon: {
          type: "string",
          description: "Addon name to deploy (e.g. SlySuite_Char). Omit to deploy all.",
        },
      },
      required: [],
    },
  },
  {
    name: "wow_git_log",
    description:
      "Return recent git commit history for the repository. " +
      "Each line: short-hash  date  subject.",
    inputSchema: {
      type: "object",
      properties: {
        n: { type: "number", description: "Number of commits to show (default 20)" },
      },
      required: [],
    },
  },
  {
    name: "wow_git_status",
    description:
      "Return the current git working-tree status — modified, staged, and " +
      "untracked files, plus the current branch name.",
    inputSchema: { type: "object", properties: {}, required: [] },
  },
  {
    name: "wow_git_diff",
    description:
      "Return git diff output. Optionally scope to a single file. " +
      "Set staged=true to see what is already staged for commit.",
    inputSchema: {
      type: "object",
      properties: {
        file:   { type: "string",  description: "Repo-relative file path (optional)" },
        staged: { type: "boolean", description: "Show staged diff (default false)" },
      },
      required: [],
    },
  },
  {
    name: "wow_git_commit",
    description:
      "Stage the given paths (default: all changes) and create a git commit " +
      "with the supplied message. Returns the commit line (hash + subject).",
    inputSchema: {
      type: "object",
      properties: {
        message: { type: "string", description: "Commit message (required)" },
        paths: {
          type: "array",
          items: { type: "string" },
          description: "Repo-relative paths to git-add. Default is ['.'] (everything).",
        },
      },
      required: ["message"],
    },
  },
  {
    name: "wow_grep",
    description:
      "Full-text or regex search across all .lua and .toc files in the " +
      "repository (or a single addon folder). Returns file, line number, " +
      "and matching line content.",
    inputSchema: {
      type: "object",
      properties: {
        pattern: { type: "string", description: "Text or JS regex pattern to search for" },
        addon: {
          type: "string",
          description: "Limit search to this addon folder name, e.g. SlySuite_Char (optional)",
        },
        max_results: {
          type: "number",
          description: "Maximum matches to return (default 60)",
        },
      },
      required: ["pattern"],
    },
  },
  {
    name: "wow_addon_files",
    description:
      "List all .lua and .toc source files inside an addon's source directory, " +
      "with their byte sizes.",
    inputSchema: {
      type: "object",
      properties: {
        addon: { type: "string", description: "Addon folder name, e.g. SlySuite_Char" },
      },
      required: ["addon"],
    },
  },
  {
    name: "wow_read_errors",
    description:
      "Read in-game Lua errors captured by the SlySuite_Error addon and stored " +
      "in SlyErrorDB SavedVariables. Returns the most recent N errors with " +
      "timestamp, source label, message, and stack trace.",
    inputSchema: {
      type: "object",
      properties: {
        n: { type: "number", description: "Number of errors to return (default 25)" },
      },
      required: [],
    },
  },
  {
    name: "wow_read_saved_vars",
    description:
      "Read the raw content of any SavedVariables .lua file from the WoW WTF " +
      "folder. Use account=ANTEUNIVERSAL for account-level vars, omit for " +
      "global (per-realm) vars.",
    inputSchema: {
      type: "object",
      properties: {
        file:    { type: "string", description: "Filename, e.g. SlyCharDB.lua" },
        account: { type: "string", description: "Account folder name, e.g. ANTEUNIVERSAL (optional)" },
      },
      required: ["file"],
    },
  },
];

// ── Tool handlers ─────────────────────────────────────────────────────────────
function handleTool(name, args) {
  switch (name) {

    // ── addon_list ──────────────────────────────────────────────────────────
    case "wow_addon_list": {
      const rows = CONFIG.addons.map((a) =>
        `${a.enabled ? "✓" : "✗"}  ${a.name.padEnd(24)} v${a.version}  ${a.description}`
      );
      return `${rows.length} addon(s) in config.json:\n\n` + rows.join("\n");
    }

    // ── deploy ──────────────────────────────────────────────────────────────
    case "wow_deploy": {
      const addonArg = args.addon ? ` -AddonName ${args.addon}` : "";
      const cmd = `powershell -ExecutionPolicy Bypass -File scripts\\deploy.ps1${addonArg}`;
      try {
        return sh(cmd, { timeout: 60_000 });
      } catch (e) {
        return `Deploy error:\n${e.message}`;
      }
    }

    // ── git_log ─────────────────────────────────────────────────────────────
    case "wow_git_log": {
      const n = Math.min(args.n || 20, 100);
      return sh(`git log --oneline --format="%h  %as  %s" -${n}`);
    }

    // ── git_status ──────────────────────────────────────────────────────────
    case "wow_git_status": {
      const branch = sh("git rev-parse --abbrev-ref HEAD");
      const status = sh("git status --short");
      return `Branch: ${branch}\n\n${status || "(clean — nothing to commit)"}`;
    }

    // ── git_diff ────────────────────────────────────────────────────────────
    case "wow_git_diff": {
      const staged = args.staged ? "--cached " : "";
      const file   = args.file   ? `-- "${args.file}"` : "";
      const diff   = sh(`git diff ${staged}${file}`);
      return trimText(diff || "(no diff)");
    }

    // ── git_commit ──────────────────────────────────────────────────────────
    case "wow_git_commit": {
      const paths = (args.paths && args.paths.length > 0) ? args.paths : ["."];
      const addCmd  = `git add ${paths.map((p) => `"${p}"`).join(" ")}`;
      const commitCmd = `git commit -m "${args.message.replace(/"/g, '\\"')}"`;
      sh(addCmd);
      return sh(commitCmd);
    }

    // ── grep ────────────────────────────────────────────────────────────────
    case "wow_grep": {
      const root  = args.addon
        ? join(ADDONS_DIR, args.addon)
        : ADDONS_DIR;
      const files = walkLua(root);
      const re    = new RegExp(args.pattern, "i");
      const max   = args.max_results || 60;
      const hits  = [];

      for (const file of files) {
        const lines = readFileSync(file, "utf8").split("\n");
        for (let i = 0; i < lines.length; i++) {
          if (re.test(lines[i])) {
            const rel = relative(REPO_ROOT, file).replace(/\\/g, "/");
            hits.push(`${rel}:${i + 1}  ${lines[i].trim()}`);
            if (hits.length >= max) break;
          }
        }
        if (hits.length >= max) break;
      }

      if (hits.length === 0) return `No matches for: ${args.pattern}`;
      return `${hits.length} match(es) for "${args.pattern}":\n\n` + hits.join("\n");
    }

    // ── addon_files ────────────────────────────────────────────────────────
    case "wow_addon_files": {
      const dir = join(ADDONS_DIR, args.addon);
      if (!existsSync(dir)) return `Addon folder not found: ${args.addon}`;
      const files = walkLua(dir);
      const lines = files.map((f) => {
        const rel  = relative(REPO_ROOT, f).replace(/\\/g, "/");
        const size = statSync(f).size;
        return `${size.toString().padStart(7)} B  ${rel}`;
      });
      return `${lines.length} file(s) in ${args.addon}:\n\n` + lines.join("\n");
    }

    // ── read_errors ────────────────────────────────────────────────────────
    case "wow_read_errors": {
      // SlyErrorDB is in global SavedVariables (per-realm or global)
      const svPaths = [
        join(WTF_PATH, "Account", "ANTEUNIVERSAL", "SavedVariables", "SlySuite_Error.lua"),
        join(WTF_PATH, "SavedVariables", "SlySuite_Error.lua"),
      ];
      let raw = null;
      for (const p of svPaths) {
        if (existsSync(p)) { raw = readFileSync(p, "utf8"); break; }
      }
      if (!raw) return "SlyErrorDB not found — has the game been run since SlySuite_Error was deployed?";

      // Parse the Lua table by extracting error entries with a regex
      const n = args.n || 25;
      // Match entries:  { label = "...", msg = "...", stack = "...", dt = "...", t = ... }
      const entryRe = /\{([^}]+)\}/gs;
      const fieldRe = /(\w+)\s*=\s*"((?:[^"\\]|\\.)*)"/g;
      const entries = [];
      let em;
      while ((em = entryRe.exec(raw)) !== null) {
        const block  = em[1];
        const fields = {};
        let fm;
        while ((fm = fieldRe.exec(block)) !== null) {
          fields[fm[1]] = fm[2].replace(/\\"/g, '"').replace(/\\n/g, "\n");
        }
        if (fields.label || fields.msg) entries.push(fields);
      }

      if (entries.length === 0) return "No errors in SlyErrorDB — clean slate!";

      const show = entries.slice(-n);
      const out = show.map((e, i) =>
        `[${show.length - i}] ${e.dt || "?"} — ${e.label || "?"}\n` +
        `  ${(e.msg || "").slice(0, 200)}\n` +
        (e.stack ? `  ${e.stack.split("\n").slice(0, 3).join(" | ")}` : "")
      );
      return `${entries.length} total error(s), showing last ${show.length}:\n\n` +
             out.reverse().join("\n\n");
    }

    // ── read_saved_vars ───────────────────────────────────────────────────
    case "wow_read_saved_vars": {
      const candidates = [
        args.account
          ? join(WTF_PATH, "Account", args.account, "SavedVariables", args.file)
          : null,
        join(WTF_PATH, "Account", "ANTEUNIVERSAL", "SavedVariables", args.file),
        join(WTF_PATH, "SavedVariables", args.file),
      ].filter(Boolean);

      for (const p of candidates) {
        if (existsSync(p)) {
          return trimText(readFileSync(p, "utf8"), 12000);
        }
      }
      return `File not found: ${args.file}\nSearched:\n` + candidates.join("\n");
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

// ── Server wiring ────────────────────────────────────────────────────────────
const server = new Server(
  { name: "wow-addons", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;
  try {
    const text = handleTool(name, args);
    return { content: [{ type: "text", text: String(text) }] };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Error: ${err.message}` }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
