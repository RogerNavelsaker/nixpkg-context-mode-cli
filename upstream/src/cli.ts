import { Client } from "@modelcontextprotocol/sdk/client";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

type CommandResult = {
  ok: boolean;
  command: string;
  toolName?: string;
  input?: Json;
  result?: Json;
  error?: string;
};

const DEFAULT_SERVER_COMMAND = process.env.CONTEXT_MODE_MCP_COMMAND || "context-mode-mcp";
const DEFAULT_TIMEOUT_MS = 30_000;

function usage(): never {
  console.error(`Usage:
  context-mode-cli list-tools [--json]
  context-mode-cli tool <tool-name> [--input-json <json>] [--json]
  context-mode-cli stats [--json]
  context-mode-cli doctor [--json]
  context-mode-cli fetch-and-index <url> [--source <source>] [--force] [--json]
  context-mode-cli search <query> [--query <query> ...] [--limit <n>] [--source <source>] [--content-type <type>] [--json]
  context-mode-cli execute <language> <code> [--timeout <ms>] [--intent <text>] [--json]
  context-mode-cli execute-file <path> <language> <code> [--timeout <ms>] [--intent <text>] [--json]
  context-mode-cli batch-execute --commands-json <json> --queries-json <json> [--timeout <ms>] [--json]

Environment:
  CONTEXT_MODE_MCP_COMMAND   Override the server executable (default: context-mode-mcp)
  CONTEXT_MODE_MCP_CWD       Working directory for the spawned MCP server`);
  process.exit(2);
}

function parseFlag(args: string[], flag: string): string | undefined {
  const index = args.indexOf(flag);
  if (index === -1) return undefined;
  if (index + 1 >= args.length) {
    throw new Error(`Missing value for ${flag}`);
  }
  return args[index + 1];
}

function hasFlag(args: string[], flag: string): boolean {
  return args.includes(flag);
}

function parseRepeatedFlag(args: string[], flag: string): string[] {
  const values: string[] = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === flag) {
      if (i + 1 >= args.length) {
        throw new Error(`Missing value for ${flag}`);
      }
      values.push(args[i + 1]);
      i += 1;
    }
  }
  return values;
}

function parseJson(value: string | undefined, label: string): Json | undefined {
  if (value == null) return undefined;
  try {
    return JSON.parse(value) as Json;
  } catch (error) {
    throw new Error(`Invalid JSON for ${label}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

function printResult(result: CommandResult, asJson: boolean): void {
  if (asJson) {
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  if (!result.ok) {
    console.error(result.error || "unknown error");
    process.exit(1);
  }

  if (result.command === "list-tools") {
    const tools = ((result.result as { tools?: Array<{ name?: string; description?: string }> })?.tools ?? []);
    for (const tool of tools) {
      console.log(`${tool.name}: ${tool.description ?? ""}`.trim());
    }
    return;
  }

  const toolResult = result.result as { content?: Array<{ type?: string; text?: string }>; structuredContent?: Json } | undefined;
  const textItems = toolResult?.content?.filter((item) => item?.type === "text" && typeof item.text === "string") ?? [];
  if (textItems.length > 0) {
    console.log(textItems.map((item) => item.text).join("\n\n"));
    return;
  }

  console.log(JSON.stringify(result.result, null, 2));
}

async function withClient<T>(fn: (client: Client) => Promise<T>): Promise<T> {
  const transport = new StdioClientTransport({
    command: DEFAULT_SERVER_COMMAND,
    cwd: process.env.CONTEXT_MODE_MCP_CWD || process.cwd(),
    stderr: "pipe",
  });
  const client = new Client(
    {
      name: "context-mode-cli",
      version: "1.0.52-p1",
    },
    {
      capabilities: {},
    },
  );

  try {
    await client.connect(transport);
    await client.listTools();
    return await fn(client);
  } finally {
    await client.close();
  }
}

async function callTool(toolName: string, input: Json | undefined, command: string): Promise<CommandResult> {
  try {
    const result = await withClient(async (client) => {
      return await client.callTool({
        name: toolName,
        arguments: (input ?? {}) as Record<string, unknown>,
      });
    });

    return {
      ok: true,
      command,
      toolName,
      input,
      result: result as Json,
    };
  } catch (error) {
    return {
      ok: false,
      command,
      toolName,
      input,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

async function listTools(): Promise<CommandResult> {
  try {
    const result = await withClient(async (client) => await client.listTools());
    return {
      ok: true,
      command: "list-tools",
      result: result as Json,
    };
  } catch (error) {
    return {
      ok: false,
      command: "list-tools",
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const command = argv[0];
  if (!command) usage();

  const asJson = hasFlag(argv, "--json");

  let result: CommandResult;

  switch (command) {
    case "list-tools": {
      result = await listTools();
      break;
    }
    case "tool": {
      const toolName = argv[1];
      if (!toolName) usage();
      const input = parseJson(parseFlag(argv, "--input-json"), "--input-json");
      result = await callTool(toolName, input, command);
      break;
    }
    case "stats": {
      result = await callTool("ctx_stats", {}, command);
      break;
    }
    case "doctor": {
      result = await callTool("ctx_doctor", {}, command);
      break;
    }
    case "fetch-and-index": {
      const url = argv[1];
      if (!url) usage();
      const source = parseFlag(argv, "--source");
      const force = hasFlag(argv, "--force");
      result = await callTool(
        "ctx_fetch_and_index",
        {
          url,
          ...(source ? { source } : {}),
          ...(force ? { force: true } : {}),
        },
        command,
      );
      break;
    }
    case "search": {
      const positionalQuery = argv[1] && !argv[1].startsWith("--") ? argv[1] : undefined;
      const extraQueries = parseRepeatedFlag(argv, "--query");
      const queries = [...(positionalQuery ? [positionalQuery] : []), ...extraQueries];
      if (queries.length === 0) usage();
      const limit = parseFlag(argv, "--limit");
      const source = parseFlag(argv, "--source");
      const contentType = parseFlag(argv, "--content-type");
      result = await callTool(
        "ctx_search",
        {
          queries,
          ...(limit ? { limit: Number(limit) } : {}),
          ...(source ? { source } : {}),
          ...(contentType ? { contentType } : {}),
        },
        command,
      );
      break;
    }
    case "execute": {
      const language = argv[1];
      const code = argv[2];
      if (!language || code == null) usage();
      const timeout = parseFlag(argv, "--timeout");
      const intent = parseFlag(argv, "--intent");
      result = await callTool(
        "ctx_execute",
        {
          language,
          code,
          ...(timeout ? { timeout: Number(timeout) } : {}),
          ...(intent ? { intent } : {}),
        },
        command,
      );
      break;
    }
    case "execute-file": {
      const path = argv[1];
      const language = argv[2];
      const code = argv[3];
      if (!path || !language || code == null) usage();
      const timeout = parseFlag(argv, "--timeout");
      const intent = parseFlag(argv, "--intent");
      result = await callTool(
        "ctx_execute_file",
        {
          path,
          language,
          code,
          ...(timeout ? { timeout: Number(timeout) } : {}),
          ...(intent ? { intent } : {}),
        },
        command,
      );
      break;
    }
    case "batch-execute": {
      const commands = parseJson(parseFlag(argv, "--commands-json"), "--commands-json");
      const queries = parseJson(parseFlag(argv, "--queries-json"), "--queries-json");
      const timeout = parseFlag(argv, "--timeout");
      if (!Array.isArray(commands) || !Array.isArray(queries)) {
        throw new Error("batch-execute requires array JSON for --commands-json and --queries-json");
      }
      result = await callTool(
        "ctx_batch_execute",
        {
          commands,
          queries,
          ...(timeout ? { timeout: Number(timeout) } : {}),
        },
        command,
      );
      break;
    }
    default:
      usage();
  }

  printResult(result, asJson);
}

await main();
